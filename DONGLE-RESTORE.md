# Dongle 自訂 layout：做了什麼、怎麼還原

2026-09-02 起，dongle（Prospector 螢幕）的韌體改成**在這個 repo 自建**，
不再直接用 t-ogura 的 release `.uf2`。這份文件記錄改了什麼，以及兩個層級的
還原步驟。

## 自訂了什麼

| 項目 | 內容 |
|---|---|
| 預設 layout | Radii（layout 3）。2026-09-03 起**整個重寫成 Toucan 專用的儀表板**，見下表。仍是唯一**沒有 WPM 手速統計**的 layout |
| 儀表板版面 | 左緣 17 格 ladder（一格一層）＋ 大字層名（固定 4 字元單行）＋ 兩行英文副標 ＋ 電量數字/bar ＋ 修飾鍵 2×2 ＋ BLE 四點。全暗底 |
| 層名來源 | 大字用**廣播帶來的 display-name**；副標走 `radii_layout.c` 的本地 `LAYERS[]` 表，用 `active_layer` 當 index 查，不受廣播 4 bytes 限制 |
| SYM 按鍵小抄 | 廣播層名 = `SYM` 時，dongle 全螢幕蓋一張 3×10 的符號小抄；離開該層自動消失。面板寬度已從 240 修正為 280（原本右邊會漏 40px） |
| ladder 格數 | 由 `radii_layout.c` 的 `LAYERS[]` 筆數決定（目前 17），配 `BUILD_ASSERT`。**不再讀 `CONFIG_PROSPECTOR_MAX_LAYERS`**——那個上限只到 10，裝不下 17 層，正是改寫的原因之一 |

## 動到的檔案（= 要還原就動這些）

```
scanner/                  ← scanner 專用 west manifest + conf + build 矩陣（新增）
scanner-module/           ← vendor 進來的 t-ogura/prospector-zmk-module v2.2.3（新增）
scanner-module/boards/shields/prospector_scanner/src/radii_layout.c
                          ← 唯一有改程式碼的檔案：SYM 小抄 overlay
                             （搜 "SYM 按鍵小抄" 或 CHEAT_LAYER_NAME）
.github/workflows/build.yml  ← 加了第二個 job "scanner"
```

vendor 基準版本：`t-ogura/prospector-zmk-module` **v2.2.3**（未改動的部分
與 upstream tarball 完全相同，唯一例外：upstream 的 `.gitignore` 沒有帶
進來——它的 `zmk/`、`zephyr/`、`modules/` 規則會把 `include/zmk/`、
`zephyr/module.yml` 等「必要檔案」擋在 git 之外，害 CMake 認不得這個
module）。scanner 的 zmk 釘在 main 的
`641514a97db345f499dd50b0360e594270f008fe`（2026-09-02）。

⚠️ 注意：這跟**鍵盤**韌體完全無關。鍵盤端（`config/west.yml`）釘的
prospector-zmk-module v2.0.0 只管「發廣播」，dongle 只是被動收聽——
dongle 刷什麼、還原成什麼，都不影響鍵盤，也不用重新配對。

## 平常怎麼用

1. push 之後 GitHub Actions 會多產出一個 **`prospector_scanner_custom`**
   artifact（跟鍵盤的 `firmware` 分開）。
2. 解壓拿到 `prospector_scanner-xiao_ble_nrf52840_zmk-zmk.uf2`。
3. Dongle 的 XIAO 連按兩下 RST 進 bootloader，把 `.uf2` 拖進去。完成。

改 SYM 層的按鍵時，小抄表有**三份**要手動同步：
`config/toucan.keymap`（鍵位本體）→
`boards/shields/nice_view_gem/widgets/cheatsheet.c`（鍵盤螢幕）→
`scanner-module/.../src/radii_layout.c` 的 `cheat_rows`（dongle 螢幕）。

## 還原 Step A：把 dongle 刷回官方韌體（硬體層，隨時可做）

不用動這個 repo，兩分鐘完事：

1. 到 <https://github.com/t-ogura/zmk-config-prospector/releases/tag/v2.2.3>
   下載 `prospector_scanner-xiao_ble_nrf52840_zmk-zmk.uf2`
   （v2.2.0 也可以；v2.2.1 / v2.2.2 沒附 `.uf2`）。
2. Dongle 連按兩下 RST 進 bootloader，拖入 `.uf2`。
3. 畫面會回到官方預設的 YADS layout（一排層號、有 WPM）。

官方韌體跟自訂韌體可以隨時互刷，廣播格式相同（`ZMK_STATUS_ADV_VERSION=1`），
鍵盤完全不用動。

## 還原 Step B：把自訂建置從 repo 移除（程式層）

方法一（乾淨，推薦）——revert 引入這套東西的 commit：

```sh
git log --oneline -- scanner-module   # 找到「dongle 自建」那個 commit
git revert <該 commit 的 SHA>
git push
```

方法二（手動）——刪檔案 + 把 workflow 改回單一 job：

```sh
git rm -r scanner scanner-module DONGLE-RESTORE.md
# 編輯 .github/workflows/build.yml，刪掉整個 "scanner:" job，
# 只留原本的 build job（uses: .../build-user-config.yml@v0.3）
git commit -m "移除 dongle 自訂建置" && git push
```

repo 還原後，dongle 上如果還跑著自訂韌體，照 Step A 刷回官方版即可。

## 想改自訂內容（不是還原）的話

| 想改什麼 | 去哪改 |
|---|---|
| 換回有 WPM 的 layout / 換 layout | `scanner/prospector_scanner.conf` 的 `CONFIG_PROSPECTOR_DEFAULT_LAYOUT`（0=YADS 1=Field 2=Operator 3=Radii 儀表板） |
| 副標文字 | `scanner-module/.../src/radii_layout.c` 的 `LAYERS[]`。**加/刪/重排鍵盤層數時一定要同步**（只改層名不用），漏了會編譯失敗（BUILD_ASSERT）或副標對到錯的層 |
| 配色 | 同檔 `color_palettes[]`，4 組暗色（Mint / Amber / Ice / Rose）。非觸控模式開機固定用第 0 個 |
| 版面座標 | 同檔頂端的 `LADDER_* / TEXT_X / COL_X / RIGHT_X / BAR_*` 常數 |
| 大字層名字級 | 同檔 `create_text_column()` 的 `FR_Regular_48`。⚠️ 換字型前先看 `fonts_carrefinho.h` 記的 glyph 範圍——`FG_Medium_20` / `FG_Medium_26` 只到 0x60，**沒有小寫**，而層名有 `-` `+`、副標有小寫 |
| 小抄的內容 / 觸發層名 | 同檔 `cheat_rows` / `CHEAT_LAYER_NAME` |
| 亮度、逾時變暗、轉 180° | `scanner/prospector_scanner.conf` 加 `CONFIG_PROSPECTOR_FIXED_BRIGHTNESS` / `CONFIG_PROSPECTOR_SCANNER_TIMEOUT_MS` / `CONFIG_PROSPECTOR_ROTATE_DISPLAY_180`（完整清單見 `scanner-module/Kconfig`） |
| 升級 upstream 模組 | 下載新版 tarball 覆蓋 `scanner-module/`，再把 radii_layout.c 的小抄 patch 重新套上（搜 CHEAT_LAYER_NAME 的四段），必要時更新 `scanner/west.yml` 釘的 zmk SHA |
