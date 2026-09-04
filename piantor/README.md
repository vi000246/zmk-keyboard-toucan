# Piantor Pro（Vial / QMK）設定備份

⚠️ **這裡的檔案不屬於本 repo 的韌體**。本 repo 是 Toucan 的 ZMK config；
Piantor Pro 是另一把鍵盤（beekeeb，RP2040，跑 Vial，`VID_BEEB`/`PID_0002`，
序號 `vial:f64c2b3c`），日常接 Windows 用。放在這裡只是為了跟 Toucan 的
keymap 一起版本控管，方便兩邊對照。

| 檔案 | `settings` QSID 21 | 說明 |
|---|---|---|
| `piantor-20260903-swap-on.vil` | `256`（swap **開**） | **改動前的原始備份**（2026-09-03 13:42）。要回退載入這個即可。 |
| `piantor-windows-20260904.vil` | `0`（swap **關**） | 對齊 Toucan keymap 的 Windows 版。**已在實機驗證並由 Vial 重新匯出**。 |

## `Magic → Swap Control and GUI` 的旗標就存在 .vil 裡

`settings` 的 **QSID 21** 就是它：`256`（= bit 8）代表開、`0` 代表關。
所以**這兩個檔案各自自帶正確的開關狀態，不需要手動去 QMK Settings 撥**。
（2026-09-04 實測確認：關掉開關後由 Vial 匯出，全檔只有 QSID 21 由 256 變 0。）

## 載入步驟

1. Vial → `File` → `Load saved layout` → `piantor-windows-20260904.vil`
2. 實測三顆：
   - 按住 `D` 應該是 **Ctrl**（不是 Win）
   - L4 的 `/` 鍵應該**關分頁**
   - base 的 `.` 鍵應該還能**切輸入法**（送出 Win+Space）
3. 確認無誤後**立刻另外匯出一份新備份**（EEPROM 隨時可能被清空）

若行為整個相反 ⇒ QSID 21 沒被套用，手動去 `QMK Settings → Magic` 關掉
`Swap Control and GUI`。

## 2026-09-04 這一版改了什麼

以 Toucan 的 `config/toucan.keymap` 為基準對齊，**語意一致而非鍵碼一致**。

### 全域
關掉 Magic 開關後，`layout` 區塊 16 層全部做 Ctrl ↔ GUI 對調，以維持原本行為：
`LGUI(`↔`LCTL(`、`LGUI_T(`↔`LCTL_T(`、`SGUI(`↔`C_S(`、`KC_LGUI`↔`KC_LCTRL`。
`LCG(` / `HYPR(` 本身含兩個修飾鍵，對調後不變。
**對調不套用到 `tap_dance` / `macro` / `combo`**——那些依語意個別處理。

### Layer 4（CMD）右手改成文字編輯層
行 = 動作、欄 = 目標，對齊 Toucan：

| | 行首 | 前一字 | 後一字 | 行尾 |
|---|---|---|---|---|
| **刪除** | `Y` = M12 | `U` = `LCTL(KC_BSPACE)` | `I` = `LCTL(KC_DELETE)` | `O` = M13 |
| **移動** | `H` = `LT8(KC_HOME)` | `J` = `LCTL(KC_LEFT)` | `K` = `LCTL(KC_RIGHT)` | `L` = `KC_END` |
| **選取** | `N` = `LSFT(KC_HOME)` | `M` = `C_S(KC_LEFT)` | `,` = `C_S(KC_RIGHT)` | `.` = `LSFT(KC_END)` |

`;` = `C_S(KC_T)`（重開分頁）、`/` = `LCTL(KC_W)`（關分頁）、`P` = `TO(0)`。

Windows 沒有「刪到行首/行尾」的單鍵，所以用巨集兩步做。
`H` 用 `LT8(...)` 而非裸 `KC_HOME`，因為 Toucan 是 `&lt 7 LG(LEFT)`，
Piantor 對應的是第 8 層（base 已在用 `LT8`）。

### 其他修正
| 位置 | 原本 | 改成 | 原因 |
|---|---|---|---|
| L4 左手 `R` | `LGUI(KC_R)`（=Ctrl+R 重新載入） | `LCTL(KC_Y)` | Toucan 是 `LS(LG(Z))` = 重做；Windows 重做是 Ctrl+Y |
| L1 左手 `W` | `KC_NO` | `M9` = `/clear`+Enter | Toucan 有 `&cc_clear`，這顆是空的 |
| L1 左手 `T` | `M4`（**引用了但巨集是空的**） | 填 M4 = `Ctrl+Space` → `V` | Toucan `&macro4` |
| L1 左手 `G` | `HYPR(KC_T)` | `KC_TRNS` | 使用者決定刪掉 |
| L1 左手 `B` | `M1` = `/context` | `M14` = `claude`+Enter | 對齊 Toucan 的 `&claude`；M1 保留不綁，`/context` 沒消失 |
| TD(1) hold | `KC_LCTRL` | `KC_LGUI` | Toucan `&mt LCTRL LG(S)`：Mac 的 Ctrl ↔ Windows 的 Win |
| TD(2) hold | `KC_LGUI` | `KC_LCTRL` | Toucan `&mt LGUI LG(D)`：Mac 的 Cmd ↔ Windows 的 Ctrl |

新增巨集：M9 `/clear`、M12 刪到行首（`Shift+Home`→`Backspace`）、
M13 刪到行尾（`Shift+End`→`Delete`）、M14 `claude`。

### 刻意**沒有**同步的（這些是對的平台適配，同步過去反而會壞）
| 位置 | Toucan (Mac) | Piantor (Windows) |
|---|---|---|
| L1 分頁切換 / 上下頁 | `⇧⌘[ ]` / `⌘[ ]` | `Ctrl+PgUp/PgDn` / `Alt+←→` |
| L4 `Q` | `⌘Q` 結束程式 | `Alt+F4` |
| base `.` | `F18` | `LGUI(KC_SPACE)` = Win+Space 切輸入法 |
| **L2 數字** | `KP_N0~N9` 數字鍵台 | `KC_0~9` 數字列——**不要同步**：NumLock 關掉時 `KC_KP_7` 在 Windows 是 Home |
| L5 右手 | `Hyper+L/E/F/T` | `LCG(1~4)`、`HYPR(...)`：主機端全域熱鍵（Raycast vs AHK） |
| L5 截圖 | `⇧⌘5` | `SGUI(KC_S)` = Win+Shift+S（對調後自動正確） |
| L3 右拇指 | 內 `Hyper+E` / 外 `⌃⌘A` | 維持 Piantor 原樣（使用者決定不改） |
| L16 藍牙層 | 配對 / 輸出切換 | Piantor 有線，沒這層 |
| Piantor L6,7,9~15 | — | 不在範圍（含 L8 滑鼠層），只吃全域對調 |

## 產生方式

由 `piantor-20260903-swap-on.vil` 經腳本轉換而來。**沒有做 JSON 轉存**——
`uid` 是 `16002279599986889074`，超過 Int64 上限，`ConvertTo-Json` 會把它變成
浮點數而損失精度。作法是只重建 `layout` 區塊的文字再原地拼接，其餘位元組不動。
已驗證 `uid` 逐字不變、JSON 可解析、對調沒外洩到 `macro` / `tap_dance`。

**目前 repo 裡這一份是刷進實機後、由 Vial 重新匯出的版本。** 與腳本產出相比，
`layout` / `macro` / `tap_dance` 三個區塊**逐位元組完全相同**（layout 7632 bytes、
逐格比對 0 差異），唯一差別是 `settings` 的 QSID 21 由 `256` 變 `0`
——也就是轉換結果經過實機來回驗證無誤。
