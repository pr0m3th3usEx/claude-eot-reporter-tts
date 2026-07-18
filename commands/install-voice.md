---
description: Download a different pocket-tts voice and make it the default spoken voice.
argument-hint: [voice]
disable-model-invocation: true
allowed-tools: AskUserQuestion, Read, Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/install.sh:*)
---

# Claude End-of-Task TTS — Install / Switch Voice

Download a stock voice (if not already cached) and set it as the **default** voice used when the
plugin speaks. Assumes `/claude-eot-report-tts:setup` has already run; if not, this will also
download the binary and model as needed.

The first argument (`$0`), if given, is the voice to switch to. Valid voices:
`alba`, `marius`, `javert`, `jean`, `fantine`, `cosette`, `eponine`, `azelma`.

## Steps

### 1. Determine the voice

- If `$0` is a non-empty value AND it is one of the eight valid voices above, use it directly.
- Otherwise (no argument, or an unrecognized value), call **AskUserQuestion** once to let the user
  pick a voice from the eight options. Give each a one-line description noting it is an English
  stock voice.

### 2. Run the installer

Run the bundled installer with the chosen voice, using a **long Bash timeout of 600000 ms** (only
the new voice is fetched if the model is already installed; a fresh machine will also download the
~244MB model):

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/install.sh --voice <chosen-voice>
```

Stream its output so the user can watch the download and hear the test clip in the new voice. Do
not suppress the output.

### 3. Report the result

When it finishes, tell the user concisely that the default voice is now `<chosen-voice>` and it
takes effect on the next task-finish. If the installer failed, surface the error and the most
likely cause (no network, or no audio player for the test clip — playback is optional).
