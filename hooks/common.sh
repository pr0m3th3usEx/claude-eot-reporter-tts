#!/usr/bin/env bash
# Shared environment for the claude-eot-report-tts hook scripts.
# Sourced by tts-setup.sh, tts-guard.sh, and tts-notify.sh.

# Plugin root: provided by Claude Code as CLAUDE_PLUGIN_ROOT; fall back to the
# directory that contains this hooks/ folder so the scripts also work standalone.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Persistent per-plugin data dir (survives plugin updates, unlike PLUGIN_ROOT).
PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-${HOME}/.cache/claude-eot-report-tts}"
mkdir -p "${PLUGIN_DATA}" 2>/dev/null || true

# HuggingFace cache lives inside PLUGIN_DATA so downloaded models persist across
# plugin updates. Exported so the pocket-tts-cli binary honors it.
export HF_HOME="${PLUGIN_DATA}/hf-cache"

# Readiness stamp: contains the plugin version the cache was populated for.
STAMP="${PLUGIN_DATA}/.tts-ready"
# Atomic lock dir to avoid launching concurrent downloads.
LOCK="${PLUGIN_DATA}/.tts-downloading"
SETUP_LOG="${PLUGIN_DATA}/setup.log"

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
