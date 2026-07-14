#!/usr/bin/env bash
# Notification hook. Refocuses the terminal or VSCode window when Claude asks for
# input, and emits a bell + desktop notification as an OS-level fallback.

# Read the hook JSON input from stdin (required by the protocol).
INPUT=$(cat)

# Detect if we're in VSCode or a terminal.
# TERM_PROGRAM is set by most terminals and VSCode.
EDITOR_APP="${TERM_PROGRAM:-}"

case "$(uname -s)" in
  Darwin*)
    if [[ "$EDITOR_APP" == "vscode" ]] || [[ -n "$VSCODE_PID" ]]; then
      osascript -e 'tell application "Visual Studio Code" to activate'
    elif [[ -n "$TMUX" ]]; then
      osascript -e 'tell application "Terminal" to activate'
    elif [[ "$EDITOR_APP" == "iTerm.app" ]]; then
      osascript -e 'tell application "iTerm" to activate'
    elif [[ "$EDITOR_APP" == "WezTerm" ]]; then
      osascript -e 'tell application "WezTerm" to activate'
    else
      osascript -e 'tell application "Terminal" to activate'
    fi
    ;;

  Linux*)
    # NOTE: xdotool is X11-only; Wayland sessions won't focus (bell still fires).
    if [[ -n "$VSCODE_PID" ]]; then
      WID=$(xdotool search --pid "$VSCODE_PID" | head -1)
    elif [[ -n "$WINDOWID" ]]; then
      # $WINDOWID is set by most X11 terminal emulators
      WID="$WINDOWID"
    else
      # Fallback: search by the Claude Code session's parent terminal
      WID=$(xdotool search --pid "$PPID" | head -1)
    fi
    [ -n "$WID" ] && xdotool windowactivate "$WID"
    ;;

  MINGW*|MSYS*|CYGWIN*)
    # NOTE: SetForegroundWindow is subject to OS foreground-lock; it may only
    # flash the taskbar rather than steal focus. The bell below is the fallback.
    if [[ -n "$VSCODE_PID" ]]; then
      TARGET_PID="$VSCODE_PID"
    else
      TARGET_PID="$PPID"
    fi
    powershell.exe -Command "
      Add-Type @'
        using System; using System.Runtime.InteropServices;
        public class Win { [DllImport(\"user32.dll\")] public static extern bool SetForegroundWindow(IntPtr h); }
'@
      \$p = Get-Process -Id $TARGET_PID -EA SilentlyContinue
      if (\$p -and \$p.MainWindowHandle -ne 0) { [Win]::SetForegroundWindow(\$p.MainWindowHandle) }
    "
    ;;
esac

# Also emit a bell + desktop notification via terminalSequence
# so you get an OS-level notification even if focus fails.
# printf keeps the literal \uXXXX escapes (valid JSON control-char escapes).
printf '{\n  "terminalSequence": "\\u001b]9;Claude Code: Needs your input\\u0007\\u0007"\n}\n'
exit 0
