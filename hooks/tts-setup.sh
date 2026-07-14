#!/usr/bin/env bash
# Setup hook (matchers: init / maintenance) and the worker spawned by the
# SessionStart guard. Ensures the prebuilt pocket-tts-cli binary is present for
# this platform, downloads/refreshes all model artifacts, then stamps the cache
# as ready for the current plugin version.
#
# Usage: tts-setup.sh [init|update]   (default: init)
set -euo pipefail

SUBCMD="${1:-init}"
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Consume stdin if present (hook protocol) so we don't block on a pipe.
if [ ! -t 0 ]; then cat >/dev/null 2>&1 || true; fi

# --- helpers ----------------------------------------------------------------

fetch() { # url dest
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    echo "tts-setup: need curl or wget to download binaries" >&2
    return 1
  fi
}

sha256_verify() { # dir archive  (expects dir/SHA256SUMS)
  local dir="$1" arc="$2" line
  [ -f "${dir}/SHA256SUMS" ] || return 2
  line="$(grep -E "[* ]?${arc}\$" "${dir}/SHA256SUMS" 2>/dev/null | head -1)"
  [ -n "${line}" ] || { echo "tts-setup: no checksum entry for ${arc}" >&2; return 1; }
  (
    cd "${dir}"
    if command -v sha256sum >/dev/null 2>&1; then
      printf '%s\n' "${line}" | sha256sum -c -
    elif command -v shasum >/dev/null 2>&1; then
      printf '%s\n' "${line}" | shasum -a 256 -c -
    else
      echo "tts-setup: no sha256 tool; skipping verification" >&2
      return 0
    fi
  )
}

# Download + verify + extract the prebuilt binary for this platform into
# ${PLUGIN_DATA}/bin, unless a suitable one is already available.
ensure_binary() {
  local name path verfile target ext tag base archive url tmp
  name="$(plugin_bin_name)"
  path="$(plugin_bin_path)"
  verfile="${PLUGIN_DATA}/bin/.version"

  # Correct version already downloaded.
  if [ -x "${path}" ] && [ "$(cat "${verfile}" 2>/dev/null)" = "${EXPECTED_VERSION}" ]; then
    return 0
  fi

  # A dev/PATH build outside PLUGIN_DATA (e.g. cargo target/release) — use it.
  local resolved
  if resolved="$(resolve_pocket_tts_bin)"; then
    case "${resolved}" in
      "${PLUGIN_DATA}/"*) : ;;  # stale download → re-download below
      *) echo "tts-setup: using existing binary ${resolved}" >&2; return 0 ;;
    esac
  fi

  target="$(plugin_bin_target)" || {
    echo "tts-setup: unsupported platform $(uname -s)/$(uname -m)" >&2; return 1; }
  ext="$(plugin_bin_archive_ext)"
  [ -n "${REPO_SLUG}" ] || {
    echo "tts-setup: repository slug unknown (check plugin.json 'repository')" >&2; return 1; }

  tag="v${EXPECTED_VERSION}"
  base="https://github.com/${REPO_SLUG}/releases/download/${tag}"
  archive="pocket-tts-cli-${tag}-${target}.${ext}"
  url="${base}/${archive}"

  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN

  echo "tts-setup: downloading ${url}" >&2
  fetch "${url}" "${tmp}/${archive}" || {
    echo "tts-setup: download failed: ${url}" >&2; return 1; }

  if fetch "${base}/SHA256SUMS" "${tmp}/SHA256SUMS" 2>/dev/null; then
    sha256_verify "${tmp}" "${archive}" || {
      echo "tts-setup: checksum verification FAILED for ${archive}" >&2; return 1; }
  else
    echo "tts-setup: WARNING: SHA256SUMS not published; skipping verification" >&2
  fi

  mkdir -p "${PLUGIN_DATA}/bin"
  case "${ext}" in
    tar.gz) tar -xzf "${tmp}/${archive}" -C "${PLUGIN_DATA}/bin" ;;
    zip)    unzip -o "${tmp}/${archive}" -d "${PLUGIN_DATA}/bin" >/dev/null ;;
  esac
  chmod +x "${path}" 2>/dev/null || true
  [ -x "${path}" ] || { echo "tts-setup: binary missing after extract: ${path}" >&2; return 1; }
  printf '%s' "${EXPECTED_VERSION}" > "${verfile}"
  echo "tts-setup: installed ${name} ${EXPECTED_VERSION}" >&2
}

# --- main -------------------------------------------------------------------

# Serialize setup: skip if another run is already in progress.
if ! mkdir "${LOCK}" 2>/dev/null; then
  echo "tts-setup: another setup is in progress, skipping" >&2
  exit 0
fi
trap 'rmdir "${LOCK}" 2>/dev/null || true' EXIT

ensure_binary

BIN="$(resolve_pocket_tts_bin)" || {
  echo "tts-setup: pocket-tts-cli binary not found after ensure_binary" >&2
  exit 1
}

echo "tts-setup: running '${SUBCMD}' (HF_HOME=${HF_HOME})" >&2
"${BIN}" "${SUBCMD}" --quiet

# Mark ready for the current plugin version.
printf '%s' "${EXPECTED_VERSION}" > "${STAMP}"
echo "tts-setup: cache ready for version ${EXPECTED_VERSION}" >&2
