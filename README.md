# paneru-kit

A free, Ribbon-style sliding window setup for macOS, built on
[Paneru](https://github.com/karinushka/paneru).

All your windows sit side by side on one horizontal strip that's wider than the screen.
You slide along it with a trackpad swipe or a shortcut instead of digging through
overlapping windows. Paneru is the open-source window manager that does the work;
paneru-kit is a one-command setup that answers a few questions and writes a config
that's ready to use, plus fixes for the rough edges found while using it day to day.

> Not affiliated with Paneru or with [Ribbon](https://meetribbon.app), the paid app
> that inspired the default preset.

## Install

You need macOS and [Homebrew](https://brew.sh).

```bash
git clone https://github.com/<your-username>/paneru-kit.git
cd paneru-kit
./setup.sh
```

The script:

1. installs Paneru with Homebrew if it's missing;
2. asks a few questions (press Enter to keep each suggestion);
3. writes the Paneru config, keeping a dated backup of any config you already had;
4. sets Paneru to start at login and starts it.

The first time, macOS asks you to allow Paneru under **System Settings → Privacy &
Security → Accessibility**. Turn it on, then run `paneru restart`.

Run `./setup.sh` again any time to change your answers. It remembers the last ones.

## Presets

| Preset | What you get |
|---|---|
| `ribbon` (default) | Windows edge to edge, 3-finger swipe, fast animations, every shortcut |
| `minimal` | 8 px gaps between windows, calmer animations, fewer shortcuts |
| `keyboard` | No trackpad gesture, every shortcut |

```bash
./setup.sh --preset minimal
```

The generated configs are in [`examples/`](examples) if you'd rather copy one by hand
to `~/.paneru.toml`.

## Default shortcuts

`⌃⌥` is Control + Option. Setup can switch it to ⌘⌥, ⌃⌘ or ⌃⌥⌘.

| Keys | Action |
|---|---|
| `⌃⌥ ←` / `→` | Focus the window to the left / right |
| `⌃⌥ 1`…`9` | Jump straight to the Nth window |
| `⌃⌥ Home` / `End` | Jump to the first / last window |
| `⌃⌥⇧ ←` / `→` | Move the focused window left / right |
| `⌃⌥⇧ Home` / `End` | Move it to the start / end of the strip |
| `⌃⌥ R` / `⌃⌥⇧ R` | Cycle the width bigger / smaller |
| `⌃⌥ F` | Full width on / off |
| `⌃⌥ B` | Make every window this width |
| `⌃⌥ C` | Center the window |
| `⌃⌥⇧ F` | Float / tile the focused window |
| `⌃⌥ S` / `⌃⌥⇧ S` | Stack into the left column / unstack |
| `⌃⌥ T` | Show a stack as tabs |
| 3-finger swipe | Slide the strip |
| `⌥` + scroll | Slide the strip |

Paneru has no drag-and-drop reordering: move windows with `⌃⌥⇧ ←` / `→`.

## What's fixed compared to a bare Paneru install

- **New windows open in place.** They open straight at the chosen width instead of at
  the app's own size followed by a resize animation, which looks glitchy.
- **No thin strip on the edge of the screen.** With no gap between windows, Paneru's
  default 5 px sliver of each off-screen window shows over the visible one. The kit uses
  2 px, the smallest that macOS left in place in testing.
- **Save / Open pop-ups float.** Some apps (Telegram, for one) open them as normal
  windows, which then join the strip. The kit floats windows whose title is exactly
  "Save", "Open", "Export" and so on. It covers English and Italian (tested) and German,
  French and Spanish (best guesses; corrections welcome).
- **WhatsApp tiles.** It's an iPad-style app that Paneru skips by default. Add other
  apps like it during setup.
- **Optional: a restart after waking from sleep.** Some people find Paneru stops
  responding after the Mac wakes and has to be restarted. The wake add-on does that
  automatically, but only when the screen comes back on after a real sleep, not when
  the screen just dims.

## The trackpad gesture conflict

macOS uses a three-finger left/right swipe to switch between full-screen apps by
default, so it would fire together with Paneru's swipe. Either:

- move the macOS gesture to four fingers in **System Settings → Trackpad → More
  Gestures → Swipe between full-screen applications**, or
- choose the four-finger swipe for Paneru during setup.

Setup reads your trackpad settings and warns you if the two clash. It never changes
macOS settings itself.

## The wake add-on

Turn it on during setup, or install it on its own:

```bash
addons/wake-restart/install.sh
```

It installs [sleepwatcher](https://www.bernhard-baehr.de) with Homebrew and a login
service, `io.github.paneru-kit.wake`. When the Mac sleeps, it leaves a marker file. When
the display turns on and the marker is there, it waits 3 seconds, restarts Paneru, sets
any full-width windows back to full width and returns focus to where it was. Each restart
is logged in `~/.paneru-kit/wake/wake.log`.

Remove it with `./uninstall.sh --wake-only`.

## Answering without questions

Every answer can be passed as an environment variable together with `--yes`, which is
handy for dotfiles:

```bash
PK_FINGERS=4 PK_GAP=8 PK_FLOAT_APPS="Calculator, Finder" ./setup.sh --yes
```

| Variable | Values | Default (ribbon) |
|---|---|---|
| `PK_MOD` | `ctrl + alt`, `cmd + alt`, `ctrl + cmd`, `ctrl + alt + cmd` | `ctrl + alt` |
| `PK_FINGERS` | `3`, `4`, `off` | `3` |
| `PK_SCROLL_MOD` | `alt`, `cmd + alt`, `ctrl + alt` | `alt` |
| `PK_GAP` | pixels, 0–50 | `0` |
| `PK_NEW_WIDTH` | `0.3333`, `0.5`, `0.6667`, `1.0`, `app` | `0.5` |
| `PK_ANIM` | `45` (fast), `20` (smooth), `off` | `45` |
| `PK_FFM` | `y`, `n` (focus follows mouse) | `n` |
| `PK_NUMBER_KEYS` | `y`, `n` | `y` |
| `PK_STACKS` | `y`, `n` | `y` |
| `PK_FLOAT_DIALOGS` | `y`, `n` | `y` |
| `PK_FLOAT_APPS` | app names or bundle IDs, comma-separated, or `none` | `Calculator, System Settings` |
| `PK_FORCE_APPS` | same | `WhatsApp` |
| `PK_QUIT_KEY` | `y`, `n` (`⌃⌥ Q` quits Paneru) | `n` |
| `PK_WAKE` | `y`, `n` | `n` |

`./setup.sh --print` prints the config without changing anything.

## Troubleshooting

- **Something's stuck:** `paneru restart`.
- **Paneru isn't running:** `paneru start`.
- **A pop-up or app still tiles:** focus it and press `⌃⌥⇧ F` to float it. To make that
  permanent, press `⌃⌥⇧ C`, which copies a rule for it, and paste the rule at the end of
  `~/.paneru.toml`.
- **After a restart some windows are narrower:** Paneru re-applies the new-window width
  on start. Press `⌃⌥ F` to make one full width again. The wake add-on does this for you.
- **Logs:** `/tmp/com.github.karinushka.paneru_$(id -u).err.log`.

## Uninstall

```bash
./uninstall.sh
```

It removes the wake add-on and offers to put back the config you had before. Paneru
stays installed; the script prints how to remove it too.

## Contributing

Pull requests are welcome, especially Save/Open window titles in more languages, apps
that need a rule, and new presets. Run `tests/check.sh` before opening one; it checks
every script and validates each preset's config.

Problems in Paneru itself belong
[upstream](https://github.com/karinushka/paneru/issues).
[`docs/upstream-issues.md`](docs/upstream-issues.md) has drafts for the ones this kit
works around.

## License

MIT, like Paneru. See [LICENSE](LICENSE).
