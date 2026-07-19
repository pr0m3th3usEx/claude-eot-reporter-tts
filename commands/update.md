---
description: Check for and install a newer pocket-tts-cli binary matching this plugin version.
disable-model-invocation: true
allowed-tools: Read, Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/update.sh:*)
---

# Claude End-of-Task TTS — Update

Reconcile the installed `pocket-tts-cli` binary with the version this plugin expects. If the
plugin was updated, this downloads the matching binary and restores TTS readiness. If already
current, it reports that and does nothing.

## Steps

### 1. Run the updater

Run the bundled updater with a **long Bash timeout of 600000 ms** (a download may be needed):

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/update.sh
```

Stream its output so the user sees the version check and any download.

### 2. Report the result

Tell the user concisely whether the binary was **already up to date** or **updated** (and from
which version to which). If it failed, surface the error and the likely cause (no network, or the
matching release/tag not published yet).
