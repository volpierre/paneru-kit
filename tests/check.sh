#!/bin/bash
# Checks paneru-kit without touching your setup: syntax of every script, every preset's
# generated config (valid TOML, known options, known shortcut names), a few answer
# combinations, and that examples/ is up to date.
#
#   tests/check.sh            run the checks
#   tests/check.sh --update   regenerate examples/ first
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0

pass() { printf '  ok    %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; FAILS=$((FAILS + 1)); }

# Python 3.11+ has tomllib; macOS's own python3 is older, so look for a newer one.
PY=""
for p in python3.13 python3.12 python3.11 python3; do
    if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import tomllib' 2>/dev/null; then PY="$p"; break; fi
done

echo "Scripts"
for f in "$ROOT"/setup.sh "$ROOT"/uninstall.sh "$ROOT"/addons/wake-restart/*.sh "$ROOT"/tests/*.sh; do
    if bash -n "$f"; then pass "bash -n ${f#$ROOT/}"; else fail "bash -n ${f#$ROOT/}"; fi
done
if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -S warning "$ROOT"/setup.sh "$ROOT"/uninstall.sh "$ROOT"/addons/wake-restart/*.sh; then
        pass "shellcheck"; else fail "shellcheck"; fi
else
    echo "  skip  shellcheck (not installed)"
fi
if python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$ROOT/addons/wake-restart/restart_paneru.py"; then
    pass "restart_paneru.py parses"; else fail "restart_paneru.py parses"; fi

# validate FILE — TOML parses, only known sections/options/bindings, rules have a title.
validate() {
    [ -n "$PY" ] || { echo "  skip  TOML checks (needs Python 3.11+)"; return 0; }
    "$PY" - "$1" <<'EOF'
import re, sys, tomllib
cfg = tomllib.load(open(sys.argv[1], "rb"))
known = {
    "options": {"focus_follows_mouse", "mouse_follows_focus", "preset_column_widths",
                "animation_speed", "sliver_width"},
    "padding": {"top", "bottom", "left", "right"},
    "swipe": {"sensitivity", "continuous", "scroll", "gesture"},
    "bindings": None, "windows": None,
}
bindings = re.compile(
    r"^(quit|window_(focus|swap)_(west|east|north|south|first|last|[1-9])|"
    r"window_(resize|shrink|fullwidth|center|balance|stack|unstack|tabbeddisplay|"
    r"equalize|nextdisplay|manage|copyrule))$")
key = re.compile(r"^((ctrl|alt|cmd|shift)( \+ (ctrl|alt|cmd|shift))*) - "
                 r"(leftarrow|rightarrow|uparrow|downarrow|home|end|[a-z0-9])$")
errors = []
for section, value in cfg.items():
    if section not in known:
        errors.append(f"unknown section [{section}]")
    elif known[section] is not None:
        errors += [f"unknown option {section}.{k}" for k in value if k not in known[section]]
for name, combo in cfg.get("bindings", {}).items():
    if not bindings.match(name):
        errors.append(f"unknown binding {name}")
    if not key.match(combo):
        errors.append(f"bad key combo {name} = {combo!r}")
combos = list(cfg.get("bindings", {}).values())
errors += [f"key used twice: {c}" for c in set(combos) if combos.count(c) > 1]
for name, rule in cfg.get("windows", {}).items():
    if "title" not in rule:
        errors.append(f"rule {name} has no title")
    re.compile(rule.get("title", ""))
gesture = cfg.get("swipe", {}).get("gesture")
if gesture and gesture.get("fingers_count") not in (3, 4):
    errors.append("fingers_count must be 3 or 4")
if errors:
    print("\n".join("        " + e for e in errors))
    sys.exit(1)
EOF
}

echo "Presets"
for preset in ribbon minimal keyboard; do
    out="$TMP/$preset.toml"
    if "$ROOT/setup.sh" --preset "$preset" --print > "$out" 2>"$TMP/err" && validate "$out"; then
        pass "$preset"
    else
        fail "$preset"; cat "$TMP/err"
    fi
done

echo "Answer combinations"
combo() {   # combo "description" "grep pattern" [present|absent] VAR=value...
    local desc="$1" pattern="$2" want="$3"; shift 3
    local out="$TMP/combo.toml"
    if ! env "$@" "$ROOT/setup.sh" --preset ribbon --print > "$out" 2>"$TMP/err"; then
        fail "$desc (setup.sh failed)"; cat "$TMP/err"; return
    fi
    validate "$out" || { fail "$desc (invalid config)"; return; }
    if grep -qE -- "$pattern" "$out"; then found=present; else found=absent; fi
    if [ "$found" = "$want" ]; then pass "$desc"; else fail "$desc: '$pattern' $found"; fi
}
combo "no gesture"            '^\[swipe.gesture\]'        absent  PK_FINGERS=off
combo "four fingers"          '^fingers_count = 4'        present PK_FINGERS=4
combo "gap 8, default sliver" '^sliver_width'             absent  PK_GAP=8
combo "gap 8 applied"         '^left = 8'                 present PK_GAP=8
combo "instant animation"     '^animation_speed'          absent  PK_ANIM=off
combo "app-sized windows"     'default_width'             absent  PK_NEW_WIDTH=app
combo "cmd + alt shortcuts"   '"cmd \+ alt \+ shift - r"' present "PK_MOD=cmd + alt"
combo "hyper shortcuts"       '"ctrl \+ alt \+ cmd - 1"'  present "PK_MOD=ctrl + alt + cmd"
combo "no number keys"        '^window_focus_1 '          absent  PK_NUMBER_KEYS=n
combo "quit key"              '^quit '                    present PK_QUIT_KEY=y
combo "no file dialogs rule"  'file_dialogs'              absent  PK_FLOAT_DIALOGS=n
combo "bundle ID passthrough" 'bundle_id = "com.example.app"' present "PK_FLOAT_APPS=com.example.app"
combo "duplicate app once"    '^\[windows.float_com_apple_calculator\]' present "PK_FLOAT_APPS=Calculator, calculator, com.apple.calculator"
combo "no apps"               '^\[windows.(float|force)_' absent  PK_FLOAT_APPS=none PK_FORCE_APPS=none

if env PK_FINGERS=5 "$ROOT/setup.sh" --print >/dev/null 2>&1; then
    fail "rejects PK_FINGERS=5"; else pass "rejects PK_FINGERS=5"; fi
if env PK_GAP=wide "$ROOT/setup.sh" --print >/dev/null 2>&1; then
    fail "rejects PK_GAP=wide"; else pass "rejects PK_GAP=wide"; fi

echo "Examples"
if [ "${1:-}" = "--update" ]; then
    for preset in ribbon minimal keyboard; do
        "$ROOT/setup.sh" --preset "$preset" --print > "$ROOT/examples/$preset.toml"
    done
fi
for preset in ribbon minimal keyboard; do
    if "$ROOT/setup.sh" --preset "$preset" --print 2>/dev/null | cmp -s - "$ROOT/examples/$preset.toml"; then
        pass "examples/$preset.toml up to date"
    else
        fail "examples/$preset.toml is stale: run tests/check.sh --update"
    fi
done

echo
if [ "$FAILS" -eq 0 ]; then echo "All checks passed."; else echo "$FAILS check(s) failed."; exit 1; fi
