#!/usr/bin/env bash
# Flash one Toucan board, after proving which board is actually in bootloader.
#
#   ./flash.sh dongle
#   ./flash.sh left
#   ./flash.sh right
#
# Read FLASHING.md before changing anything here. The short version: every board
# mounts a volume, none of them says which board it is in the volume name alone,
# and writing the wrong .uf2 turns a keyboard half into a dead dongle. This
# script identifies the board from INFO_UF2.TXT's Board-ID and refuses on any
# mismatch.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${REPO}-build"
TIMEOUT_S="${TIMEOUT_S:-900}"

# Board-ID as reported by INFO_UF2.TXT. The dongle is a XIAO nRF52840 *Sense*;
# the halves are XIAO nRF52840 *Plus* modules — physically different hardware,
# which is why this check is trustworthy rather than a naming convention.
#
# Caveat, stated plainly: Board-ID separates the dongle from a half, but NOT the
# left half from the right half. For those, the USB-serial check below is the
# only discriminator, and only the left half's serial is known.
BOARDID_DONGLE="Seeed_XIAO_nRF52840_Sense"
BOARDID_HALF="nRF52840-SeeedXiao-v1"

SERIAL_DONGLE="6D1223706D497DBF"
SERIAL_LEFT="B2AF9AAE792235E5"

case "${1:-}" in
  dongle)
    UF2="$BUILD/toucan_dongle-seeeduino_xiao_ble-zmk.uf2"
    WANT_BOARDID="$BOARDID_DONGLE"
    MUST_VANISH="$SERIAL_DONGLE"
    ;;
  left)
    UF2="$BUILD/ci/firmware/toucan_left rgbled_adapter toucan_pet-seeeduino_xiao_ble-zmk.uf2"
    WANT_BOARDID="$BOARDID_HALF"
    MUST_VANISH="$SERIAL_LEFT"
    ;;
  right)
    UF2="$BUILD/ci/firmware/toucan_right rgbled_adapter-seeeduino_xiao_ble-zmk.uf2"
    WANT_BOARDID="$BOARDID_HALF"
    MUST_VANISH=""   # serial not recorded yet — see FLASHING.md
    ;;
  *)
    echo "usage: $0 {dongle|left|right}" >&2
    exit 64
    ;;
esac

[ -f "$UF2" ] || { echo "missing firmware: $UF2" >&2; exit 1; }

zmk_serials() {
  ioreg -p IOUSB -w0 -l 2>/dev/null \
    | grep -A 25 '"USB Product Name" = "Toucan"' \
    | grep '"USB Serial Number"' \
    | sed 's/.*= "\(.*\)"/\1/'
}

find_volume() {
  for v in /Volumes/XIAO-*; do
    [ -d "$v" ] && [ -f "$v/INFO_UF2.TXT" ] && { echo "$v"; return 0; }
  done
  return 1
}

echo "target:   $1"
echo "firmware: $UF2"
echo "          $(stat -f '%z bytes, built %Sm' -t '%Y-%m-%d %H:%M' "$UF2")"
echo
if [ "$1" = "dongle" ]; then
  echo "Double-tap RST on the DONGLE's XIAO (the button beside its USB-C port)."
  echo "The &bootloader key cannot do this: ZMK runs reset behaviors on the side"
  echo "where the key is pressed, so it only ever resets a keyboard half."
else
  echo "Double-tap RST on the $1 half's XIAO (the button beside its USB-C port,"
  echo "silkscreened RST)."
fi
echo

before="$(zmk_serials)"
deadline=$(( $(date +%s) + TIMEOUT_S ))
printf 'waiting for a XIAO bootloader volume '
while ! VOL="$(find_volume)"; do
  [ "$(date +%s)" -lt "$deadline" ] || { echo; echo "timed out, nothing written" >&2; exit 1; }
  printf '.'
  sleep 1
done
echo " found: $VOL"

board_id="$(sed -n 's/^Board-ID: //p' "$VOL/INFO_UF2.TXT" | tr -d '\r')"
echo "board-id: $board_id"

if [ "$board_id" != "$WANT_BOARDID" ]; then
  echo >&2
  echo "ABORT: that is not the $1." >&2
  echo "       expected Board-ID $WANT_BOARDID, found $board_id" >&2
  [ "$board_id" = "$BOARDID_DONGLE" ] && echo "       (that board is the dongle)" >&2
  [ "$board_id" = "$BOARDID_HALF" ] && echo "       (that board is a keyboard half)" >&2
  exit 1
fi

# Second, independent check: the board now in bootloader must have dropped off
# the USB device list. Board-ID cannot tell left from right, so for a half this
# is what stops a right-half flash landing on the left.
if [ -n "$MUST_VANISH" ]; then
  now="$(zmk_serials)"
  if grep -q "$MUST_VANISH" <<<"$now"; then
    echo "ABORT: $MUST_VANISH is still enumerated, so the $1 is not the board in bootloader" >&2
    exit 1
  fi
  if grep -q "$MUST_VANISH" <<<"$before"; then
    echo "confirmed: $MUST_VANISH left the USB bus"
  fi
fi

# `cp` reports a bogus xattr failure here: the bootloader reboots the instant the
# .uf2 finishes writing, so the volume is unmounted before macOS sets attributes.
# The data landed. The volume disappearing IS the success signal.
cp "$UF2" "$VOL/" 2>/dev/null || true
sync
echo "flashed $1 — it reboots on its own"

if [ "$1" = "dongle" ]; then
  echo
  echo "If this changed the KEYMAP (not just input processors), connect ZMK"
  echo "Studio and run 'Restore Stock Settings' — Studio's stored keymap"
  echo "overrides the compiled one and the flash will otherwise look inert."
fi
