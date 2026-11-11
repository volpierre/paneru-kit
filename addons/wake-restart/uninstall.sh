#!/bin/bash
# Removes the wake add-on. Leaves sleepwatcher installed (brew uninstall sleepwatcher).
set -euo pipefail

LABEL="io.github.paneru-kit.wake"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$HOME/.paneru-kit/wake"
printf '✓ Wake add-on removed.\n' >&2
