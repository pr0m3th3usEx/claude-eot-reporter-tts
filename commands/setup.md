---
description: Install the pocket-tts binary and a chosen voice so the plugin can speak task results aloud.
argument-hint: [voice]
disable-model-invocation: true
allowed-tools: AskUserQuestion, Read, Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/install.sh:*), Bash(curl:*)
---

# Claude End-of-Task TTS — Setup

Set up the End-of-Task Text-to-Speech plugin: download the `pocket-tts-cli` binary for this
platform, download the model plus one selected voice, and play a short confirmation clip.

The first argument (`$0`), if given, is the voice to install. Valid voices:
`alba`, `marius`, `javert`, `jean`, `fantine`, `cosette`, `eponine`, `azelma`.

## Steps

### 1. Determine the voice

- If `$0` is a non-empty value AND it is one of the eight valid voices above, use it directly.
- Otherwise (no argument, or an unrecognized value), call **AskUserQuestion** once to let the user
  pick a voice from the eight options. Recommend `alba` (the default) as the first option. Give
  each option a one-line description noting it is an English stock voice.

### 2. Run the installer

Run the bundled installer with the chosen voice, using a **long Bash timeout of 600000 ms**
because the first run downloads the ~244MB model:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/install.sh --voice <chosen-voice>
```

Stream its output so the user can watch each step (binary download, voice download, test clip).
Do not suppress the output.

### 3. Report the result

When it finishes, tell the user concisely:

- TTS is set up and which voice is now the default.
- It will speak automatically when a task finishes.
- They can change the voice later with `/claude-eot-report-tts:install-voice <name>`, or pause
  speech with `/claude-eot-report-tts:pause`.

If the installer failed, surface the error output and the most likely cause (e.g. no network, or
`ffmpeg`/`ffplay` not installed — note that playback is optional and does not affect setup).
