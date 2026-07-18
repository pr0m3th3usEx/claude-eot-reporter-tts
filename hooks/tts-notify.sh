#!/usr/bin/env bash
# Stop hook. Speaks the last assistant message aloud when a task finishes.
#
# Audio is generated + played in a detached background job so the hook returns
# immediately (model load + synthesis can take longer than the hook timeout).
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Paused via /pause: stay fully silent (no speech, no bell).
[ "${TTS_PAUSED}" = "1" ] && exit 0

# Read the hook JSON from stdin and extract the message (truncate for brevity).
INPUT=""
if [ ! -t 0 ]; then INPUT="$(cat)"; fi
MSG="Task completed"
if command -v jq >/dev/null 2>&1 && [ -n "${INPUT}" ]; then
  MSG="$(printf '%s' "${INPUT}" | jq -r '.last_assistant_message // "Task completed"' | head -c 300)"
fi
[ -z "${MSG}" ] && MSG="Task completed"

emit_bell() {
  # OS-level fallback notification via terminal escape.
  printf '{\n  "terminalSequence": "\\u001b]9;Claude: %s\\u0007\\u0007"\n}\n' \
    "$(printf '%s' "${MSG}" | sed 's/"/\\"/g')"
}

# Not set up yet: never download here. Bell + a ONE-TIME hint to run /setup.
if ! tts_is_ready; then
  HINT_MARKER="${PLUGIN_DATA}/.setup-hint-shown"
  if [ ! -f "${HINT_MARKER}" ]; then
    echo "claude-eot-report-tts: TTS is not set up yet. Run /claude-eot-report-tts:setup to enable spoken task summaries." >&2
    touch "${HINT_MARKER}" 2>/dev/null || true
  fi
  emit_bell
  exit 0
fi

BIN="$(resolve_pocket_tts_bin)" || { emit_bell; exit 0; }
if ! command -v ffplay >/dev/null 2>&1; then
  echo "tts-notify: ffplay not found; install ffmpeg for audio playback" >&2
  emit_bell
  exit 0
fi

# Detached synthesis + playback in the user's chosen voice. MSG and voice are
# passed via env (no shell injection); $0 inside bash -c is the binary path.
TTS_MSG="${MSG}" TTS_VOICE="${TTS_VOICE}" nohup bash -c \
  '"$0" generate --text "$TTS_MSG" --voice "$TTS_VOICE" --stream 2>/dev/null \
     | ffplay -f s16le -ar 24000 -ch_layout mono -nodisp -autoexit \
              -probesize 32 -analyzeduration 0 -i pipe:0 >/dev/null 2>&1' \
  "${BIN}" </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
