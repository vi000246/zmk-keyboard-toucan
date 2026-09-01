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
    cat >&2 <<'MSG'
dongle 已經不是這個 repo 的建置目標了（2026-09-01 起）。

左半改當 split central，dongle 退出訊號路徑、變成純顯示器：請從
t-ogura 的 release 下載 Prospector scanner 韌體手動拖進 bootloader 磁碟：

  https://github.com/t-ogura/zmk-config-prospector/releases
  prospector_scanner-xiao_ble_nrf52840_zmk-zmk.uf2

⚠️ 不要把舊的 toucan_dongle 韌體刷回去：它也是 central，會跟左半搶同一個
   右半，症狀是右半時連時不連。真的要 rollback 就先把 build.yaml 和
   Kconfig.defconfig 一起 revert，再照 FLASHING.md 重跑一次配對。
MSG
    exit 64
    ;;
  left)
    # 本機 ./build-left.sh 的產物優先，其次是 GitHub Actions 下載下來的。
    UF2="$BUILD/toucan_left-seeeduino_xiao_ble-zmk.uf2"
    [ -f "$UF2" ] || UF2="$BUILD/ci/firmware/toucan_left rgbled_adapter toucan_pet-seeeduino_xiao_ble-zmk.uf2"
    WANT_BOARDID="$BOARDID_HALF"
    MUST_VANISH="$SERIAL_LEFT"
    ;;
  right)
    UF2="$BUILD/ci/firmware/toucan_right rgbled_adapter-seeeduino_xiao_ble-zmk.uf2"
    WANT_BOARDID="$BOARDID_HALF"
    MUST_VANISH=""   # serial not recorded yet — see FLASHING.md
    ;;
  # settings_reset：抹掉板子上所有 BLE bond 與設定。切換 central 角色時
  # 兩個半邊都必須先跑一次——ZMK 的 peripheral 只要還記得舊 central，就
  # 只對那個位址做 directed advertising，新的 central 永遠連不上它。
  # 刷完之後板子是空的，必須馬上把正式韌體刷回去。
  reset-left)
    UF2="$BUILD/ci/firmware/settings_reset-seeeduino_xiao_ble-zmk.uf2"
    WANT_BOARDID="$BOARDID_HALF"
    MUST_VANISH="$SERIAL_LEFT"
    ;;
  reset-right)
    UF2="$BUILD/ci/firmware/settings_reset-seeeduino_xiao_ble-zmk.uf2"
    WANT_BOARDID="$BOARDID_HALF"
    MUST_VANISH=""   # serial not recorded yet — see FLASHING.md
    ;;
  *)
    echo "usage: $0 {left|right|reset-left|reset-right}" >&2
    echo "       (dongle 已退出建置，執行 '$0 dongle' 會說明原因)" >&2
    exit 64
    ;;
esac

[ -f "$UF2" ] || { echo "missing firmware: $UF2" >&2; exit 1; }

zmk_serials() {
  # Empty output is the normal, expected case — every board can be in
  # bootloader at once. Without the `|| true` the grep's exit status 1 trips
  # pipefail, the failing command substitution trips `set -e`, and the script
  # dies at exactly the moment it is trying to confirm a board went away.
  { ioreg -p IOUSB -w0 -l 2>/dev/null \
      | grep -A 25 '"USB Product Name" = "Toucan"' \
      | grep '"USB Serial Number"' \
      | sed 's/.*= "\(.*\)"/\1/'; } || true
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
case "$1" in
  left|reset-left)
    echo "把左半送進 bootloader。兩種方法都行："
    echo "  a) MEDIA 層按住位置 40 進 BT 層，按 B（&bootloader）。"
    echo "     reset behavior 重置的是「按下它的那一側」——左半正是目標。"
    echo "  b) 連按兩下左半 XIAO 上的 RST 鈕（USB-C 接頭旁，絲印 RST）。"
    ;;
  *)
    echo "連按兩下右半 XIAO 上的 RST 鈕（USB-C 接頭旁，絲印 RST）。"
    echo "keymap 上的 &bootloader 只會重置左半，對右半沒用。"
    ;;
esac
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

case "$1" in
  reset-*)
    echo
    echo "⚠️ 這顆板子現在是空的（bond 和設定都被抹掉）。"
    echo "   馬上把正式韌體刷回去：./flash.sh ${1#reset-}"
    ;;
  left)
    echo
    echo "左半是 split central，也是唯一真正使用 keymap 的映像。改了 keymap"
    echo "之後若行為沒變，連上 ZMK Studio 執行一次 'Restore Stock Settings'"
    echo "——Studio 存在裝置上的 keymap 會覆蓋編譯進去的那份。"
    echo
    echo "（input processor：觸控板速度、方向、自動切層——刷完立即生效，"
    echo "  不受 Studio 影響。）"
    ;;
esac
