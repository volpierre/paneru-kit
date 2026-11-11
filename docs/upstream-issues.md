# Issues to report to Paneru

paneru-kit works around these in config or with scripts. Each one would be better fixed
in [Paneru itself](https://github.com/karinushka/paneru/issues). These are drafts:
before filing one, check it still happens on the latest Paneru and add your macOS
version and logs.

---

## 1. Paneru sometimes stops responding after the Mac wakes and needs a restart

**Seen on:** Paneru 0.5.2, macOS 27, Apple M1 laptop.

After opening the lid, Paneru sometimes stops managing windows until it's restarted
with `paneru restart`. The log shows no error or warning at the time, only the usual
`can not get current focus` lines. In one user's `pmset -g log`, 4 of 9 lid-open wakes
over two days were followed by a manual restart within about two minutes.

Paneru already reconciles displays on `SystemWoke` (`ecs/display.rs`), so the cause is
probably something else that goes stale across sleep.

**Workaround in paneru-kit:** `addons/wake-restart` restarts Paneru when the display
turns on after a real sleep.

---

## 2. Standalone Save panels are tiled

Some apps (Telegram from the Mac App Store, for example) show the Save panel as its own
window with subrole `AXStandardWindow` and the title "Save". Paneru tiles it like any
other window, so a small dialog becomes a full-height column on the strip.

**Suggestion:** float windows that belong to the open/save panel service, or detect
`NSSavePanel` / `NSOpenPanel` windows another way.

**Workaround in paneru-kit:** a window rule that floats exact titles such as "Save",
"Open" and their translations.

---

## 3. Catalyst apps (WhatsApp) aren't managed by default

WhatsApp for Mac (`net.whatsapp.WhatsApp`, an iPad app built with Catalyst) isn't
tiled unless a rule sets `manage = true`. Once, after a restart of the Mac, it also
wasn't picked up when launched about 30 minutes after Paneru, even with the rule. This
didn't happen again when the app was relaunched. A `Tap Disabled, re-enabling` warning
was logged 8 seconds after that launch.

**Workaround in paneru-kit:** a `manage = true` rule for WhatsApp, plus a setup question
for other apps.

---

## 4. A restart resets window widths when a `width` rule matches every window

With `[windows.x] title = ".*"` and `width = 0.5`, restarting Paneru resizes every
existing window to half width, including ones the user had set to full width. Session
restore brings back the order but not the widths.

**Suggestion:** apply `width` rules only to windows created after startup, or restore
widths from the saved session.

**Workaround in paneru-kit:** the wake add-on records full-width windows before
restarting and sets them back afterwards.
