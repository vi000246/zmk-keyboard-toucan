#!/usr/bin/env bash
# Build the Toucan *left half* firmware locally, in Docker.
#
# Mirrors zmkfirmware/zmk's build-user-config.yml@v0.3 exactly, including the
# part that is easy to miss: because this repo carries `zephyr/module.yml`, the
# west workspace must live OUTSIDE the repo (otherwise west's `zephyr` project
# collides with the repo's own `zephyr/` directory), and the repo is handed in
# via -DZMK_EXTRA_MODULES instead.
#
# Only the left half is built: it is the split central, so it is the only image
# that actually uses the keymap. The right half keeps the firmware it has.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="${REPO}-build"          # west workspace, deliberately a sibling of the repo
IMAGE="zmkfirmware/zmk-build-arm:stable"

BOARD="seeeduino_xiao_ble"
SHIELD="toucan_left rgbled_adapter toucan_pet"
SNIPPET="studio-rpc-usb-uart"   # without this ZMK Studio cannot reach the central
OUT="toucan_left-${BOARD}-zmk.uf2"

mkdir -p "$WS"

docker run --rm \
  -v "$REPO":/repo \
  -v "$WS":/ws \
  -w /ws \
  "$IMAGE" bash -c "
set -euo pipefail
mkdir -p /ws/config
cp -R /repo/config/. /ws/config/

if [ ! -d /ws/.west ]; then
  west init -l /ws/config
fi
west update --fetch-opt=--filter=tree:0
west zephyr-export

west build -s zmk/app -d /ws/build/left -b '${BOARD}' -S '${SNIPPET}' -- \
  -DZMK_CONFIG=/ws/config \
  -DSHIELD='${SHIELD}' \
  -DZMK_EXTRA_MODULES=/repo \
  -DCONFIG_ZMK_STUDIO=y -DCONFIG_ZMK_SLEEP=y -DCONFIG_ZMK_PM_SOFT_OFF=y

cp /ws/build/left/zephyr/zmk.uf2 '/ws/${OUT}'
ls -l '/ws/${OUT}'
"

echo
echo "firmware: ${WS}/${OUT}"
