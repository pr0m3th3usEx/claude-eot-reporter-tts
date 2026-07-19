# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.0.0]

### Added
- `/claude-eot-report-tts:pause [on|off]` command to toggle spoken task summaries.
- `/claude-eot-report-tts:uninstall` command to remove the cached model, binary, and settings.
- `marketplace.json` for installing via `/plugin marketplace add`.

### Changed
- Setup, voice install, and binary update are now explicit user-triggered commands
  (`/setup`, `/install-voice`, `/update`) instead of running silently in the background.
- Corrected repository/homepage URLs (case and repo name) and updated keywords in
  `plugin.json`/`marketplace.json`.

### Removed
- macOS Intel (x86_64) binary from the release build matrix — only
  `aarch64-apple-darwin` is built for macOS going forward.

## [0.0.1]

- Initial release: Stop hook speaks a summary when Claude finishes a task; Notification
  hook refocuses the terminal/editor window and sends an OS notification when Claude
  needs input.
