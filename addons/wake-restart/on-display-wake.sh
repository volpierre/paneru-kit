#!/bin/sh
# Run by sleepwatcher when the display turns on. Restarts Paneru only if the Mac slept
# since the last restart (on-sleep.sh left a marker); a screen that only dimmed or turned
# off while the Mac stayed awake is left alone.
DIR="$HOME/.paneru-kit/wake"
[ -f "$DIR/slept" ] || exit 0
rm -f "$DIR/slept"
sleep 3   # let macOS finish bringing displays and windows back first
/usr/bin/python3 -I "$DIR/restart_paneru.py" >> "$DIR/wake.log" 2>&1
