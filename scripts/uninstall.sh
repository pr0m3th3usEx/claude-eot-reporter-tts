#!/usr/bin/env bash
# Remove everything the plugin downloaded/generated: the model cache, the
# downloaded binary, and all plugin data. Invoked by the /uninstall command.
#
# Usage: uninstall.sh [--yes]
#   (no arg / --dry-run)  list what would be removed, delete nothing
#   --yes | --force       actually delete
#
# Does NOT remove the plugin itself (use Claude Code's /plugin manager) or the
# dev source build (pocket-tts/target/release).
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../hooks/common.sh"

DO_DELETE=0
case "${1:-}" in
  --yes|--force)  DO_DELETE=1 ;;
  ""|--dry-run)   DO_DELETE=0 ;;
  *) echo "usage: uninstall.sh [--yes]" >&2; exit 2 ;;
esac

# Refuse obviously dangerous paths. Applied at COLLECTION time so an unsafe path
# is never even `du`'d (e.g. `du -sh /` would scan the whole disk).
is_safe() { # path
  local p="$1"
  [ -n "${p}" ] || return 1
  [ "${p}" != "/" ] || return 1
  [ "${p}" != "${HOME}" ] || return 1
  case "${p}" in
    *claude-eot-report-tts*|*/.tts-debug.log) return 0 ;;
    *) return 1 ;;
  esac
}

targets=()
add_target() { # path
  local p="$1"
  if [ -d "${p}" ]; then
    # Skip an empty dir (common.sh re-creates an empty PLUGIN_DATA when sourced).
    [ -n "$(ls -A "${p}" 2>/dev/null)" ] || return 0
  elif [ ! -e "${p}" ]; then
    return 0
  fi
  if is_safe "${p}"; then
    targets+=("${p}")
  else
    echo "skipping unsafe path: ${p}" >&2
  fi
}

# Canonical data dir, official plugin-data dir(s) (incl. pre-fix leftovers,
# matched by name prefix), and the debug log.
add_target "${PLUGIN_DATA}"
for d in "${HOME}/.claude/plugins/data/"claude-eot-report-tts*; do
  add_target "${d}"
done
add_target "${HOME}/.tts-debug.log"

if [ "${#targets[@]}" -eq 0 ]; then
  echo "Nothing to remove — no plugin data found."
  exit 0
fi

echo "The following will be removed:"
for t in "${targets[@]}"; do
  sz="$(du -sh "${t}" 2>/dev/null | cut -f1)"
  echo "  ${t}  (${sz:-?})"
done

if [ "${DO_DELETE}" -eq 0 ]; then
  echo
  echo "(dry run — nothing deleted. Re-run with --yes to remove.)"
  exit 0
fi

# Stop any speech currently playing before deleting its files.
pkill -f 'pocket-tts-cli generate' 2>/dev/null || true
pkill -f 'ffplay -f s16le' 2>/dev/null || true

for t in "${targets[@]}"; do
  if is_safe "${t}"; then
    rm -rf "${t}" && echo "removed: ${t}"
  else
    echo "SKIPPED unsafe path: ${t}" >&2
  fi
done

echo "Done. All TTS data removed. Run /claude-eot-report-tts:setup to reinstall."
