#!/usr/bin/env bash
# Wait for a XIAO in bootloader mode, then flash the dongle firmware onto it.
#
# Why this asks before copying: the dongle and both halves are all
# seeeduino_xiao_ble, and every one of them mounts as the same volume name. A
# script that copied the moment a volume appeared would happily write dongle
# firmware onto the right half — which takes the trackpad with it. So it shows
# you what it found and waits for a yes.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UF2="${REPO}-build/toucan_dongle-seeeduino_xiao_ble-zmk.uf2"
VOL="${VOL:-/Volumes/XIAO-SENSE}"

if [ ! -f "$UF2" ]; then
  echo "no firmware at $UF2 — run ./build-dongle.sh first" >&2
  exit 1
fi

echo "firmware: $UF2"
echo "          $(stat -f '%z bytes, built %Sm' -t '%Y-%m-%d %H:%M' "$UF2")"
echo
echo "Put the DONGLE into bootloader mode:"
echo "  · press left-thumb ESC + R  (the &bootloader key on NAV), or"
echo "  · unplug it and double-tap the RST button"
echo
printf 'waiting for %s ' "$VOL"
until [ -d "$VOL" ]; do
  printf '.'
  sleep 1
done
echo " found"
echo

ls -l "$VOL" | head -5
echo
read -r -p "Is this the DONGLE (not a keyboard half)? [y/N] " reply
case "$reply" in
  [yY]*) ;;
  *) echo "aborted, nothing written"; exit 1 ;;
esac

cp "$UF2" "$VOL/"
sync
echo "copied — the dongle reboots on its own"
echo
echo "NEXT: connect ZMK Studio and run 'Restore Stock Settings'."
echo "Studio's stored keymap overrides the compiled one, so without that step"
echo "the new keymap and MOUSE layer will not appear and the flash will look"
echo "like it did nothing."
