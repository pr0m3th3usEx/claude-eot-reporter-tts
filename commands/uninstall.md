---
description: Remove the downloaded pocket-tts model, binary, and all plugin data (asks first).
disable-model-invocation: true
allowed-tools: AskUserQuestion, Read, Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/uninstall.sh:*)
---

# Claude End-of-Task TTS — Uninstall data

Remove everything this plugin downloaded or generated: the model cache (~240MB), the downloaded
`pocket-tts-cli` binary, and all plugin data (settings, voice choice, readiness stamp). This does
**not** remove the plugin itself — use Claude Code's `/plugin` manager for that.

## Steps

### 1. Show what will be removed

Run the uninstaller in **dry-run** mode and show the user the list of paths and their total size:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/uninstall.sh
```

### 2. Confirm

Use **AskUserQuestion** to confirm, since this frees hundreds of MB and requires re-downloading to
use TTS again. Offer **Remove everything** (first) and **Cancel**. If the user cancels, stop and
report that nothing was removed.

### 3. Delete and report

On confirmation, run:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/uninstall.sh --yes
```

Then tell the user what was freed, that TTS is now off, and that they can reinstall anytime with
`/claude-eot-report-tts:setup`. (To also remove the plugin itself, they use Claude Code's `/plugin`
manager.)
