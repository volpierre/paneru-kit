#!/bin/sh
# Run by sleepwatcher when the Mac goes to sleep. Leaves a marker so the next time the
# screen turns on, on-display-wake.sh knows this was a real sleep. Must finish within
# 15 seconds or macOS sleeps anyway, so it does nothing else.
touch "$HOME/.paneru-kit/wake/slept"
