#!/bin/bash
# paneru-kit setup
#
# Turns Paneru (https://github.com/karinushka/paneru), a free, open-source sliding window
# manager for macOS, into a ready-to-use Ribbon-style setup: every window sits on one
# horizontal strip and you slide along it with the keyboard or the trackpad.
#
# Run it again any time to change your answers; it remembers the last ones.
#
#   ./setup.sh                      interactive setup
#   ./setup.sh --preset minimal     start from another preset
#   ./setup.sh --yes                accept every default, no questions
#   ./setup.sh --print              only print the config it would write
#
# Written for the bash 3.2 that ships with macOS.

set -euo pipefail

KIT_VERSION="0.1.0"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$HOME/.paneru-kit"
CHOICES_FILE="$STATE_DIR/choices"
SERVICE_LABEL="com.github.karinushka.paneru"

# ----------------------------------------------------------------------------- options

PRESET=""
ASSUME_YES=0
PRINT_ONLY=0
OUTPUT=""

usage() {
    cat <<'EOF'
Usage: ./setup.sh [options]

  --preset NAME   Start from a preset: ribbon (default), minimal, keyboard
  --yes, -y       Don't ask questions; use the preset (or your last answers)
  --print         Print the generated config and exit. Changes nothing.
  --output FILE   Write the config to FILE instead of Paneru's config location
  --version       Print the paneru-kit version
  --help, -h      Show this help

Any answer can also be given as an environment variable, for example:
  PK_FINGERS=4 PK_GAP=8 ./setup.sh --yes
See README.md for the full list.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --preset) PRESET="${2:-}"; shift 2 ;;
        --preset=*) PRESET="${1#*=}"; shift ;;
        --yes|-y) ASSUME_YES=1; shift ;;
        --print) PRINT_ONLY=1; ASSUME_YES=1; shift ;;
        --output) OUTPUT="${2:-}"; shift 2 ;;
        --output=*) OUTPUT="${1#*=}"; shift ;;
        --version) echo "paneru-kit $KIT_VERSION"; exit 0 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

# ----------------------------------------------------------------------------- output helpers

if [ -t 1 ] && [ "$PRINT_ONLY" -eq 0 ]; then
    B=$'\033[1m'; D=$'\033[2m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'
else
    B=""; D=""; G=""; Y=""; R=""; N=""
fi

# Everything chatty goes to stderr so --print output stays clean.
say()  { printf '%s\n' "$*" >&2; }
head_() { printf '\n%s%s%s\n' "$B" "$*" "$N" >&2; }
ok()   { printf '%s✓%s %s\n' "$G" "$N" "$*" >&2; }
warn() { printf '%s!%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

interactive() { [ "$ASSUME_YES" -eq 0 ] && [ -t 0 ]; }

# ask VAR "Question" — free text, keeps the current value of VAR on Enter.
ask() {
    local var="$1" question="$2" current answer
    eval "current=\${$var}"
    interactive || return 0
    printf '%s %s[%s]%s ' "$question" "$D" "$current" "$N" >&2
    IFS= read -r answer || true
    [ -n "$answer" ] && eval "$var=\$answer"
    return 0
}

# ask_yn VAR "Question" — VAR holds y or n.
ask_yn() {
    local var="$1" question="$2" current answer
    eval "current=\${$var}"
    interactive || return 0
    while :; do
        if [ "$current" = "y" ]; then printf '%s %s[Y/n]%s ' "$question" "$D" "$N" >&2
        else printf '%s %s[y/N]%s ' "$question" "$D" "$N" >&2; fi
        IFS= read -r answer || true
        case "$answer" in
            "") return 0 ;;
            y|Y|yes|YES) eval "$var=y"; return 0 ;;
            n|N|no|NO) eval "$var=n"; return 0 ;;
        esac
    done
}

# ask_choice VAR "Question" "value|description" ... — numbered menu, Enter keeps VAR.
ask_choice() {
    local var="$1" question="$2" current answer i opt value desc
    shift 2
    eval "current=\${$var}"
    interactive || return 0
    say "$question"
    i=1
    for opt in "$@"; do
        value="${opt%%|*}"; desc="${opt#*|}"
        if [ "$value" = "$current" ]; then say "  $i) $desc ${G}(current)${N}"
        else say "  $i) $desc"; fi
        i=$((i + 1))
    done
    while :; do
        printf '%sChoose 1-%d, Enter keeps current:%s ' "$D" "$#" "$N" >&2
        IFS= read -r answer || true
        [ -z "$answer" ] && return 0
        case "$answer" in *[!0-9]*) continue ;; esac
        if [ "$answer" -ge 1 ] && [ "$answer" -le "$#" ]; then
            eval "opt=\${$answer}"
            eval "$var=\${opt%%|*}"
            return 0
        fi
    done
}

# ----------------------------------------------------------------------------- presets

# Every answer lives in one of these variables. A preset sets them all; saved answers or
# PK_* environment variables then override them.
CHOICE_VARS="PRESET MOD FINGERS SCROLL_MOD GAP NEW_WIDTH ANIM FFM NUMBER_KEYS STACKS \
FLOAT_DIALOGS FLOAT_APPS FORCE_APPS QUIT_KEY WAKE"

apply_preset() {
    # Shared defaults (the "ribbon" preset).
    MOD="ctrl + alt"        # shortcut modifier
    FINGERS="3"             # trackpad swipe: 3, 4 or off
    SCROLL_MOD="alt"        # hold while scrolling to slide the strip
    GAP="0"                 # px of wallpaper between and around windows
    NEW_WIDTH="0.5"         # width of new windows, or "app" to keep the app's own size
    ANIM="45"               # animation speed: higher is faster, "off" for instant
    FFM="n"                 # focus follows mouse
    NUMBER_KEYS="y"         # modifier + 1..9 jumps to the Nth window
    STACKS="y"              # stack / tab shortcuts
    FLOAT_DIALOGS="y"       # Save / Open pop-ups float
    FLOAT_APPS="Calculator, System Settings"
    FORCE_APPS="WhatsApp"   # apps Paneru skips by default but should tile
    QUIT_KEY="n"            # a shortcut that quits Paneru (easy to hit by accident)
    WAKE="n"                # restart Paneru after the Mac wakes from sleep

    case "$1" in
        ribbon|"") PRESET="ribbon" ;;
        minimal)
            PRESET="minimal"; GAP="8"; ANIM="20"; NUMBER_KEYS="n"; STACKS="n" ;;
        keyboard)
            PRESET="keyboard"; FINGERS="off" ;;
        *) die "Unknown preset '$1'. Use ribbon, minimal or keyboard." ;;
    esac
}

load_saved_choices() {
    [ -f "$CHOICES_FILE" ] || return 0
    # The file only ever holds VAR=value lines written by save_choices below.
    # shellcheck disable=SC1090
    . "$CHOICES_FILE"
}

save_choices() {
    mkdir -p "$STATE_DIR"
    {
        echo "# paneru-kit answers, read by ./setup.sh as defaults. Safe to delete."
        local v
        for v in $CHOICE_VARS; do
            eval "printf '%s=%q\n' \"\$v\" \"\${$v}\""
        done
    } > "$CHOICES_FILE"
}

apply_env_overrides() {
    local v env
    for v in $CHOICE_VARS; do
        env="PK_$v"
        if eval "[ -n \"\${$env+x}\" ]"; then eval "$v=\${$env}"; fi
    done
}

if [ -n "$PRESET" ]; then
    apply_preset "$PRESET"
else
    apply_preset ribbon
    if [ "$PRINT_ONLY" -eq 0 ]; then load_saved_choices; fi
fi
apply_env_overrides

# ----------------------------------------------------------------------------- validation

validate_choices() {
    case "$MOD" in
        "ctrl + alt"|"cmd + alt"|"ctrl + cmd"|"ctrl + alt + cmd") ;;
        *) die "PK_MOD must be one of: 'ctrl + alt', 'cmd + alt', 'ctrl + cmd', 'ctrl + alt + cmd'" ;;
    esac
    case "$FINGERS" in 3|4|off) ;; *) die "PK_FINGERS must be 3, 4 or off" ;; esac
    case "$SCROLL_MOD" in "alt"|"cmd + alt"|"ctrl + alt") ;;
        *) die "PK_SCROLL_MOD must be 'alt', 'cmd + alt' or 'ctrl + alt'" ;; esac
    case "$GAP" in ''|*[!0-9]*) die "PK_GAP must be a whole number of pixels" ;; esac
    [ "$GAP" -le 50 ] || die "PK_GAP can be at most 50"
    case "$NEW_WIDTH" in 0.3333|0.5|0.6667|1.0|app) ;;
        *) die "PK_NEW_WIDTH must be 0.3333, 0.5, 0.6667, 1.0 or app" ;; esac
    case "$ANIM" in 20|45|off) ;; *) die "PK_ANIM must be 20, 45 or off" ;; esac
    local v
    for v in FFM NUMBER_KEYS STACKS FLOAT_DIALOGS QUIT_KEY WAKE; do
        eval "case \"\${$v}\" in y|n) ;; *) die \"PK_$v must be y or n\" ;; esac"
    done
    return 0
}

# ----------------------------------------------------------------------------- questions

ask_questions() {
    head_ "Start from a preset"
    local before="$PRESET"
    ask_choice PRESET "Which setup is closest to what you want?" \
        "ribbon|Ribbon-style: edge-to-edge windows, 3-finger swipe, fast animations" \
        "minimal|Minimal: small gaps between windows, calmer animations, fewer shortcuts" \
        "keyboard|Keyboard-first: no trackpad gesture, every shortcut"
    if [ "$PRESET" != "$before" ]; then apply_preset "$PRESET"; fi

    head_ "Keyboard"
    ask_choice MOD "Which keys do the shortcuts start with? (Shift is added to move windows.)" \
        "ctrl + alt|Control + Option (⌃⌥) — rarely used by apps" \
        "cmd + alt|Command + Option (⌘⌥) — note: browsers use ⌘⌥←/→ to switch tabs" \
        "ctrl + cmd|Control + Command (⌃⌘)" \
        "ctrl + alt + cmd|Control + Option + Command (⌃⌥⌘) — for a Hyper key"
    ask_yn NUMBER_KEYS "Jump straight to the Nth window with $(pretty_mod) + 1…9?"
    ask_yn STACKS "Add shortcuts to stack windows vertically and show stacks as tabs?"
    ask_yn QUIT_KEY "Add $(pretty_mod) + Q to quit Paneru? (easy to press by accident)"

    head_ "Trackpad and mouse"
    ask_choice FINGERS "Slide along the strip with a trackpad swipe of…" \
        "3|Three fingers (macOS uses this for full-screen apps; see the note at the end)" \
        "4|Four fingers" \
        "off|No swipe gesture"
    ask_choice SCROLL_MOD "Hold which keys while scrolling to slide the strip? (always on)" \
        "alt|Option (⌥)" \
        "cmd + alt|Command + Option (⌘⌥)" \
        "ctrl + alt|Control + Option (⌃⌥)"
    ask_yn FFM "Focus a window just by moving the mouse over it?"

    head_ "Look"
    ask GAP "Gap between and around windows, in pixels (0 = edge to edge):"
    ask_choice NEW_WIDTH "How wide should new windows open?" \
        "0.5|Half the screen (opens in place, no resize jump)" \
        "0.3333|A third" \
        "0.6667|Two thirds" \
        "1.0|Full width" \
        "app|Whatever size the app picks (may visibly resize when it opens)"
    ask_choice ANIM "Animation speed" \
        "45|Fast (~0.15 s per move)" \
        "20|Smooth (~0.35 s per move)" \
        "off|Instant, no animation"

    head_ "Apps"
    ask_yn FLOAT_DIALOGS "Keep Save / Open pop-ups floating instead of on the strip?"
    ask FLOAT_APPS "Apps that should float (names, comma-separated, or 'none'):"
    ask FORCE_APPS "Apps Paneru ignores that should tile, e.g. WhatsApp (or 'none'):"

    head_ "Sleep and wake"
    say "${D}Some people find Paneru stops responding after the Mac wakes from sleep. This"
    say "add-on restarts it automatically when the screen comes back on after a real sleep.${N}"
    ask_yn WAKE "Install the wake add-on? (installs 'sleepwatcher' with Homebrew)"
}

pretty_mod() {
    case "$MOD" in
        "ctrl + alt") printf '⌃⌥' ;;
        "cmd + alt") printf '⌘⌥' ;;
        "ctrl + cmd") printf '⌃⌘' ;;
        "ctrl + alt + cmd") printf '⌃⌥⌘' ;;
    esac
}

# ----------------------------------------------------------------------------- apps

# Prints the bundle ID for an app name ("Calculator") or passes a bundle ID through.
bundle_id_for() {
    local name="$1" id
    case "$name" in
        Calculator) echo "com.apple.calculator"; return 0 ;;
        "System Settings"|"System Preferences") echo "com.apple.systempreferences"; return 0 ;;
        WhatsApp) echo "net.whatsapp.WhatsApp"; return 0 ;;
    esac
    case "$name" in *.*.*) echo "$name"; return 0 ;; esac    # already a bundle ID
    if id="$(osascript -e "id of application \"$name\"" 2>/dev/null)" && [ -n "$id" ]; then
        echo "$id"; return 0
    fi
    return 1
}

# Splits a comma-separated list into one trimmed name per line.
split_list() {
    local IFS=','
    local item
    for item in $1; do
        item="$(printf '%s' "$item" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [ -n "$item" ] && [ "$item" != "none" ] && printf '%s\n' "$item"
    done
    return 0
}

rule_name() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_' | sed -e 's/__*/_/g' -e 's/^_//' -e 's/_$//'
}

# ----------------------------------------------------------------------------- config

# Exact titles of standalone Save/Open windows. Anchored and case-insensitive, so a
# document called "Open Notes" or a chat called "Saved Messages" still tiles.
# English and Italian are confirmed; the others are best guesses — PRs welcome.
DIALOG_TITLES="save|save as|open|export|import|choose|choose file|choose folder|\
enter name of file to save to.*|file upload|\
salva|salva come|salva con nome|apri|esporta|importa|scegli|\
inserire il nome del file da salvare.*|caricamento file|\
speichern|speichern unter|sichern|öffnen|exportieren|importieren|auswählen|\
enregistrer|enregistrer sous|ouvrir|exporter|importer|choisir|\
guardar|guardar como|abrir|exportar|importar|elegir|seleccionar"

generate_config() {
    local m="$MOD" ms="$MOD + shift" n
    cat <<EOF
# Paneru config generated by paneru-kit $KIT_VERSION (preset: $PRESET).
# Re-run ./setup.sh to change it, or edit by hand: Paneru reloads this file on save.
# Every option: https://github.com/karinushka/paneru/blob/main/CONFIGURATION.md

[options]
focus_follows_mouse = $( [ "$FFM" = y ] && echo true || echo false )
mouse_follows_focus = false
# Widths that "resize" cycles through: quarter, third, half, two-thirds, three-quarters, full.
preset_column_widths = [0.25, 0.3333, 0.5, 0.6667, 0.75, 1.0]
EOF
    if [ "$ANIM" != "off" ]; then
        cat <<EOF
# Ease-out speed: a 1000 px move settles in about ln(1000)/speed seconds.
animation_speed = $ANIM
EOF
    fi
    if [ "$GAP" -eq 0 ]; then
        cat <<'EOF'
# Off-screen windows keep a sliver visible or macOS moves them. With no gap, the 5 px
# default shows as a strip over the edge of the visible window; 2 px stays in place.
sliver_width = 2
EOF
    fi

    cat <<EOF

[padding]
top = $GAP
bottom = $GAP
left = $GAP
right = $GAP

[swipe]
sensitivity = 0.35
continuous = false

# Hold these keys and scroll (two fingers or a mouse wheel) to slide the strip.
[swipe.scroll]
modifier = "$SCROLL_MOD"
EOF

    if [ "$FINGERS" != "off" ]; then
        cat <<EOF

# $FINGERS-finger left/right swipe slides the strip. Up/down swipes stay with macOS.
[swipe.gesture]
fingers_count = $FINGERS
direction = "Natural"
vertical = false
EOF
    fi

    cat <<EOF

[bindings]
# Move focus along the strip
window_focus_west  = "$m - leftarrow"
window_focus_east  = "$m - rightarrow"
window_focus_north = "$m - uparrow"
window_focus_south = "$m - downarrow"
window_focus_first = "$m - home"
window_focus_last  = "$m - end"
EOF
    if [ "$NUMBER_KEYS" = y ]; then
        echo ""
        echo "# Jump straight to the Nth window from the left"
        for n in 1 2 3 4 5 6 7 8 9; do
            echo "window_focus_$n = \"$m - $n\""
        done
    fi
    cat <<EOF

# Move the focused window along the strip
window_swap_west  = "$ms - leftarrow"
window_swap_east  = "$ms - rightarrow"
window_swap_north = "$ms - uparrow"
window_swap_south = "$ms - downarrow"
window_swap_first = "$ms - home"
window_swap_last  = "$ms - end"

# Widths
window_resize    = "$m - r"
window_shrink    = "$ms - r"
window_fullwidth = "$m - f"
window_center    = "$m - c"
window_balance   = "$m - b"
EOF
    if [ "$STACKS" = y ]; then
        cat <<EOF

# Stacks and tabs
window_stack         = "$m - s"
window_unstack       = "$ms - s"
window_tabbeddisplay = "$m - t"
window_equalize      = "$m - e"
EOF
    fi
    cat <<EOF

# Displays, floating, misc
window_nextdisplay = "$m - n"
window_manage      = "$ms - f"
window_copyrule    = "$ms - c"
EOF
    if [ "$QUIT_KEY" = y ]; then
        echo "quit               = \"$m - q\""
    fi

    if [ "$NEW_WIDTH" != "app" ]; then
        cat <<EOF

# New windows open at this width in one step, before joining the strip, instead of
# opening at the app's size and then animating. Rules merge per setting, so this only
# supplies the width.
[windows.default_width]
title = ".*"
width = $NEW_WIDTH
EOF
    fi

    if [ "$FLOAT_DIALOGS" = y ]; then
        cat <<EOF

# Save / Open pop-ups that some apps open as normal windows (e.g. Telegram) float.
[windows.file_dialogs]
title = '(?i)^($DIALOG_TITLES)\$'
floating = true
EOF
    fi

    app_rules force "manage = true" "$FORCE_APPS"
    app_rules float "floating = true" "$FLOAT_APPS"
}

# app_rules PREFIX "setting = value" "App, App" — one [windows.PREFIX_app] rule per app,
# skipping duplicates (TOML rejects two tables with the same name).
app_rules() {
    local prefix="$1" setting="$2" list="$3" name id key seen=" "
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        if ! id="$(bundle_id_for "$name")"; then
            warn "Couldn't find an app called '$name'; skipped. Use its bundle ID instead."
            continue
        fi
        key="$(rule_name "$id")"
        case "$seen" in *" $key "*) continue ;; esac
        seen="$seen$key "
        printf '\n[windows.%s_%s]\ntitle = ".*"\nbundle_id = "%s"\n%s\n' \
            "$prefix" "$key" "$id" "$setting"
    done <<EOF
$(split_list "$list")
EOF
}

# ----------------------------------------------------------------------------- install steps

find_brew() {
    if command -v brew >/dev/null 2>&1; then command -v brew; return 0; fi
    local b
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [ -x "$b" ] && { echo "$b"; return 0; }
    done
    return 1
}

find_paneru() {
    if command -v paneru >/dev/null 2>&1; then command -v paneru; return 0; fi
    local p
    for p in /opt/homebrew/bin/paneru /usr/local/bin/paneru; do
        [ -x "$p" ] && { echo "$p"; return 0; }
    done
    return 1
}

ensure_paneru() {
    PANERU="$(find_paneru || true)"
    if [ -n "$PANERU" ]; then ok "Paneru found: $PANERU"; return 0; fi
    local brew
    brew="$(find_brew)" || die "Homebrew isn't installed. Get it from https://brew.sh, then run this again."
    local install="y"
    ask_yn install "Paneru isn't installed. Install it now with Homebrew?"
    [ "$install" = y ] || die "Paneru is needed. Install it with: brew install paneru"
    "$brew" install paneru
    PANERU="$(find_paneru)" || die "Paneru still isn't on PATH after installing."
    ok "Paneru installed"
}

# Paneru reads the first of these that exists, so writing ~/.paneru.toml does nothing
# when another one is in the way.
config_target() {
    if [ -n "$OUTPUT" ]; then echo "$OUTPUT"; return 0; fi
    if [ -n "${PANERU_CONFIG:-}" ] && [ -e "$PANERU_CONFIG" ]; then echo "$PANERU_CONFIG"; return 0; fi
    if [ -f "$HOME/.paneru" ]; then echo "$HOME/.paneru"; return 0; fi
    echo "$HOME/.paneru.toml"
}

check_lua_override() {
    local f
    for f in "${PANERU_LUA:-}" "$HOME/.paneru.lua" "${XDG_CONFIG_HOME:-$HOME/.config}/paneru/init.lua"; do
        if [ -n "$f" ] && [ -f "$f" ]; then
            warn "Found a Lua config at $f. Paneru uses it instead of any TOML file,"
            warn "so this setup won't take effect until you move it away."
        fi
    done
    return 0
}

write_config() {
    local target="$1" tmp backup
    tmp="$(mktemp)"
    generate_config > "$tmp"
    mkdir -p "$(dirname "$target")"
    if [ -f "$target" ]; then
        if cmp -s "$tmp" "$target"; then
            rm -f "$tmp"; ok "Config unchanged: $target"; return 0
        fi
        backup="$target.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$target" "$backup"
        ok "Saved your previous config as $backup"
    fi
    mv "$tmp" "$target"
    ok "Wrote $target"
}

service_installed() {
    launchctl print "gui/$(id -u)/$SERVICE_LABEL" >/dev/null 2>&1
}

ensure_service() {
    if service_installed; then
        local restart="y"
        ask_yn restart "Restart Paneru now to apply everything?"
        if [ "$restart" = y ]; then "$PANERU" restart >/dev/null 2>&1 && ok "Paneru restarted"; fi
        return 0
    fi
    local start="y"
    ask_yn start "Set Paneru to start at login and start it now?"
    if [ "$start" = y ]; then
        "$PANERU" install && "$PANERU" start && ok "Paneru installed as a login service and started"
        say ""
        say "${B}One more step:${N} macOS will ask you to allow Paneru under"
        say "System Settings → Privacy & Security → Accessibility. Turn it on, then run:"
        say "  paneru restart"
    else
        say "Start it later with: paneru install && paneru start"
    fi
}

# Reads macOS's own trackpad gesture settings to spot a clash with the chosen swipe.
check_gesture_conflict() {
    [ "$FINGERS" = off ] && return 0
    local key val
    if [ "$FINGERS" = 3 ]; then key="TrackpadThreeFingerHorizSwipeGesture"
    else key="TrackpadFourFingerHorizSwipeGesture"; fi
    val="$(defaults read com.apple.AppleMultitouchTrackpad "$key" 2>/dev/null || echo "")"
    # These preference keys don't always match what System Settings shows, so this is a
    # hint, not a verdict.
    if [ "$val" = "2" ]; then
        warn "macOS may also use a $FINGERS-finger left/right swipe (to switch full-screen apps)."
        warn "If both move at once, check System Settings → Trackpad → More Gestures →"
        warn "'Swipe between full-screen applications' and pick the other finger count."
    fi
    return 0
}

install_wake_addon() {
    if [ "$WAKE" = y ]; then
        "$KIT_DIR/addons/wake-restart/install.sh" --paneru "$PANERU"
    elif [ -f "$HOME/Library/LaunchAgents/io.github.paneru-kit.wake.plist" ]; then
        local remove="y"
        ask_yn remove "The wake add-on is installed but you said no. Remove it?"
        if [ "$remove" = y ]; then "$KIT_DIR/addons/wake-restart/uninstall.sh"; fi
    fi
    return 0
}

print_cheatsheet() {
    local p; p="$(pretty_mod)"
    head_ "Your shortcuts"
    say "  $p ← →          move focus left / right"
    say "  $p ⇧ ← →        move the window left / right"
    say "  $p ⇧ Home/End   move the window to the start / end"
    [ "$NUMBER_KEYS" = y ] && say "  $p 1…9          jump to the Nth window"
    say "  $p R / $p ⇧ R    cycle width bigger / smaller"
    say "  $p F            full width on/off"
    say "  $p B            make every window this width"
    say "  $p ⇧ F          float / tile the focused window"
    [ "$STACKS" = y ] && say "  $p S / $p T      stack into the left column / show stack as tabs"
    [ "$QUIT_KEY" = y ] && say "  $p Q            quit Paneru"
    case "$FINGERS" in
        3|4) say "  $FINGERS-finger swipe   slide the strip" ;;
    esac
    say "  $(echo "$SCROLL_MOD" | sed -e 's/cmd/⌘/' -e 's/ctrl/⌃/' -e 's/alt/⌥/' -e 's/ + //g') + scroll      slide the strip"
    say ""
    say "Change anything: run ./setup.sh again. Restart Paneru: paneru restart"
}

# ----------------------------------------------------------------------------- main

validate_choices

if [ "$PRINT_ONLY" -eq 1 ]; then
    generate_config
    exit 0
fi

[ "$(uname -s)" = "Darwin" ] || die "paneru-kit only works on macOS."

say "${B}paneru-kit $KIT_VERSION${N} — a Ribbon-style setup for the Paneru window manager"
if interactive; then
    say "${D}Press Enter to keep the suggested answer.${N}"
    ask_questions
    validate_choices
fi

head_ "Installing"
ensure_paneru
check_lua_override
TARGET="$(config_target)"
write_config "$TARGET"
save_choices
if [ -n "$OUTPUT" ]; then
    # Writing somewhere else (a dotfiles repo, a test): leave the running Paneru alone.
    say "Wrote the config to $OUTPUT only; Paneru and the wake add-on were left as they are."
else
    install_wake_addon
    ensure_service
fi
check_gesture_conflict
print_cheatsheet
