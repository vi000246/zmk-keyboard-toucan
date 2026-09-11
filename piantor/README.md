# Piantor Pro（Vial / QMK）設定備份

⚠️ **這裡的檔案不屬於本 repo 的韌體**。本 repo 是 Toucan 的 ZMK config；
Piantor Pro 是另一把鍵盤（beekeeb，RP2040，跑 Vial，`VID_BEEB`/`PID_0002`，
序號 `vial:f64c2b3c`），日常接 Windows 用。放在這裡只是為了跟 Toucan 的
keymap 一起版本控管，方便兩邊對照。

| 檔案 | `settings` QSID 21 | 說明 |
|---|---|---|
| **`piantor-windows-20260910.vil`** | `0`（swap **關**） | ⭐ **本分支（Windows）要載入的就是這個**。2026-09-10 從 09-09 版改 2 格 ＋ 2 條 tap dance（見下）。 |
| `rollback/piantor-windows-20260909.vil` | `0`（swap **關**） | 上一版（L4 右拇指還是固定鍵碼、沒有 tap dance）。**只有要回退時才碰**。 |
| `rollback/piantor-windows-20260907.vil` | `0`（swap **關**） | 上一版（L3/L4 拇指改動前）。**只有要回退時才碰**。 |
| `rollback/piantor-windows-20260904.vil` | `0`（swap **關**） | 再上一版（L8 改動前）。**只有要回退時才碰**。 |
| `rollback/piantor-20260903-original-swap-on.vil` | `256`（swap **開**） | 改動前的原始備份（2026-09-03 13:42）。**只有要回退時才碰**，刻意放在子資料夾避免誤選。 |

> 📌 **2026-09-07 起，`.vil` 依分支區分平台**：`prospector-scanner-windows`
> （本分支）只放 **Windows** 版；`prospector-scanner` 只放 **macOS** 版
> （在那邊是 `piantor-macos-20260910.vil`）。檔名同時帶平台字樣，跟分支
> 雙重保險——之前發生過誤載事故，載入前檔名再看一眼。

> ⚠️ 這兩個檔原本同層、檔名相近，2026-09-04 實際發生過誤載回退檔的事故：
> keymap 退回舊版、Magic 對調被打開，於是 `LCTL` 全部變成 `Win` ——
> 按下去跑出「協助工具設定」(`Win+U`) 和「小工具面板」(`Win+W`)。
> 回退檔因此移進 `rollback/`，讓載入時同一層只看得到一個 `.vil`。

⚠️ `rollback/piantor-windows-20260907.vil` 是**實機當下狀態由 Vial 匯出**的，所以 L8 那批
改動已經在鍵盤裡了。L4 上排四顆的刪除鍵（見下）則是 09-04 那版就改好、**一直沒刷入**，
連 09-09 這版也還是舊值——要一次補齊請重新 Load 一次。

## 載入步驟（Windows）

1. Vial → `File` → `Load saved layout` → `piantor-windows-20260910.vil`
2. 實測三顆：
   - 按住 `D` 應該是 **Ctrl**（不是 Win）
   - L4 的 `/` 鍵應該**關分頁**
   - base 的 `.` 鍵應該還能**切輸入法**（送出 Win+Space）
3. **09-09 這版多一個必驗項**：L4 右拇指最內側那顆送出的是
   `LSFT(LCG(KC_SPACE))`（Ctrl+Win+Shift+Space）。這是**巢狀修飾鍵**寫法，
   QMK 沒有 Ctrl+Shift+GUI 的三修飾鍵 alias（只有 `MEH` / `LCAG` / `HYPR`），
   所以只能巢狀。**若 Vial 顯示成空白或 Any**，就是它的 parser 不吃這種寫法
   ⇒ 在 Vial 裡手動用修飾鍵勾選面板重設那一顆，然後重新匯出取代這個檔。
4. 確認無誤後**立刻另外匯出一份新備份**（EEPROM 隨時可能被清空）

若行為整個相反 ⇒ QSID 21 沒被套用，手動去 `QMK Settings → Magic` 關掉
`Swap Control and GUI`。

## 2026-09-10 這一版改了什麼（2 格 layout ＋ 2 條 tap dance）

**L4 右拇指兩顆從固定鍵碼改成 tap dance —— 點一下 AX、連點兩下 Vision。**

| 位置 | 09-09 | 09-10 | 單擊 | 雙擊 |
|---|---|---|---|---|
| L4 r7c4（右拇指中鍵） | `LCG(KC_SPACE)` | **`TD(7)`** | Ctrl+Win+Space（AX 單次） | Alt+Win+Space（Vision 單次） |
| L4 r7c5（右拇指最內側） | `0xb2c` | **`TD(8)`** | Ctrl+Win+Shift+Space（AX 連續） | Alt+Win+Shift+Space（Vision 連續） |

```
TD(7) ["LCG(KC_SPACE)",       "KC_NO", "LAG(KC_SPACE)",       "KC_NO", 200]
TD(8) ["LSFT(LCG(KC_SPACE))", "KC_NO", "LSFT(LAG(KC_SPACE))", "KC_NO", 200]
```

語意：**Ctrl 管 AX、Alt 管 Vision、Shift 管連不連續**。Vision（CV）只是 AX 標不到東西時的
備援，所以放在比較費事的雙擊上。逐欄比對過 `uid`/`macro`/`combo`/`settings`/`key_override`/
`encoder_layout` 逐位元組相同，`layout` 也逐格比對只有上表那兩格變。

⚠️ **09-09 版的 r7c5 在 repo 裡是 `0xb2c` 而不是 `LSFT(LCG(KC_SPACE))`** —— 那是同一個鍵碼
（`0x0B2C`：mods=0b01011=Ctrl+Shift+GUI、keycode=0x2C=Space），Vial 把它載進鍵盤再匯出時
存成了原始碼。**這就是「巢狀修飾鍵 Vial 認不認」那個待驗證項的答案：它認得、只是回吐數字。**
新加的 `LSFT(LAG(...))` 預期也會變成數字，不用緊張。

⚠️ **槽號刻意用 7 / 8，把 `TD(6)` 留空** —— 本分支 `TD(6)` 本來就沒用到，但 macOS 分支的
`TD(6)` 被 `LGUI(KC_LEFT)` / `MO(8)` 佔著。兩邊同槽號，README 與排錯步驟才不會分岔。

⚠️ 代價：**單擊要等 200ms 的 tapping-term 過完才送出**（跟 `TD(5)` 一樣）。刻意的取捨——
把「切 Vision」做在韌體，主機端就不必為了偵測雙擊而引入 timing window；Windows 端更是
根本做不到：`Ctrl+Win+Space` 是 NeverClick 用 `RegisterHotKey` 佔的，AHK 連使用者按了
第二下都看不到。

⚠️ **`Alt+Win+Shift+Space`（Vision 連續）在 Windows 沒人接得住** —— NeverClick 沒有 repeat、
mousemaster 沒有 CV。按了不會有反應，是主機端工具的能力限制，不是 keymap 漏了。

⚠️ **本檔目前落後 macOS 分支**：2026-09-10 使用者確認「Vial 現在只在 mac 用，Windows 這份
先不管、未來再同步」。要同步時的差異來源是 09-09 那筆 `123` commit（`.` 鍵 `KC_F18`、
L3 的 `HYPR(KC_R)` / `LCG(KC_E)` 對調），那三格 macOS 分支還是舊值。
**2026-09-11 又多一格**：macOS 版（`piantor-macos-20260911.vil`）把 L1 左手 B 從
`M14`（claude 巨集）改成 `LCA(KC_SPACE)`（herbr 的 prefix，Ctrl+Alt+Space），
本檔這一格還是 `M14`，同步時要帶上（M14 巨集保留不刪）。

## 2026-09-09 這一版改了什麼（只有 3 格）

跟 `rollback/piantor-windows-20260907.vil` 相比，`layout` 只有 3 格變了；
`uid` / `macro` / `tap_dance` / `combo` / `settings` **逐位元組相同**
（QSID 21 仍是 `0`＝swap 關），驗證方式同下方「產生方式」。

| 位置 | 09-07 | 09-09 | 意思 |
|---|---|---|---|
| L3 右拇指 r7c5 | `LCG(KC_A)` | `LCG(KC_R)` | Ctrl+Win+R（主機端全域熱鍵） |
| L4 右拇指 r7c4 | `KC_NO` | `LCG(KC_SPACE)` | Ctrl+Win+Space |
| L4 右拇指 r7c5 | `OSL(1)` | `LSFT(LCG(KC_SPACE))` | Ctrl+Win+Shift+Space（原本是升 NAV） |

對應 Toucan 是 `config/toucan.keymap` 的 `layer_3`（SYM）與 `layer_4`（CMD）。

⚠️ **Toucan 這次還有兩件事在 Piantor 上沒有對應物，不要去找**：
1. **藍牙層搬家**（Toucan CMD 位置 40 → NUM 位置 34）。Piantor 有線，
   沒有 BT 層，`KC_NO` 那格直接讓給 Ctrl+Win+Space。
2. **鍵盤游標鍵速度**（Toucan 的 `&mmv` 三檔改成 250 / 500 / 1000）。
   QMK 的 mousekey 速度是**韌體編譯期常數**（`MOUSEKEY_MAX_SPEED` 那組在
   `config.h`），不存在 `.vil` 裡，所以 `.vil` 改不了也不用改。
   Piantor L8 是靠 `KC_ACL0/1/2` 三顆調速的。

⚠️ **L3 右拇指兩把鍵盤的左右是相反的**，這是既有狀態、不是這次弄壞的：
Toucan 的 `LC(LG(A))` 在位置 41（右拇指**最外側**），Piantor 的 `LCG(KC_A)`
在 `r7c5`（右拇指**最內側**）。原因是 2026-09-04 對齊時使用者決定
「L3 右拇指維持 Piantor 原樣」（見下方對照表）。這次只換鍵碼、**沒有**
順手把位置對齊——要對齊是另一個決定。

### 欄位對應備忘（改 `.vil` 前先看這個）

`layout[層][列][欄]`，列 0-3 = 左半、列 4-7 = 右半，列 3 / 列 7 是拇指排，
拇指只用 **欄 3、4、5**（欄 0-2 是 `-1`）。**兩半都是欄 1 = 外側（小指）→
欄 5 = 內側（食指）**，所以拇指排對到 Toucan 的 ZMK 位置是：

| | Toucan 位置 | Piantor |
|---|---|---|
| 左拇指 外→內 | 36 / 37 / 38 | `r3c3` / `r3c4` / `r3c5` |
| 右拇指 內→外 | 39 / 40 / 41 | `r7c5` / `r7c4` / `r7c3` |

用 L0 交叉驗證：Toucan 39/40/41 = `BSPC` / `RET` / `F19`，Piantor
`r7c5`=`LT2(KC_BSPACE)`、`r7c4`=`LT5(KC_ENTER)`、`r7c3`=`LT3(KC_F19)`。✅

### ✅ 順帶確認：NAV / NUM 的層編號 Piantor 一直是對的

Piantor base 是 `LT1(KC_ESCAPE)`（ESC → NAV）、`LT2(KC_BSPACE)`
（BSPC → NUM），也就是 **L1 = NAV、L2 = NUM**。Toucan 那邊 2026-09-06 被
keymap-editor bot 弄成 NUM=1 / NAV=2，2026-09-09 已修回來跟 Piantor 一致。
`.vil` 這邊**不用改**。

## `Magic → Swap Control and GUI` 的旗標就存在 .vil 裡

`settings` 的 **QSID 21** 就是它：`256`（= bit 8）代表開、`0` 代表關。
所以**這兩個檔案各自自帶正確的開關狀態，不需要手動去 QMK Settings 撥**。

兩次獨立驗證：
1. 關掉開關後由 Vial 匯出，全檔**只有** QSID 21 由 `256` 變 `0`。
2. 誤載回退檔（QSID 21 = `256`）之後，`LCTL` 立刻全部變成 `Win`
   —— 證明 **Vial 載入 `.vil` 時確實會套用這個旗標**，不只是存著而已。

## 2026-09-07 這一版改了什麼（只有 L8）

跟 `rollback/piantor-windows-20260904.vil` 相比，**只有 `layout` 的第 8 層變了，
共 9 格**；`uid` / `macro` / `tap_dance` / `combo` / `settings` 全部逐位元組相同
（QSID 21 仍是 `0`＝swap 關）。

| 位置 | 09-04 | 09-07 | 意思 |
|---|---|---|---|
| 左 r0c1 | `LCTL(KC_W)` | `KC_ESCAPE` | 關分頁移走，改放 Esc |
| 左 r0c5 | — | `LCTL(KC_KP_PLUS)` | 放大 |
| 左 r2c1 | `C_S(KC_T)` | `LALT(KC_TAB)` | 重開分頁移走，改放 Alt+Tab 切程式 |
| 左 r2c5 | — | `LCTL(KC_KP_MINUS)` | 縮小 |
| 左拇指 r3c3 | `LALT(KC_LEFT)` | — | 上一頁移走（右手 r4 那組還在） |
| 左拇指 r3c4 | `LALT(KC_RIGHT)` | `KC_ACL1` | 下一頁移走，改成滑鼠中速 |
| 右 r5c1 | — | `C_S(KC_T)` | 重開分頁（從左手搬過來） |
| 右 r6c1 | — | `LCTL(KC_W)` | 關分頁（從左手搬過來） |
| 右拇指 r7c3 | `KC_F19` | `LCTL(KC_R)` | 重新整理 |

對應 Toucan 這邊是 `config/toucan.keymap` 的 `layer_7`（SCRL）——
**Toucan L7 = Piantor L8，兩邊要一起改**。macOS 版見 `prospector-scanner` 分支。

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
| L3 右拇指**位置** | 內 `Hyper+E` / 外 `Ctrl+Win+R` | 內 `LCG(KC_R)` / 外 `HYPR(KC_E)`——**左右相反**，2026-09-04 決定維持 Piantor 原樣。鍵碼本身 09-09 已同步（`LCG(KC_A)`→`LCG(KC_R)`），只有位置沒對齊 |
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
