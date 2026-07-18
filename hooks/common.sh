#!/usr/bin/env bash
# Shared environment for the claude-eot-report-tts plugin scripts.
# Sourced by hooks/tts-notify.sh and scripts/install.sh.

# Plugin root: provided by Claude Code as CLAUDE_PLUGIN_ROOT; fall back to the
# directory that contains this hooks/ folder so the scripts also work standalone.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Per-user data dir. We deliberately do NOT use ${CLAUDE_PLUGIN_DATA}: it is set
# for hooks but NOT for slash-command shells, so relying on it makes /setup (a
# command) and the Stop hook read different files. A fixed HOME path resolves
# identically in every context and survives plugin updates. (TTS_DATA_DIR is an
# override for tests.)
PLUGIN_DATA="${TTS_DATA_DIR:-${HOME}/.cache/claude-eot-report-tts}"
mkdir -p "${PLUGIN_DATA}" 2>/dev/null || true

# HuggingFace cache lives inside PLUGIN_DATA so downloaded models persist across
# plugin updates. Exported so the pocket-tts-cli binary honors it.
export HF_HOME="${PLUGIN_DATA}/hf-cache"

# Readiness stamp: contains the plugin version the cache was populated for.
STAMP="${PLUGIN_DATA}/.tts-ready"
# Atomic lock dir to avoid launching concurrent downloads.
LOCK="${PLUGIN_DATA}/.tts-downloading"
SETUP_LOG="${PLUGIN_DATA}/setup.log"

# The 8 predefined stock voices (kyutai/pocket-tts-without-voice-cloning).
PREDEFINED_VOICES="alba marius javert jean fantine cosette eponine azelma"

# --- User settings (chosen via /setup, /install-voice, /pause) ---------------
SETTINGS_FILE="${PLUGIN_DATA}/settings.env"
# Defaults, overridden by settings.env if present.
TTS_VOICE="alba"
TTS_PAUSED="0"
# shellcheck disable=SC1090
[ -f "${SETTINGS_FILE}" ] && . "${SETTINGS_FILE}"

# Idempotently set KEY=VALUE in settings.env (and export it for this process).
tts_set_setting() { # KEY VALUE
  local key="$1" val="$2" tmp
  mkdir -p "${PLUGIN_DATA}" 2>/dev/null || true
  touch "${SETTINGS_FILE}"
  tmp="$(mktemp)"
  grep -vE "^${key}=" "${SETTINGS_FILE}" > "${tmp}" 2>/dev/null || true
  printf '%s=%s\n' "${key}" "${val}" >> "${tmp}"
  mv "${tmp}" "${SETTINGS_FILE}"
  export "${key}=${val}"
}

# True if NAME is one of the predefined stock voices.
tts_is_valid_voice() { # NAME
  case " ${PREDEFINED_VOICES} " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

# Expected version = the plugin's declared version. Bump plugin.json (and the
# config @revision when the model changes) to force a re-download.
PLUGIN_JSON="${PLUGIN_ROOT}/.claude-plugin/plugin.json"
if command -v jq >/dev/null 2>&1 && [ -f "${PLUGIN_JSON}" ]; then
  EXPECTED_VERSION="$(jq -r '.version // "0"' "${PLUGIN_JSON}" 2>/dev/null || echo "0")"
  # owner/repo slug parsed from the repository URL (git@..:o/r.git or https://.../o/r[.git]).
  REPO_SLUG="$(jq -r '.repository // ""' "${PLUGIN_JSON}" 2>/dev/null \
    | sed -E 's#\.git$##; s#^git@[^:]+:##; s#^https?://[^/]+/##')"
else
  EXPECTED_VERSION="0"
  REPO_SLUG=""
fi

# --- Platform detection for prebuilt binary download -------------------------

# ".exe" on Windows shells, empty elsewhere.
bin_exe_suffix() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) echo ".exe" ;;
    *) echo "" ;;
  esac
}

# Binary filename for this platform, e.g. pocket-tts-cli or pocket-tts-cli.exe.
plugin_bin_name() { echo "pocket-tts-cli$(bin_exe_suffix)"; }

# Rust target triple for the current OS/arch (matches the CI release matrix).
# Echoes empty and returns 1 when unsupported.
plugin_bin_target() {
  local os arch
  os="$(uname -s)"; arch="$(uname -m)"
  case "${os}" in
    Darwin)
      case "${arch}" in
        arm64|aarch64) echo "aarch64-apple-darwin" ;;
        x86_64)        echo "x86_64-apple-darwin" ;;
        *) return 1 ;;
      esac ;;
    Linux)
      case "${arch}" in
        x86_64) echo "x86_64-unknown-linux-gnu" ;;
        *) return 1 ;;
      esac ;;
    MINGW*|MSYS*|CYGWIN*)
      case "${arch}" in
        x86_64) echo "x86_64-pc-windows-msvc" ;;
        *) return 1 ;;
      esac ;;
    *) return 1 ;;
  esac
}

# Archive extension for this platform: zip on Windows, tar.gz elsewhere.
plugin_bin_archive_ext() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) echo "zip" ;;
    *) echo "tar.gz" ;;
  esac
}

# Path where a downloaded binary is installed.
plugin_bin_path() { echo "${PLUGIN_DATA}/bin/$(plugin_bin_name)"; }

# Resolve the pocket-tts-cli binary: explicit override, downloaded binary in
# PLUGIN_DATA, a shipped/dev build, then PATH. All candidates are .exe-aware.
resolve_pocket_tts_bin() {
  if [ -n "${POCKET_TTS_BIN:-}" ] && [ -x "${POCKET_TTS_BIN}" ]; then
    echo "${POCKET_TTS_BIN}"; return 0
  fi
  local name; name="$(plugin_bin_name)"
  for cand in \
    "${PLUGIN_DATA}/bin/${name}" \
    "${PLUGIN_ROOT}/bin/${name}" \
    "${PLUGIN_ROOT}/pocket-tts/target/release/${name}"; do
    if [ -x "${cand}" ]; then echo "${cand}"; return 0; fi
  done
  if command -v "${name}" >/dev/null 2>&1; then
    command -v "${name}"; return 0
  fi
  return 1
}

# True when the cache has been populated for the expected version.
tts_is_ready() {
  [ -f "${STAMP}" ] && [ "$(cat "${STAMP}" 2>/dev/null)" = "${EXPECTED_VERSION}" ]
}

# --- Prebuilt binary download (shared by the installer) ----------------------

fetch() { # url dest
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    echo "tts: need curl or wget to download binaries" >&2
    return 1
  fi
}

sha256_verify() { # dir archive  (expects dir/SHA256SUMS)
  local dir="$1" arc="$2" line
  [ -f "${dir}/SHA256SUMS" ] || return 2
  line="$(grep -E "[* ]?${arc}\$" "${dir}/SHA256SUMS" 2>/dev/null | head -1)"
  [ -n "${line}" ] || { echo "tts: no checksum entry for ${arc}" >&2; return 1; }
  (
    cd "${dir}"
    if command -v sha256sum >/dev/null 2>&1; then
      printf '%s\n' "${line}" | sha256sum -c -
    elif command -v shasum >/dev/null 2>&1; then
      printf '%s\n' "${line}" | shasum -a 256 -c -
    else
      echo "tts: no sha256 tool; skipping verification" >&2
      return 0
    fi
  )
}

# Download + verify + extract the prebuilt binary for this platform into
# ${PLUGIN_DATA}/bin, unless a suitable one is already available. Echoes progress
# to stderr. Returns 0 when a usable binary is present afterward.
ensure_binary() {
  local name path verfile target ext tag base archive url tmp resolved
  name="$(plugin_bin_name)"
  path="$(plugin_bin_path)"
  verfile="${PLUGIN_DATA}/bin/.version"

  # Correct version already downloaded.
  if [ -x "${path}" ] && [ "$(cat "${verfile}" 2>/dev/null)" = "${EXPECTED_VERSION}" ]; then
    return 0
  fi

  # A dev/PATH build outside PLUGIN_DATA (e.g. cargo target/release) — use it.
  if resolved="$(resolve_pocket_tts_bin)"; then
    case "${resolved}" in
      "${PLUGIN_DATA}/"*) : ;;  # stale download → re-download below
      *) echo "tts: using existing binary ${resolved}" >&2; return 0 ;;
    esac
  fi

  target="$(plugin_bin_target)" || {
    echo "tts: unsupported platform $(uname -s)/$(uname -m)" >&2; return 1; }
  ext="$(plugin_bin_archive_ext)"
  [ -n "${REPO_SLUG}" ] || {
    echo "tts: repository slug unknown (check plugin.json 'repository')" >&2; return 1; }

  tag="v${EXPECTED_VERSION}"
  base="https://github.com/${REPO_SLUG}/releases/download/${tag}"
  archive="pocket-tts-cli-${tag}-${target}.${ext}"
  url="${base}/${archive}"

  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN

  echo "tts: downloading ${url}" >&2
  fetch "${url}" "${tmp}/${archive}" || {
    echo "tts: download failed: ${url}" >&2; return 1; }

  if fetch "${base}/SHA256SUMS" "${tmp}/SHA256SUMS" 2>/dev/null; then
    sha256_verify "${tmp}" "${archive}" || {
      echo "tts: checksum verification FAILED for ${archive}" >&2; return 1; }
  else
    echo "tts: WARNING: SHA256SUMS not published; skipping verification" >&2
  fi

  mkdir -p "${PLUGIN_DATA}/bin"
  case "${ext}" in
    tar.gz) tar -xzf "${tmp}/${archive}" -C "${PLUGIN_DATA}/bin" ;;
    zip)    unzip -o "${tmp}/${archive}" -d "${PLUGIN_DATA}/bin" >/dev/null ;;
  esac
  chmod +x "${path}" 2>/dev/null || true
  [ -x "${path}" ] || { echo "tts: binary missing after extract: ${path}" >&2; return 1; }
  printf '%s' "${EXPECTED_VERSION}" > "${verfile}"
  echo "tts: installed ${name} ${EXPECTED_VERSION}" >&2
}
