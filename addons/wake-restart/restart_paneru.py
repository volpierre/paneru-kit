"""Restart Paneru and put back what a restart undoes.

After a restart, Paneru re-applies the "new windows open at N width" rule to every
window, so full-width windows come back narrower. This records which windows were full
width, restarts Paneru, sets those back to full width and returns focus to the window
that had it.

Uses only the Python standard library (works with macOS's /usr/bin/python3, 3.9+).
The paneru binary comes from $PANERU, then PATH, then the usual Homebrew locations.
"""

import json
import os
import shutil
import subprocess
import time

FULL_WIDTH_TOLERANCE = 0.03  # a window within 3% of a screen's width counts as full width


def paneru_path():
    for candidate in (
        os.environ.get("PANERU"),
        shutil.which("paneru"),
        "/opt/homebrew/bin/paneru",
        "/usr/local/bin/paneru",
    ):
        if candidate and os.access(candidate, os.X_OK):
            return candidate
    raise SystemExit("paneru not found")


PANERU = paneru_path()


def log(*parts):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), *parts, flush=True)


def tiled_windows():
    """Windows on the active strip, left to right, or None if Paneru can't list them
    (for example while a full-screen app's Space is showing)."""
    result = subprocess.run(
        [PANERU, "query", "state", "--json"], capture_output=True, text=True
    )
    try:
        state = json.loads(result.stdout)
    except ValueError:
        return None
    return [
        window
        for workspace in state.get("virtual_workspaces", [])
        if workspace.get("active")
        for window in workspace.get("windows", [])
        if not window.get("floating")
    ]


def screen_widths():
    """Widths of all displays in points, read through AppKit via JavaScript for Automation."""
    script = 'ObjC.import("AppKit"); $.NSScreen.screens.js.map(s => s.frame.size.width).join(",")'
    result = subprocess.run(
        ["osascript", "-l", "JavaScript", "-e", script], capture_output=True, text=True
    )
    try:
        return [float(w) for w in result.stdout.strip().split(",") if w]
    except ValueError:
        return []


def is_full_width(width, screens):
    return any(abs(width - s) <= s * FULL_WIDTH_TOLERANCE for s in screens)


def window_command(*args):
    subprocess.run([PANERU, "send-cmd", "window", *args], capture_output=True)
    time.sleep(0.6)


def main():
    log("wake: restarting paneru")
    screens = screen_widths()
    before = tiled_windows() or []
    full = {w["window_id"] for w in before if is_full_width(w["frame"]["width"], screens)}
    focused = next((w["window_id"] for w in before if w.get("focused")), None)

    subprocess.run([PANERU, "restart"], capture_output=True)
    time.sleep(5)

    if tiled_windows() is None:
        log("  windows not readable after restart; widths left as they are")
        return

    for window_id in full:
        windows = tiled_windows() or []
        ids = [w["window_id"] for w in windows]
        if window_id not in ids:
            continue
        window = windows[ids.index(window_id)]
        if not is_full_width(window["frame"]["width"], screens):
            window_command("focus", str(ids.index(window_id) + 1))
            window_command("fullwidth")

    ids = [w["window_id"] for w in tiled_windows() or []]
    if focused in ids:
        window_command("focus", str(ids.index(focused) + 1))

    summary = [
        (w.get("app_name", "").strip("‎"), w["frame"]["width"])
        for w in tiled_windows() or []
    ]
    log("  done:", summary)


if __name__ == "__main__":
    main()
