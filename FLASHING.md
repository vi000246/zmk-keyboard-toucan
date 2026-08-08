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
2. **`&bootloader` 鍵永遠只能讓「按下它的那一側」進 bootloader。** dongle 只能靠它自己
   XIAO 上的 RST 鈕（USB-C 接頭旁、絲印 `RST`，約 2mm，要用迴紋針或鑷子尖）連按兩下。
3. 刷半邊時，**另一顆半邊或 dongle 要留在 USB 上當對照組** —— `flash.sh` 用「誰從 USB
   上消失了」做第二道驗證。

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
./build-dongle.sh          # 本機 Docker 編 dongle（只編 dongle，它是唯一帶 keymap 的）
./flash.sh dongle          # 等待 → 驗證 Board-ID → 驗證序號消失 → 寫入
./flash.sh left
./flash.sh right           # 目前只驗得到「這是一顆半邊」，驗不出左右
```

左右半邊的 `.uf2` 來自 GitHub Actions（`build-dongle.sh` 不編它們）。下載：

```sh
gh run download <run-id> -R vi000246/zmk-keyboard-toucan -D "$PWD-build/ci"
```

## 三個會被誤判成失敗的正常現象

- **`cp: could not copy extended attributes ... Device not configured`** —— 不是失敗。
  bootloader 一收完檔案就立刻重開機並卸載磁碟，`cp` 這時才要寫 macOS 擴充屬性就撲空了。
  **磁碟自己消失就是成功的訊號。**
- **刷完 dongle 後有一半打字沒反應** —— 不是刷壞。dongle 重開之後兩個半邊要重新以 BLE
  連上 central，需要幾秒到數十秒，有時要按一下該半邊的鍵把它喚醒。**先等一下、按幾下再判斷**；
  另一半正常而這一半沒反應，最常見的原因就是它還沒連上，不是韌體問題。
- **刷完 dongle 後行為沒變** —— 不是編錯。ZMK Studio 存在裝置上的 keymap 會**覆蓋**編譯進去
  的那份，要連上 Studio 執行一次 *Restore Stock Settings*。注意這只影響 keymap；input
  processor（觸控板速度、方向、自動切層）是韌體層的東西，刷完立即生效。

## 哪些改動要刷哪一顆

| 改了什麼 | 要刷 |
|---|---|
| `config/toucan.keymap`（層、combo、macro） | dongle |
| `toucan.dtsi` 的 input processor（游標/捲動速度、方向、mouse layer） | dongle |
| `toucan_right.overlay` 的 `sensitivity`（觸控板硬體增益） | **右半邊** |
| 半邊的 `.conf`（睡眠、電池回報） | 對應的半邊 |

dongle 是 split central，是唯一帶 keymap 的映像；兩個半邊只負責回報按鍵，keymap 改動碰不到它們。
