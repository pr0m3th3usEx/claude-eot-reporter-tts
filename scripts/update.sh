#!/usr/bin/env bash
# Reconcile the installed pocket-tts-cli binary to the version this plugin
# expects (release tag == plugin.json version), invoked by the /update command.
#
# Binary-focused: downloads the matching binary only when stale/missing, then
# refreshes the readiness stamp so TTS keeps working after a plugin update. A
# changed model @revision is fetched lazily by the next generate.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../hooks/common.sh"

VERFILE="${PLUGIN_DATA}/bin/.version"
OLD="$(cat "${VERFILE}" 2>/dev/null || echo none)"

echo "==> Installed pocket-tts-cli: ${OLD}"
echo "==> Plugin expects:           ${EXPECTED_VERSION}"

echo "==> Checking for a binary update..."
ensure_binary
resolve_pocket_tts_bin >/dev/null || { echo "update: binary unavailable after check" >&2; exit 1; }

NEW="$(cat "${VERFILE}" 2>/dev/null || echo "${OLD}")"

# Restore readiness for the current version so the user need not re-run /setup.
printf '%s' "${EXPECTED_VERSION}" > "${STAMP}"

if [ "${OLD}" = "${NEW}" ]; then
  echo "==> Already up to date (${NEW})."
else
  echo "==> Updated pocket-tts-cli: ${OLD} -> ${NEW}."
fi
