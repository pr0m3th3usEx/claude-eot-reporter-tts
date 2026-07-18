#!/usr/bin/env bash
# Observable installer for the claude-eot-report-tts plugin, invoked by the
# /setup and /install-voice commands.
#
# Usage: install.sh --voice <name>
#
# Steps (all visible to the user):
#   1. ensure the platform pocket-tts-cli binary is downloaded
#   2. persist the chosen voice as the default
#   3. download the model + ONLY the chosen voice and render a test clip
#   4. play the test clip (best effort)
# then mark the plugin ready.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../hooks/common.sh"

VOICE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --voice)    VOICE="${2:-}"; shift 2 ;;
    --voice=*)  VOICE="${1#*=}"; shift ;;
    -h|--help)  echo "usage: install.sh --voice <name>  (voices: ${PREDEFINED_VOICES})"; exit 0 ;;
    *) echo "install: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Remember the current default before we change it (common.sh loaded TTS_VOICE
# from settings.env, or the "alba" default).
PREV_VOICE="${TTS_VOICE}"

# Default to the currently-configured voice when none is given.
[ -n "${VOICE}" ] || VOICE="${TTS_VOICE}"
if ! tts_is_valid_voice "${VOICE}"; then
  echo "install: invalid voice '${VOICE}'. Choose one of: ${PREDEFINED_VOICES}" >&2
  exit 2
fi

play_wav() { # wav
  local wav="$1"
  if command -v afplay >/dev/null 2>&1; then afplay "${wav}"; return; fi
  if command -v ffplay >/dev/null 2>&1; then ffplay -nodisp -autoexit -loglevel quiet "${wav}"; return; fi
  if command -v aplay  >/dev/null 2>&1; then aplay -q "${wav}"; return; fi
  if command -v paplay >/dev/null 2>&1; then paplay "${wav}"; return; fi
  return 1
}

echo "==> Installing pocket-tts (voice: ${VOICE})"

echo "==> [1/4] Ensuring pocket-tts-cli binary for this platform..."
ensure_binary
BIN="$(resolve_pocket_tts_bin)" || { echo "install: binary unavailable after download" >&2; exit 1; }

if [ -n "${PREV_VOICE}" ] && [ "${PREV_VOICE}" != "${VOICE}" ]; then
  echo "==> [2/4] Switching default voice: ${PREV_VOICE} -> ${VOICE}"
else
  echo "==> [2/4] Setting default voice: ${VOICE}"
fi
tts_set_setting TTS_VOICE "${VOICE}"

echo "==> [3/4] Downloading model + voice '${VOICE}' and rendering a test clip"
echo "         (first run downloads the ~244MB model; only this one voice is fetched)..."
TEST_WAV="${PLUGIN_DATA}/setup-test.wav"
"${BIN}" generate \
  --text "Text to speech is ready. Selected voice: ${VOICE}." \
  --voice "${VOICE}" \
  --output "${TEST_WAV}"

echo "==> [4/4] Playing test clip..."
if ! play_wav "${TEST_WAV}"; then
  echo "         (no audio player found; install ffmpeg for playback — the download itself is OK)"
fi

# Mark ready for the current plugin version.
printf '%s' "${EXPECTED_VERSION}" > "${STAMP}"
echo "==> Done. Default voice: ${VOICE}. Speaks when a task finishes."
echo "    Change the voice with /install-voice, pause with /pause."
