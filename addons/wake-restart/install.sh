#!/bin/bash
# Installs the wake add-on: restarts Paneru when the screen comes back on after the Mac
# really slept. Screen dims and the short "maintenance" wakes macOS does with the lid
# closed are ignored.
#
# How: sleepwatcher (Homebrew) runs on-sleep.sh when the Mac sleeps, which leaves a marker
# file, and on-display-wake.sh when the display turns on, which restarts Paneru only if
# that marker is there.
#
#   ./install.sh [--paneru /path/to/paneru] [--dry-run]

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.paneru-kit/wake"
LABEL="io.github.paneru-kit.wake"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
PANERU=""
DRY=0

while [ $# -gt 0 ]; do
    case "$1" in
        --paneru) PANERU="${2:-}"; shift 2 ;;
        --dry-run) DRY=1; shift ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

say() { printf '%s\n' "$*" >&2; }
run() { if [ "$DRY" -eq 1 ]; then say "[dry-run] $*"; else "$@"; fi; }

find_first() {
    local p
    for p in "$@"; do [ -x "$p" ] && { echo "$p"; return 0; }; done
    return 1
}

[ -n "$PANERU" ] || PANERU="$(command -v paneru || find_first /opt/homebrew/bin/paneru /usr/local/bin/paneru || true)"
[ -n "$PANERU" ] || { say "Paneru isn't installed."; exit 1; }

BREW="$(command -v brew || find_first /opt/homebrew/bin/brew /usr/local/bin/brew || true)"
SLEEPWATCHER="$(find_first /opt/homebrew/sbin/sleepwatcher /usr/local/sbin/sleepwatcher || true)"
if [ -z "$SLEEPWATCHER" ]; then
    [ -n "$BREW" ] || { say "Homebrew is needed to install sleepwatcher: https://brew.sh"; exit 1; }
    say "Installing sleepwatcher with Homebrew…"
    run "$BREW" install sleepwatcher
    SLEEPWATCHER="$(find_first /opt/homebrew/sbin/sleepwatcher /usr/local/sbin/sleepwatcher || true)"
    [ -n "$SLEEPWATCHER" ] || [ "$DRY" -eq 1 ] || { say "sleepwatcher didn't install."; exit 1; }
    [ -n "$SLEEPWATCHER" ] || SLEEPWATCHER="$(dirname "$BREW")/../sbin/sleepwatcher"
fi

# The scripts are copied out of the repo so moving or deleting the clone doesn't break it.
run mkdir -p "$DEST" "$HOME/Library/LaunchAgents"
run cp "$HERE/on-sleep.sh" "$HERE/on-display-wake.sh" "$HERE/restart_paneru.py" "$DEST/"
run chmod +x "$DEST/on-sleep.sh" "$DEST/on-display-wake.sh"

PLIST_BODY="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$SLEEPWATCHER</string>
    <string>-s</string><string>$DEST/on-sleep.sh</string>
    <string>-W</string><string>$DEST/on-display-wake.sh</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PANERU</key><string>$PANERU</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardErrorPath</key><string>$DEST/sleepwatcher.log</string>
</dict>
</plist>"

if [ "$DRY" -eq 1 ]; then
    say "[dry-run] would write $PLIST:"
    say "$PLIST_BODY"
else
    printf '%s\n' "$PLIST_BODY" > "$PLIST"
    plutil -lint "$PLIST" >/dev/null
fi

run launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
run launchctl bootstrap "gui/$(id -u)" "$PLIST"
say "✓ Wake add-on installed. It logs each restart to $DEST/wake.log"
say "  Remove it with: $(cd "$HERE/../.." && pwd)/uninstall.sh --wake-only"
