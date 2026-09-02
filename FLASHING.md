# 燒錄規則（先讀這份，再碰任何 `.uf2`）

2026-08-08 發生過一次事故：**dongle 的韌體被刷進左半邊**，左半邊的按鍵和螢幕整個失效。
沒有硬體損壞，但要靠一顆很難按的 RST 鈕才救得回來。這份文件是為了不再發生。

## 事故是怎麼發生的

1. 為了讓 dongle 進 bootloader，按了 keymap 上的 `&bootloader` 鍵（左拇指 ESC + R）。
2. **那顆鍵重置的是左半邊，不是 dongle。** ZMK 的
   [reset behaviors](https://zmk.dev/docs/keymaps/behaviors/reset) 是 *source-specific* 的：
   「會重置**含有該綁定的那一側**」。唯一的例外是 combo —— combo 觸發的 reset 一律跑在
   central 上。
3. 磁碟跳出來了，看起來就跟 dongle 進 bootloader 一模一樣（**磁碟名稱不會告訴你是哪一顆**）。
4. 沒有做任何辨識就 `cp` 了 dongle 的 `.uf2` 進去。

第 4 步是真正的錯誤。前三步只是讓人容易誤判，第 4 步才是把它變成事故。

## 硬性規則

1. **絕對不要在沒有辨識板子之前寫入任何掛載的 XIAO 磁碟。** 用 `./flash.sh`，不要手動 `cp`。
2. **`&bootloader` 鍵永遠只能讓「按下它的那一側」進 bootloader。**
   2026-09-01 起這變成好事：左半是 central、也是最常刷的板子，而 `&bootloader` 正好
   只重置左半。它在 **BT 層的 `B` 鍵**：按住左拇指 `SPACE` 進 MEDIA、再按住
   右拇指 `RET` 那顆進 BT 層，然後左手按 `B`。
   右半只能靠它自己 XIAO 上的 RST 鈕（USB-C 接頭旁、絲印 `RST`，約 2mm，要用迴紋針
   或鑷子尖）連按兩下。
3. 刷半邊時，**另一顆半邊要留在 USB 上當對照組** —— `flash.sh` 用「誰從 USB
   上消失了」做第二道驗證。（dongle 已退出 split，不再是對照組的一部分。）

## 怎麼分辨三顆板子

`INFO_UF2.TXT` 裡的 `Board-ID` 是硬體層級的事實，不是命名慣例：

| | 磁碟名 | Model | Board-ID | USB 序號 |
|---|---|---|---|---|
| dongle | `XIAO-SENSE` | XIAO nRF52840（Sense） | `Seeed_XIAO_nRF52840_Sense` | `6D1223706D497DBF` |
| 左半邊 | `XIAO-BOOT` | XIAO nRF52840 **Plus** | `nRF52840-SeeedXiao-v1` | `B2AF9AAE792235E5` |
| 右半邊 | 未記錄 | 推測同左半邊 | 推測 `nRF52840-SeeedXiao-v1` | **未記錄** |

**Board-ID 分得出「dongle vs 半邊」，分不出「左 vs 右」。** 左右只能靠 USB 序號，而右半邊的
序號還沒記錄過 —— 下次右半邊插上 USB 時，執行下面這行把它補進本表與 `flash.sh`：

```sh
ioreg -p IOUSB -w0 -l | grep -A 25 '"USB Product Name" = "Toucan"' | grep '"USB Serial Number"'
```

## 用法

```sh
./build-left.sh            # 本機 Docker 編左半（它是 central，唯一真正用 keymap 的）
./flash.sh left            # 等待 → 驗證 Board-ID → 驗證序號消失 → 寫入
./flash.sh right
./flash.sh reset-left      # 抹掉左半的 bond 與設定（之後必須馬上刷回 left）
./flash.sh reset-right
./flash.sh dongle          # 會直接拒絕並說明原因，見下一節
```

右半的 `.uf2` 來自 GitHub Actions。下載：

```sh
gh run download <run-id> -R vi000246/zmk-keyboard-toucan -D "$PWD-build/ci"
```

## dongle 已經退出 split（2026-09-01）

左半改當 split central 之後，dongle 不再是訊號路徑的一環：

```
打字：  右半 ──BLE split──▶ 左半（central）──USB 線 或 BLE──▶ 電腦
顯示：  左半 ──單向 BLE 廣播──▶ Prospector（被動收聽，不配對、不連線）
```

dongle 改刷 Prospector scanner 韌體。**2026-09-02 起改在這個 repo 自建**
（Radii layout：顯示目前層名、沒有 WPM，外加 SYM 層按鍵小抄）：

1. GitHub Actions 每次 push 會產出 `prospector_scanner_custom` artifact
   （scanner job，跟鍵盤的 `firmware` 是分開的兩個 zip）。
2. 解壓拿 `prospector_scanner-xiao_ble_nrf52840_zmk-zmk.uf2`，dongle 連按
   兩下 RST 進 bootloader、拖進去。

自建的內容、可調選項、以及**還原成官方韌體的步驟**都在
[`DONGLE-RESTORE.md`](DONGLE-RESTORE.md)。官方 release（YADS 層號列 +
WPM）永遠是安全的 fallback：v2.2.0 或 v2.2.3 有附 `.uf2`（v2.2.1 /
v2.2.2 只有原始碼），跟自訂版可以隨時互刷、鍵盤完全不用動。

鍵盤端的模組釘 **v2.0.0**（跟原廠 scanner 分支相同；v2.2.x 鍵盤端的廣播
會干擾 split 觸控板，原因見 `config/west.yml` 的說明）。各版本的
`ZMK_STATUS_ADV_VERSION` 都是 1，廣播格式相同，可以混搭。

（背景知識：層的顯示方式由 scanner 的 layout 決定，跟鍵盤端無關。
0=YADS 層號列、1=Field WPM 動畫、2=Operator、3=Radii 層名輪盤。廣播的
層名欄位只有 4 字元，層名取名要 ≤ 4 字，例如 SYM。非觸控版 layout 開機
固定，在 `scanner/prospector_scanner.conf` 的
`CONFIG_PROSPECTOR_DEFAULT_LAYOUT` 選。）

它只需要 USB 供電，放哪裡都行；關掉、拿走、壞掉都不影響鍵盤。

⚠️ **不要把舊的 `toucan_dongle` 韌體刷回去。** 它也是 central，會跟左半搶同一個
右半，症狀是右半時連時不連。要 rollback 必須連 `build.yaml` 與
`boards/shields/toucan/Kconfig.defconfig` 一起 revert，並重跑下面的配對流程。

## 一次性遷移：把 central 從 dongle 換到左半

ZMK 的 split peripheral **只要有任何 bond，就永遠只對那個位址做 directed
advertising**，不會退回開放廣播（`zmk/app/src/split/bluetooth/peripheral.c` 的
`start_advertising()`）。所以右半還記著 dongle 時，新的 central 根本連不上它——
**兩個半邊都必須先抹掉 bond**。

順序照做，中間不要跳步：

1. **把 dongle 從 USB 拔掉。** 它還跑著舊的 central 韌體，開著就會在下一步把剛
   清空的右半搶走。整個遷移過程都不要插回去。
2. `./flash.sh reset-left` → 接著 `./flash.sh left`
3. `./flash.sh reset-right` → 接著 `./flash.sh right`
4. 兩半各按幾下鍵，等它們互相連上（可能要數十秒）。左半的 RGB widget 會告訴你
   peripheral 連上了沒。
5. 左半接 USB 到電腦 → 應該直接能打字（USB 輸出）。
6. 要用藍牙：**先到電腦的藍牙設定把舊的 "Toucan" 條目刪掉**（配對失敗最常見的
   原因就是殘留的舊配對）。然後按住左拇指 `SPACE` 進 MEDIA、再按住右拇指 `RET`
   進 **BT 層**，左手按 `Q`（profile 0），回電腦連 "Toucan"。
   `A`/`S`/`D` = 強制 USB / 強制 BLE / 切換。
7. dongle 刷成 Prospector scanner（上一節），插上任何 USB 電源即可。

## 三個會被誤判成失敗的正常現象

- **`cp: could not copy extended attributes ... Device not configured`** —— 不是失敗。
  bootloader 一收完檔案就立刻重開機並卸載磁碟，`cp` 這時才要寫 macOS 擴充屬性就撲空了。
  **磁碟自己消失就是成功的訊號。**
- **刷完左半後右半沒反應** —— 不是刷壞。左半重開之後右半要重新以 BLE 連上它，需要幾秒
  到數十秒，有時要按一下右半的鍵把它喚醒。**先等一下、按幾下再判斷。**
  但如果等超過一分鐘還是不通，八成是 bond 問題：右半還記著舊的 central。
  照「一次性遷移」那節重跑 `reset-right` → `right`。
- **刷完左半後 keymap 沒變** —— 不是編錯。ZMK Studio 存在裝置上的 keymap 會**覆蓋**編譯
  進去的那份，要連上 Studio 執行一次 *Restore Stock Settings*。注意這只影響 keymap；
  input processor（觸控板速度、方向、自動切層）是韌體層的東西，刷完立即生效。

## 哪些改動要刷哪一顆

| 改了什麼 | 要刷 |
|---|---|
| `config/toucan.keymap`（層、combo、macro） | **左半** |
| `toucan-trackpad.dtsi` 的 input processor（游標/捲動速度、方向、mouse layer） | **左半** |
| `toucan_right.overlay` 的 `sensitivity`（觸控板硬體增益） | 右半 |
| `boards/shields/toucan/toucan_left.conf`（睡眠、電池、Prospector 廣播） | 左半 |
| `boards/shields/toucan/toucan_right.conf` | 右半 |
| `Kconfig.defconfig` 的 split 角色 | **兩半都要，而且要照上面的遷移流程重跑** |

左半是 split central，是唯一真正使用 keymap 的映像；右半只負責回報按鍵和轉送
觸控板的原始事件，keymap 改動碰不到它。
