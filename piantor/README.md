# Piantor Pro（Vial / QMK）設定備份

⚠️ **這裡的檔案不屬於本 repo 的韌體**。本 repo 是 Toucan 的 ZMK config；
Piantor Pro 是另一把鍵盤（beekeeb，RP2040，跑 Vial，`VID_BEEB`/`PID_0002`，
序號 `vial:f64c2b3c`），日常接 Windows 用。放在這裡只是為了跟 Toucan 的
keymap 一起版本控管，方便兩邊對照。

| 檔案 | `settings` QSID 21 | 說明 |
|---|---|---|
| **`piantor-windows-20260904.vil`** | `0`（swap **關**） | ⭐ **平常要載入的就是這個**。對齊 Toucan keymap 的 Windows 版。 |
| `rollback/piantor-20260903-original-swap-on.vil` | `256`（swap **開**） | 改動前的原始備份（2026-09-03 13:42）。**只有要回退時才碰**，刻意放在子資料夾避免誤選。 |

> ⚠️ 這兩個檔原本同層、檔名相近，2026-09-04 實際發生過誤載回退檔的事故：
> keymap 退回舊版、Magic 對調被打開，於是 `LCTL` 全部變成 `Win` ——
> 按下去跑出「協助工具設定」(`Win+U`) 和「小工具面板」(`Win+W`)。
> 回退檔因此移進 `rollback/`，讓載入時同一層只看得到一個 `.vil`。

⚠️ `piantor-windows-20260904.vil` 曾刷進實機並由 Vial 重新匯出驗證過，
**但之後又改了 L4 上排四顆的刪除鍵（見下），這部分尚未刷入**。要用請重新 Load 一次。

## `Magic → Swap Control and GUI` 的旗標就存在 .vil 裡

`settings` 的 **QSID 21** 就是它：`256`（= bit 8）代表開、`0` 代表關。
所以**這兩個檔案各自自帶正確的開關狀態，不需要手動去 QMK Settings 撥**。

兩次獨立驗證：
1. 關掉開關後由 Vial 匯出，全檔**只有** QSID 21 由 `256` 變 `0`。
2. 誤載回退檔（QSID 21 = `256`）之後，`LCTL` 立刻全部變成 `Win`
   —— 證明 **Vial 載入 `.vil` 時確實會套用這個旗標**，不只是存著而已。

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
| **刪除** | `Y` = `LCTL(KC_U)` | `U` = `LCTL(KC_BSPACE)` | `I` = `LCTL(KC_DELETE)` | `O` = `LCTL(KC_K)` |
| **移動** | `H` = `LT8(KC_HOME)` | `J` = `LCTL(KC_LEFT)` | `K` = `LCTL(KC_RIGHT)` | `L` = `KC_END` |
| **選取** | `N` = `LSFT(KC_HOME)` | `M` = `C_S(KC_LEFT)` | `,` = `C_S(KC_RIGHT)` | `.` = `LSFT(KC_END)` |

`;` = `C_S(KC_T)`（重開分頁）、`/` = `LCTL(KC_W)`（關分頁）、`P` = `TO(0)`。

`H` 用 `LT8(...)` 而非裸 `KC_HOME`，因為 Toucan 是 `&lt 7 LG(LEFT)`，
Piantor 對應的是第 8 層（base 已在用 `LT8`）。

⚠️ **Toucan 在 ce0602d 之後層數從 17 減為 13**，8 以後全部往前重排
（BT 16→12、SCR+ 13→11、SCR- 11→10、CUR+ 10→9；CUR/SCR/HJKL/WHEL 已刪除）。
**層 0-7 沒有變動**，所以上面 `LT8` 對應 `&lt 7` 的推論仍然成立。

#### 上排四顆：送各平台原生鍵碼，只在終端機轉譯

| 實體鍵 | Piantor（Windows） | Toucan（macOS） | GUI 要設定嗎 | 終端機要設定嗎 |
|:---:|---|---|---|---|
| `Y` 刪到行首 | `LCTL(KC_U)` | `⌘⌫` | **要**（AHK 展開） | 不用（`^U` 原生） |
| `U` 刪前一字 | `LCTL(KC_BSPACE)` | `⌥⌫` | 不用 | **要**（轉 `ESC+DEL`） |
| `I` 刪後一字 | `LCTL(KC_DELETE)` | `⌥⌦` | 不用 | **要**（轉 `ESC+d`） |
| `O` 刪到行尾 | `LCTL(KC_K)` | `⌃K` | 不用 | 不用（`^K` 原生） |

翻譯層全部在 **MyConfig repo**（chezmoi 同步）：

| 環境 | 檔案 | 做什麼 |
|---|---|---|
| Windows 終端機 | `AppData/.../WindowsTerminal/settings.json` | `Ctrl+Backspace`→`ESC+DEL`、`Ctrl+Delete`→`ESC+d` |
| Windows GUI | `Documents/AutoHotkey/autohotkey.ahk` | 非終端機時 `Ctrl+U`/`Ctrl+K` 展開成 `Shift+Home`+`Backspace` |
| PowerShell | `scripts/windows/powershell/profile.ps1` | 補 PSReadLine 的 `Ctrl+u`/`Ctrl+k`/`Alt+Backspace` |
| macOS 終端機 | `dot_wezterm.lua` | `⌘⌫`→`^U`、`⌥⌫`→`ESC+DEL`、`⌥⌦`→`ESC+d` |
| zsh | `dot_zshrc` | `bindkey '^U' backward-kill-line` |

**macOS 的 GUI 側完全不需要設定**，Cocoa 文字系統原生就支援這四個。
cmd.exe(clink) 與 Git Bash 也不用——底層是 readline。

##### 為什麼不用 F13-F16 當「中性訊號」（已否決，別再提）
把四顆都改送 F13-F16、再由各環境翻譯，看起來能讓兩把鍵盤完全一致，但三個致命問題：
1. **Chrome 的 Commands API 允許清單裡沒有 F 鍵**（連 F1-F12 都沒有），
   套件自己錄鍵的程式碼通常也用 `e.key.length === 1` 濾掉 —— 這些鍵就再也不能
   拿去綁 Chrome 擴充功能了，而使用者正需要這個。
2. **`dot_hammerspoon/init.lua` 已經佔用 F13 / F15**（切換音訊輸出裝置）。
3. 中性鍵碼把 **macOS 上免費的原生行為一起犧牲掉**，反而要多維護一整層 Karabiner。

##### ⚠️ 兩個已知限制
- **Chrome 的 `Ctrl+U`（檢視原始碼）與 `Ctrl+K`（網址列搜尋）會被 AHK 蓋掉。**
  要留給 Chrome 擴充功能的話，在 AHK 的 `InTerminalWin()` 加一行
  `|| WinActive("ahk_exe chrome.exe")`，代價是 Chrome 內的輸入框失去這兩個操作。
- **macOS 的 `⌃K` 在 Chrome / Electron 的輸入框裡不一定有效**——Chromium 自己
  實作文字輸入，emacs-style 綁定支援不完整。這是 Chromium 的限制，不是鍵盤問題。

原本用來做「刪到行首/行尾」的巨集 **M12 / M13 已無任何鍵引用**，
但刻意保留不刪，日後若要退回純 GUI 用法可以直接綁回去。

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
| 藍牙層（Toucan 的 L12） | 配對 / 輸出切換 | Piantor 有線，沒這層 |
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
