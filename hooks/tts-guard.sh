#!/usr/bin/env bash
# SessionStart hook. Fast readiness check: if the model cache is missing or stale
# (plugin updated), kick off the download in the background so we never block
# session start on a ~250MB fetch. This is the mechanism that handles first-run
# (when the Setup hook may never fire) and post-update refresh.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Consume the hook's JSON stdin without blocking.
if [ ! -t 0 ]; then cat >/dev/null 2>&1 || true; fi

if tts_is_ready; then
  exit 0   # Fast path: nothing to do.
fi

# Not ready. Launch setup detached (unless one is already running) and return
# immediately; tts-notify.sh no-ops until the stamp appears.
if [ ! -d "${LOCK}" ]; then
  SETUP="$(dirname "${BASH_SOURCE[0]}")/tts-setup.sh"
  nohup bash "${SETUP}" update >"${SETUP_LOG}" 2>&1 &
  echo "tts-guard: TTS models not ready; downloading in background (log: ${SETUP_LOG})" >&2
fi

exit 0
