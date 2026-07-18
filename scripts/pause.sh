#!/usr/bin/env bash
# Pause / resume spoken task summaries, invoked by the /pause command.
#
# Usage: pause.sh [on|pause|off|resume|toggle]
#   (no arg)  toggle current state
#   on|pause  pause TTS
#   off|resume resume TTS
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../hooks/common.sh"

arg="${1:-toggle}"
case "${arg}" in
  ""|toggle)   [ "${TTS_PAUSED}" = "1" ] && NEW="0" || NEW="1" ;;
  on|pause|1)  NEW="1" ;;
  off|resume|0) NEW="0" ;;
  *) echo "pause: unknown argument '${arg}' (use on|off|toggle)" >&2; exit 2 ;;
esac

tts_set_setting TTS_PAUSED "${NEW}"

if [ "${NEW}" = "1" ]; then
  # Also stop any speech that is currently playing, not just future events.
  pkill -f 'pocket-tts-cli generate' 2>/dev/null || true
  pkill -f 'ffplay -f s16le' 2>/dev/null || true
  echo "TTS paused — task summaries are silent until you run /pause again."
else
  echo "TTS resumed — will speak when a task finishes."
fi
