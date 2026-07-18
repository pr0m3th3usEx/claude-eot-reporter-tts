---
description: Pause or resume spoken task summaries (toggles by default).
argument-hint: [on|off]
disable-model-invocation: true
allowed-tools: Read, Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/pause.sh:*)
---

# Claude End-of-Task TTS — Pause / Resume

Turn spoken task summaries off or on. With no argument this toggles the current state; pass `on`
(pause) or `off` (resume) to set it explicitly. Only the spoken Stop-hook summaries are affected —
window focus on "needs input" still works.

## Steps

### 1. Apply the state

Run the toggle script, passing the argument through (`$0` is empty for a plain toggle):

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/pause.sh $0
```

### 2. Report the result

Tell the user the new state in one line: **paused** (summaries will be silent until they run
`/claude-eot-report-tts:pause` again) or **resumed** (will speak when a task finishes).
