# ZMK config for beekeeb Toucan2 Keyboard

[The beekeeb Toucan Keyboard](https://beekeeb.com/toucan-keyboard/) is a wireless split 42-key column‑stagger keyboard that a display and a trackpad, with an aggressive stagger on the pinky columns.

> ⚠️ **這份 config 目前只能刷 Toucan2，不能刷 Toucan1。**
>
> 這個 repo 原本 fork 自 [`beekeeb/zmk-keyboard-toucan`](https://github.com/beekeeb/zmk-keyboard-toucan)（v1），
> 2026-09-03 起觸控板改成 Toucan2 的硬體。兩代的觸控板完全不同，而且腳位對撞：
>
> | | Toucan1 | Toucan2 |
> |---|---|---|
> | 感測器 | Cirque Pinnacle | Azoteq TPS43 |
> | 匯流排 | SPI0 | I2C0 @ 0x74 |
> | 驅動 | `geeksville/cirque-input-module` | `beekeeb/zmk_driver_azoteq` |
> | P1.13 / P1.15 | SPIM_SCK / MOSI | TWIM_SDA / SCL |
> | P1.14 / P0.02 | SPIM_MISO / Cirque DR | RST / RDY |
>
> 刷錯代的結果是**觸控板完全沒反應**（游標不動、PAD 層不升），但**按鍵完全正常**
> ——因為 kscan 那 10 根腳兩代逐字相同。這個症狀很容易被誤判成韌體迴歸，
> 實際上是硬體對不上。要刷回 Toucan1 請 revert「觸控板換成 Azoteq TPS43」那個
> commit，官方 v1 config 也還在上游。
>
> 上游的 Toucan2 官方 config：[`beekeeb/zmk-keyboard-toucan2`](https://github.com/beekeeb/zmk-keyboard-toucan2)

# License

The code in this repo is available under the MIT license.

The included shield nice_view_gem is modified from https://github.com/M165437/nice-view-gem licensed under the MIT License.

ZMK code snippets are taken from the ZMK documentation under the MIT license.

The embedded font QuinqueFive is designed by GGBotNet, licensed under under the SIL Open Font License, Version 1.1.
