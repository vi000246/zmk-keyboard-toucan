#!/usr/bin/env bash
# Regenerate config/toucan.keymap from the .vil, then re-apply the hand patches.
#
# Three things the exporter cannot know and this script owns:
#   1. layer names (a .vil does not store them)
#   2. &studio_unlock / &bootloader — ZMK-only keys with no QMK equivalent
#   3. the MOUSE layer, which the trackpad turns on by itself — a .vil has no
#      way to express "layer that follows the pointer"
#
# Every patch below asserts its target exists. A silent no-op here would ship a
# firmware that cannot be unlocked, which is unrecoverable without a
# settings_reset flash, so a missing anchor is a hard error.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KM="$REPO/backend"                     # keyboard-manager backend, for the exporter
KM_REPO="${KM_REPO:-$HOME/Projects/keyboard-manager}"
VIL="${VIL:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/beekeeb 36key.vil}"

"$KM_REPO/backend/.venv/bin/python" - "$KM_REPO" "$VIL" "$REPO" <<'PY'
import pathlib
import re
import sys

km_repo, vil, out = (pathlib.Path(a) for a in sys.argv[1:4])
sys.path.insert(0, str(km_repo))

from backend.parsers import zmk_export
from backend.parsers.vial import parse

# Layer names as the user calls them. Max 12 chars — the dongle screen's layer
# widget truncates at `char text[13]`.
LAYER_NAMES = ["BASE", "NAV", "NUM", "SYMBOL", "MEDIA", "FUN"]
assert all(len(n) <= 12 for n in LAYER_NAMES), "a name would be truncated on screen"

result = zmk_export.export(
    parse(vil), "toucan", source_name=vil.name, layer_names=LAYER_NAMES
)
for name, body in result.files.items():
    (out / name).write_text(body)

keymap = out / "config" / "toucan.keymap"
text = keymap.read_text()


def patch(pattern: str, replacement: str) -> None:
    """Rewrite exactly one match, or fail.

    The exporter pads bindings into aligned columns, so the amount of whitespace
    between them is not stable across regenerations — patterns match on `\\s+`
    and assert a single hit rather than trusting a literal string.
    """
    global text
    text, n = re.subn(pattern, replacement, text, count=1)
    if n != 1:
        raise SystemExit(f"patch matched {n} times, refusing to ship:\n{pattern}")


# ── Patch 1: &studio_unlock as a combo ───────────────────────────────────────
# This board is the 36-key build: the outer pinky columns (positions 0, 11, 12,
# 23, 24, 35) have no switch soldered, so a binding there can never be pressed.
# Every one of the 36 real keys is already in use on the base layer, and putting
# the unlock behind a layer-tap means holding a thumb past the 200 ms tapping
# term first (flavor is tap-preferred) — a bad property for the one key that
# rescues a broken keymap.
#
# A combo needs no free key and no layer: positions 25 and 34 are the two bottom
# pinky keys (Z and /), one per hand. `require-prior-idle-ms` means it only fires
# after a pause, so fast typing cannot trigger it by accident — and an accidental
# fire is harmless anyway: &studio_unlock emits no keycode, it only permits
# Studio edits (verified in zmk/app/src/behaviors/behavior_studio_unlock.c).
patch(
    r'(combos \{\n\s*compatible = "zmk,combos";\n)',
    r'\1'
    "        combo_studio_unlock {\n"
    "            // Hand-added, not from the .vil — see regen.sh.\n"
    "            // Z + / together, after a brief pause. Unlocks ZMK Studio.\n"
    "            timeout-ms = <200>;\n"
    "            require-prior-idle-ms = <500>;\n"
    "            key-positions = <25 34>;\n"
    "            bindings = <&studio_unlock>;\n"
    "        };\n\n",
)

# ── Patch 2: NAV layer keeps a backup unlock plus the bootloader key ─────────
# Both positions sat empty (KC_NO) on this layer. Positions 1 and 2 are left
# alone on purpose: combo_3 (Q+W → M6) already claims that pair on every layer.
patch(
    r'(display-name = "NAV";\n)(\s*bindings = <\n\s*)'
    r'&none\s+&none\s+&none\s+&none\s+&none(\s+&macro1)',
    r'\1'
    "            /*\n"
    "             * Positions 3 and 4 are hand-added (see regen.sh):\n"
    "             *   &studio_unlock — a second way in if the Z + / combo ever\n"
    "             *                    stops working. Left thumb ESC + E, and\n"
    "             *                    the thumb must be held past 200 ms.\n"
    "             *   &bootloader    — left thumb ESC + R. Saves prying the\n"
    "             *                    dongle out to double-tap RST on a reflash.\n"
    "             */\n"
    r'\2&none  &none  &none  &studio_unlock  &bootloader\3',
)

# ── Patch 3: the MOUSE layer ────────────────────────────────────────────────
# A .vil has no concept of "the layer that turns itself on when the trackpad
# moves", so this layer only exists here. It is driven by `&mouse_temp_layer 6
# 1000` on the input listener in boards/shields/toucan/toucan.dtsi, and the
# seven positions bound below must stay in step with that node's
# `excluded-positions` — a key that is not excluded switches the layer off the
# moment it is pressed, which for a click key means it never works.
MOUSE_LAYER = """\
        /*
         * MOUSE — hand-added, see regen.sh. Switched on automatically while
         * the trackpad is moving, by `&mouse_temp_layer 6 1000` in
         * boards/shields/toucan/toucan.dtsi. It drops again 1 s after the last
         * movement, or as soon as you press a key that is not in that node's
         * `excluded-positions`.
         *
         * Everything is on the LEFT hand on purpose: the trackpad lives on the
         * right half, so the hand that is not on the pad does the clicking.
         *
         * Those excluded positions are the seven keys bound below (r t /
         * d f g / v b — positions 4 5 15 16 17 28 29). Move a binding here and
         * you must move the position there, or clicking switches the layer off
         * under you.
         */
        layer_6 {
            display-name = "MOUSE";
            bindings = <
            &trans  &trans  &trans  &trans      &kp PG_UP   &kp PG_DN   &trans  &trans  &trans  &trans  &trans  &trans
            &trans  &trans  &trans  &mkp LCLK   &mkp RCLK   &mkp MCLK   &trans  &trans  &trans  &trans  &trans  &trans
            &trans  &trans  &trans  &trans      &kp HOME    &kp END     &trans  &trans  &trans  &trans  &trans  &trans
            &trans  &trans  &trans  &trans  &trans  &trans
            >;
        };

"""

patch(r'( *extra_1 \{\n)', MOUSE_LAYER + r'\1')

keymap.write_text(text)
print(f"regenerated {len(result.files)} files, 3 patches applied")
print(f"warnings: {len(result.warnings)}")
for w in result.warnings:
    print("  -", w)
PY
