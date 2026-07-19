# Claude End-of-Task Report TTS

Claude finishes a task, and tells you out loud.

A Claude Code plugin that generates spoken summaries when Claude finishes a task or needs your input, using the open-source [`pocket-tts`](https://github.com/pr0m3th3usEx/pocket-tts) engine — fully local, token-free.

## What it does

- **Spoken task summaries**: When Claude finishes a task, the plugin speaks a short summary of what happened (the last assistant message, up to 300 characters). Runs in the background so it doesn't block your workflow.
- **Window focus on input**: When Claude needs your input, the plugin refocuses your terminal/editor window and sends an OS-level notification (macOS, Linux, Windows).

## Prerequisites

These dependencies are optional but highly recommended:

- **`ffmpeg`** (provides `ffplay`) — Required for audio playback. Without it, the plugin downloads and caches everything but stays silent (falls back to a terminal bell). To install:
  - macOS: `brew install ffmpeg`
  - Ubuntu/Debian: `apt-get install ffmpeg`
  - Windows: `choco install ffmpeg` or download from [ffmpeg.org](https://ffmpeg.org)

- **`curl` or `wget`** — Required to download the `pocket-tts-cli` binary and model (~244 MB). One of these is usually installed by default.

- **`jq`** (optional) — Used to extract the assistant message from hook JSON. Without it, spoken summaries fall back to a generic "Task completed" message.

## Install

### Via marketplace (recommended)

Add the plugin from the Claude Code marketplace:

```bash
/plugin marketplace add pr0m3th3usEx/claude-eot-reporter-tts
/plugin install claude-eot-report-tts
```

Then run the setup command to download the speech model and choose a voice:

```bash
/claude-eot-report-tts:setup
```

### Manual (from source)

Clone this repository directly into Claude Code's plugin directory:

```bash
git clone --recurse-submodules \
  https://github.com/pr0m3th3usEx/claude-eot-reporter-tts.git \
  ~/.claude/plugins/claude-eot-reporter-tts
```

(The `--recurse-submodules` flag is necessary because `pocket-tts` is a git submodule. After cloning, restart Claude Code or run `/plugin` to pick up the new plugin.)

Then run the setup command:

```bash
/claude-eot-report-tts:setup
```

## Commands

### `/claude-eot-report-tts:setup [voice]`

Install the pocket-tts binary and a chosen voice so the plugin can speak task results aloud. The first time this runs, it downloads the ~244 MB model; subsequent runs are faster.

If no voice is specified, you'll be prompted to choose one. Use any of the 8 available voices (see below).

### `/claude-eot-report-tts:install-voice [voice]`

Download a different pocket-tts voice and make it the default. The plugin will speak in this voice on the next task finish.

If no voice is specified, you'll be prompted to choose one.

### `/claude-eot-report-tts:pause [on|off]`

Pause or resume spoken task summaries. With no argument, this toggles the current state; pass `on` to pause or `off` to resume.

Note: window focus on "Claude needs input" is not affected — only the spoken summaries are toggled.

### `/claude-eot-report-tts:update`

Check for and install a newer `pocket-tts-cli` binary if this plugin has been updated. If already up to date, reports that and does nothing.

### `/claude-eot-report-tts:uninstall`

Remove all downloaded data: the model cache (~240 MB), the `pocket-tts-cli` binary, and all plugin settings. This does not remove the plugin itself — use Claude Code's `/plugin` manager for that.

You can reinstall anytime by running `/claude-eot-report-tts:setup` again.

### Available voices

8 stock English voices from [`kyutai/pocket-tts-without-voice-cloning`](https://github.com/kyutai-labs/pocket-tts):

- `alba` (default)
- `marius`
- `javert`
- `jean`
- `fantine`
- `cosette`
- `eponine`
- `azelma`

## How it works

The plugin uses two hooks:

- **Stop hook** (`tts-notify.sh`): When Claude finishes a task, reads the last assistant message (up to 300 characters), generates speech using `pocket-tts-cli` in your chosen voice, and pipes it to `ffplay` for playback. This runs in a detached background process, so the hook returns instantly and doesn't block your workflow. If TTS isn't set up, `ffplay` is missing, or TTS is paused, it falls back to a terminal bell.

- **Notification hook** (`focus-window.sh`): When Claude needs your input, refocuses your terminal/editor window (Terminal, iTerm, WezTerm, VS Code on macOS; uses `xdotool` on Linux/X11; `SetForegroundWindow` on Windows) and sends an OS-level notification as a fallback.

### Supported platforms

- **macOS** (Intel x86_64 and Apple Silicon ARM64)
- **Linux** (x86_64; requires X11 for window focus)
- **Windows** (x86_64)

## Data & storage

All plugin data is stored in `~/.cache/claude-eot-report-tts`:

- `bin/` — the downloaded `pocket-tts-cli` binary for your platform
- `hf-cache/` — the cached ~244 MB TTS model
- `settings.env` — your chosen voice and pause/resume state
- `.tts-ready` — a stamp file tracking which plugin version the cache was prepared for

Running `/claude-eot-report-tts:uninstall` removes all of this. The plugin itself stays in `~/.claude/plugins/`.

## Contributing

Found a bug or have a suggestion? Feel free to open an issue or submit a pull request!

## License

MIT License. Built on [`pocket-tts`](https://github.com/pr0m3th3usEx/pocket-tts).

## Author

[@pr0m3th3usEx](https://github.com/pr0m3th3usEx)
