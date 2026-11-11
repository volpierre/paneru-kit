#!/bin/bash
# Undoes what setup.sh did:
#   - removes the wake add-on
#   - puts back the Paneru config you had before paneru-kit (if setup.sh saved one)
#   - forgets your saved answers
# Paneru itself stays installed; the end of this script says how to remove it too.
#
#   ./uninstall.sh              everything above, asking before restoring the config
#   ./uninstall.sh --wake-only  only remove the wake add-on

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$KIT_DIR/addons/wake-restart/uninstall.sh"
[ "${1:-}" = "--wake-only" ] && exit 0

CONFIG="${PANERU_CONFIG:-$HOME/.paneru.toml}"
[ -f "$HOME/.paneru" ] && [ -z "${PANERU_CONFIG:-}" ] && CONFIG="$HOME/.paneru"

# The oldest backup is the config from before paneru-kit first ran.
OLDEST="$(ls -1 "$CONFIG".backup-* 2>/dev/null | sort | head -1 || true)"
if [ -n "$OLDEST" ]; then
    printf 'Restore your config from before paneru-kit (%s)? [Y/n] ' "$OLDEST" >&2
    read -r answer || answer=""
    case "$answer" in
        n|N|no) printf 'Left %s as it is.\n' "$CONFIG" >&2 ;;
        *) cp "$OLDEST" "$CONFIG"; printf '✓ Restored %s\n' "$CONFIG" >&2 ;;
    esac
else
    printf 'No earlier config was saved, so %s stays as it is.\n' "$CONFIG" >&2
fi

rm -rf "$HOME/.paneru-kit"
printf '✓ paneru-kit removed.\n\n' >&2
printf 'To remove Paneru as well:\n  paneru stop && paneru uninstall && brew uninstall paneru\n' >&2
