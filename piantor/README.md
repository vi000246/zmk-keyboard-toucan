# Piantor Pro（Vial / QMK）設定備份

⚠️ **這裡的檔案不屬於本 repo 的韌體**。本 repo 是 Toucan 的 ZMK config；
Piantor Pro 是另一把鍵盤（beekeeb，RP2040，跑 Vial，`VID_BEEB`/`PID_0002`，
序號 `vial:f64c2b3c`），日常接 Windows 用。放在這裡只是為了跟 Toucan 的
keymap 一起版本控管，方便兩邊對照。

| 檔案 | `settings` QSID 21 | 說明 |
|---|---|---|
| **`piantor-macos-20260911b.vil`** | `0`（swap **關**） | ⭐ **本分支（macOS）要載入的就是這個**。由 Windows 版轉出，語意對齊本分支的 Toucan macOS keymap，見下方「macOS 版」一節。2026-09-11 第二版：herbr prefix 定案在 L1 的 W、清掉三個 Claude Code 巨集（見下一節）。 |
| `rollback/piantor-macos-20260911.vil` | `0`（swap **關**） | 同日第一版（herbr prefix 還在 L1 的 B、M9/M11/M14 巨集還在）。**只有要回退時才碰**。 |
| `rollback/piantor-macos-20260910.vil` | `0`（swap **關**） | 上一版（L1 的 B 還是 `M14` claude 巨集）。**只有要回退時才碰**。 |
| `rollback/piantor-macos-20260909.vil` | `0`（swap **關**） | 更早一版（L4 右拇指還是固定 `&kp`、沒有 tap dance）。**只有要回退時才碰**。 |
| `rollback/piantor-macos-20260907.vil` | `0`（swap **關**） | 更早一版（L3/L4 拇指改動前）。**只有要回退時才碰**。 |
| `rollback/piantor-20260903-original-swap-on.vil` | `256`（swap **開**） | 改動前的原始備份（2026-09-03 13:42）。**只有要回退時才碰**，刻意放在子資料夾避免誤選。 |

> 📌 **2026-09-07 起，`.vil` 依分支區分平台**：`prospector-scanner`（本分支）
> 只放 **macOS** 版；`prospector-scanner-windows` 只放 **Windows** 版
> （在那邊是 `piantor-windows-20260910.vil`）。檔名同時帶平台字樣，
> 跟分支雙重保險——之前發生過誤載事故，載入前檔名再看一眼。

> ⚠️ 這兩個檔原本同層、檔名相近，2026-09-04 實際發生過誤載回退檔的事故：
> keymap 退回舊版、Magic 對調被打開，於是 `LCTL` 全部變成 `Win` ——
> 按下去跑出「協助工具設定」(`Win+U`) 和「小工具面板」(`Win+W`)。
> 回退檔因此移進 `rollback/`，讓載入時同一層只看得到一個 `.vil`。

⚠️ `piantor-macos-20260911b.vil` **尚未刷入實機驗證**——待驗證點沿用 09-10 版：
`LSA(` alias、新占用的 `TD(6)`（見「macOS 版」一節）、L8 新加的
`LGUI(KC_KP_PLUS)` / `LGUI(KC_KP_MINUS)` 縮放（見下方 L8 一節），
巢狀 `LSFT(LCG(KC_SPACE))` / `LSFT(LAG(KC_SPACE))`，以及 09-10 新占用的
`TD(7)` / `TD(8)`（見 09-10 一節）。09-11 新增一個：L1 的 `LCA(KC_SPACE)`
（`LCA(` 是 QMK 內建 alias，風險同 `LAG(`——Vial 顯示空白或 Any 就是
parser 不吃，得用修飾鍵勾選面板手動重設再重新匯出）。

## 載入步驟（macOS）

1. Vial → `File` → `Load saved layout` → `piantor-macos-20260911b.vil`
2. 實測三顆：
   - 按住 `S` 應該是 **⌘**、按住 `D` 應該是 **⌃**
   - L4 的 `/` 鍵應該**關分頁**（⌘W）
   - base 的 `.` 鍵應該送 **F18**（macOS 端已綁輸入法切換）
3. **09-09 這版多一個必驗項**：L4 右拇指最內側那顆送出的是
   `LSFT(LCG(KC_SPACE))`（⌃⌘⇧Space）。這是**巢狀修飾鍵**寫法，QMK 沒有
   Ctrl+Shift+GUI 的三修飾鍵 alias（只有 `MEH` / `LCAG` / `HYPR`），所以只能
   巢狀。**若 Vial 顯示成空白或 Any**，就是它的 parser 不吃這種寫法 ⇒ 在
   Vial 裡手動用修飾鍵勾選面板重設那一顆，然後重新匯出取代這個檔。
4. 確認無誤後**立刻另外匯出一份新備份**（EEPROM 隨時可能被清空）

若行為整個相反 ⇒ QSID 21 沒被套用，手動去 `QMK Settings → Magic` 關掉
`Swap Control and GUI`。

## 2026-09-11 第二版（20260911b）改了什麼（3 格 ＋ 清空 3 個巨集槽）

跟 `rollback/piantor-macos-20260911.vil`（同日第一版）相比；`uid` / `tap_dance` /
`combo` / `settings` / `key_override` / `encoder_layout` **逐位元組相同**
（已用 node 逐欄比對確認，QSID 21 仍是 `0`）。

| 位置 | 第一版 | 第二版 | 意思 |
|---|---|---|---|
| L1 左手 Q（r0c1） | `M11`（`/exit`+Enter） | `KC_NO` | cc_exit 拔掉 |
| L1 左手 W（r0c2） | `M9`（`/clear`+Enter） | `LCA(KC_SPACE)` | herbr 的 prefix（⌃⌥Space）搬來這 |
| L1 左手 B（r2c5） | `LCA(KC_SPACE)` | `KC_NO` | prefix 搬走，清空 |

`macro` 區塊清空三個槽：**M9**（`/clear`）、**M11**（`/exit`）、**M14**（`claude`）
→ `[]`。使用者不用這三個了，這次**不留備用**（跟 M12/M13 的慣例相反，是使用者
明確要求拔掉）；要回收去翻 git 歷史。M1（`/context`）、M7（`continue`）、
M8（`/usage`）、M10（`/effort`）等其餘巨集不動。

對應 Toucan 是 `config/toucan.keymap` `layer_1`（NAV）位置 1 / 2 / 29，
與 macros 區刪掉的 `claude` / `cc_clear` / `cc_exit` 三個定義，同日兩分支都已改。
herbr prefix 這格兩個平台的 `.vil` 值相同（Ctrl / Alt 是同一組 HID modifier）。

## 2026-09-11 第一版改了什麼（只有 1 格，已進 rollback/）

跟 `rollback/piantor-macos-20260910.vil` 相比，`layout` 只有 1 格變了；
`uid` / `macro` / `tap_dance` / `combo` / `settings` / `key_override` /
`encoder_layout` **逐位元組相同**（已用 node 逐欄比對確認，QSID 21 仍是 `0`）。

| 位置 | 09-10 | 09-11 | 意思 |
|---|---|---|---|
| L1 左手 B（r2c5） | `M14`（打字 `claude`+Enter） | `LCA(KC_SPACE)` | ⌃⌥Space —— herbr 的 prefix |

使用者不再用 claude 巨集。**M14 保留不刪**（比照 M12/M13 的慣例），要回退
直接綁回去。對應 Toucan 是 `config/toucan.keymap` 的 `layer_1`（NAV）位置 29
（`&claude` → `&kp LC(LA(SPACE))`），同日兩個分支都已改。

⚠️ **這 1 格兩個平台的 `.vil` 值完全相同**（Ctrl / Alt 是同一組 HID modifier）
⇒ 不進「刻意不同步」名單。Windows 分支的 `.vil` 從 2026-09-10 起整體落後
（使用者決定「Vial 現在只在 mac 用，Windows 這份先不管」），未來同步時
這一格要一起帶上。

## 2026-09-10 這一版改了什麼（2 格 layout ＋ 2 條 tap dance）

跟 `rollback/piantor-macos-20260909.vil` 相比只動兩處；`uid` / `macro` / `combo` /
`settings` / `key_override` **逐位元組相同**（已用 node 逐欄比對確認，QSID 21 仍是 `0`）。

**L4 右拇指兩顆從固定鍵碼改成 tap dance —— 點一下 AX、連點兩下 Vision。**

| 位置 | 09-09 | 09-10 | 單擊 | 雙擊 |
|---|---|---|---|---|
| L4 r7c4（右拇指中鍵） | `LCG(KC_SPACE)` | **`TD(7)`** | `LCG(KC_SPACE)` ⌃⌘Space（AX 單次） | `LAG(KC_SPACE)` ⌥⌘Space（Vision 單次） |
| L4 r7c5（右拇指最內側） | `LSFT(LCG(KC_SPACE))` | **`TD(8)`** | `LSFT(LCG(KC_SPACE))` ⌃⌘⇧Space（AX 連續） | `LSFT(LAG(KC_SPACE))` ⌥⌘⇧Space（Vision 連續） |

新占用兩個 tap dance 槽（`TD(7)` / `TD(8)`，原本 7 以後全空）：

```
TD(7) ["LCG(KC_SPACE)",       "KC_NO", "LAG(KC_SPACE)",       "KC_NO", 200]
TD(8) ["LSFT(LCG(KC_SPACE))", "KC_NO", "LSFT(LAG(KC_SPACE))", "KC_NO", 200]
```

語意：**Ctrl 管 AX、Alt 管 Vision、Shift 管連不連續**。Vision（CV）只是 AX
（accessibility tree）標不到東西時的備援，所以放在比較費事的雙擊上。

⚠️ `LAG(` = Left Alt + GUI，QMK 內建 alias。`LSFT(LAG(...))` 是巢狀寫法（QMK 沒有
Shift+Alt+GUI 的三修飾鍵 alias），跟 09-09 的 `LSFT(LCG(...))` 同一個待驗證風險：
**若 Vial 顯示成空白或 Any，就是它的 parser 不吃**，得在 Vial 的修飾鍵勾選面板手動
重設那一格再重新匯出。

⚠️ **這 2 格與 2 條 tap dance 兩個平台的 `.vil` 值完全相同**（`⌘` 與 `Win`、`⌥` 與 `Alt`
都是同一顆 HID modifier）⇒ 不進「刻意不同步」名單，**兩個分支要一起改**。對應 Toucan 是
`config/toucan.keymap` 的 `td_hint` / `td_hint_rep` 兩個 behavior。

⚠️ 代價：**單擊要等 200ms 的 tapping-term 過完才送出**（跟 `TD(5)` / Toucan 的 `td_ptt`
一樣）。這是刻意的取捨——把「切 Vision」做在韌體，主機端就不必為了偵測雙擊而引入
timing window（那會讓主線 AX 每次都變鈍），而且 Windows 端根本做不到：`Ctrl+Win+Space`
是 NeverClick 用 `RegisterHotKey` 佔的，AHK 連使用者按了第二下都看不到。

⚠️ **`Alt+Win+Shift+Space`（Vision 連續）在 Windows 沒人接得住** —— NeverClick 沒有
repeat、mousemaster 沒有 CV。按了不會有反應，這是主機端工具的能力限制，不是 keymap
漏了。macOS 端 Neru 四組都吃得下。

## 2026-09-09 這一版改了什麼（只有 3 格）

跟 `rollback/piantor-macos-20260907.vil` 相比，`layout` 只有 3 格變了；
`uid` / `macro` / `tap_dance` / `combo` / `settings` **逐位元組相同**
（QSID 21 仍是 `0`＝swap 關）。

| 位置 | 09-07 | 09-09 | 意思 |
|---|---|---|---|
| L3 右拇指 r7c5 | `LCG(KC_A)` | `LCG(KC_R)` | ⌃⌘R（主機端全域熱鍵） |
| L4 右拇指 r7c4 | `KC_NO` | `LCG(KC_SPACE)` | ⌃⌘Space |
| L4 右拇指 r7c5 | `OSL(1)` | `LSFT(LCG(KC_SPACE))` | ⌃⌘⇧Space（原本是升 NAV） |

⚠️ **這 3 格兩個平台的 `.vil` 值完全相同**，因為 `⌘` 與 `Win` 是同一顆 HID
modifier ⇒ 這三顆不進「刻意不同步」名單。對應 Toucan 是
`config/toucan.keymap` 的 `layer_3`（SYM）與 `layer_4`（CMD）。

⚠️ **這三顆不是 OS 內建快捷鍵**，主機端要有人接（macOS: Hammerspoon /
Raycast）。`⌃⌘Space` 本身系統沒佔用，但 `⌘Space`（Spotlight）和
`⌃Space`（輸入法切換）就在隔壁，設定時注意別打架。

⚠️ **Toucan 這次還有兩件事在 Piantor 上沒有對應物，不要去找**：
1. **藍牙層搬家**（Toucan CMD 位置 40 → NUM 位置 34）。Piantor 有線，
   沒有 BT 層，`KC_NO` 那格直接讓給 ⌃⌘Space。
2. **鍵盤游標鍵速度**（Toucan 的 `&mmv` 三檔改成 250 / 500 / 1000）。
   QMK 的 mousekey 速度是**韌體編譯期常數**（`MOUSEKEY_MAX_SPEED` 那組在
   `config.h`），不存在 `.vil` 裡，所以 `.vil` 改不了也不用改。
   Piantor L8 是靠 `KC_ACL0/1/2` 三顆調速的。

⚠️ **L3 右拇指兩把鍵盤的左右是相反的**，這是既有狀態、不是這次弄壞的：
Toucan 的 `LC(LG(R))` 在位置 41（右拇指**最外側**），Piantor 的 `LCG(KC_R)`
在 `r7c5`（右拇指**最內側**）。原因是 2026-09-04 對齊時使用者決定
「L3 右拇指維持 Piantor 原樣」。這次只換鍵碼、**沒有**順手把位置對齊。

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

## L8（滑鼠／捲動層）跟上 Windows 版（2026-09-07 傍晚）

Windows 那邊 `piantor-windows-20260907.vil` 由實機匯出，**只有 layout 第 8 層
改了 9 格**，其餘區塊逐位元組不變。這份 macOS 檔就是在原本的 macOS 版上
把那 9 格依平台語意翻過來（同樣只換 L8 的文字、其餘位元組不動）。

| 位置 | Windows 版 | macOS 版 | 意思 |
|---|---|---|---|
| 左 r0c1 | `KC_ESCAPE` | `KC_ESCAPE` | Esc（平台無關；原本這格是關分頁） |
| 左 r0c5 | `LCTL(KC_KP_PLUS)` | `LGUI(KC_KP_PLUS)` | 放大 |
| 左 r2c1 | `LALT(KC_TAB)` | `LGUI(KC_TAB)` | 切程式（Alt+Tab ⇢ ⌘Tab） |
| 左 r2c5 | `LCTL(KC_KP_MINUS)` | `LGUI(KC_KP_MINUS)` | 縮小 |
| 左拇指 r3c3 | `KC_NO` | `KC_NO` | 上一頁移走（右手 r4 那組還在） |
| 左拇指 r3c4 | `KC_ACL1` | `KC_ACL1` | 滑鼠中速（平台無關） |
| 右 r5c1 | `C_S(KC_T)` | `SGUI(KC_T)` | 重開分頁 |
| 右 r6c1 | `LCTL(KC_W)` | `LGUI(KC_W)` | 關分頁 |
| 右拇指 r7c3 | `LCTL(KC_R)` | `LGUI(KC_R)` | 重新整理（原本這格是 `KC_F19`） |

其餘 L8 的格子（滑鼠移動／滾輪／`KC_BTN*`／`KC_HOME``KC_END``KC_PGUP``KC_PGDOWN`／
`TO(0)`／`KC_ACL0`）兩平台**完全相同**，不需要翻譯。

⚠️ **待驗證：`⌘` + 數字鍵盤 `+` / `-` 的縮放**。Windows 版用的是
`KC_KP_PLUS` / `KC_KP_MINUS`，這裡照 Ctrl ↔ ⌘ 的全域規則直接對調。
macOS 的瀏覽器多半吃這組，但若實測沒反應，改成 `LGUI(KC_EQUAL)` /
`LGUI(KC_MINUS)`（＝ ⌘= / ⌘-）即可。

> 對應的 Toucan 是 `config/toucan.keymap` 的 `layer_7`（SCRL）。
> **Toucan L7 = Piantor L8**，兩把鍵盤、兩個平台分支要一起改。

## macOS 版（原始轉出，2026-09-07；現行檔已疊上 09-09 的 3 格）

由 `piantor-windows-20260904.vil`（現放在 `prospector-scanner-windows`
分支）以腳本轉出（同樣**只重建 `layout` 與
`tap_dance` 區塊文字、原地拼接**，`uid` / `macro` / `combo` / `settings`
逐位元組不變，QSID 21 維持 `0`＝swap 關、鍵碼寫死）。語意對齊 Toucan
**prospector-scanner 分支**（macOS 版）的 `config/toucan.keymap`。

共改 54 格 layout ＋ 5 條 tap dance：

| 功能 | Windows 版 | macOS 版 |
|---|---|---|
| base `.`＝切輸入法 | `Win+Space` | `KC_F18`（macOS 端已綁輸入法切換） |
| L1/L8 分頁切換 | `Ctrl+PgUp/PgDn` | `⇧⌘[` / `⇧⌘]` |
| L1/L8 瀏覽歷史 | `Alt+←→` | `⌘[` / `⌘]` |
| L2 數字 | 數字列 `KC_0~9` | `KC_KP_0~9`（macOS 不理 NumLock，維持 Toucan 的 keypad 碼；`.`/`=` 同理） |
| L4 `Q` 關程式 | `Alt+F4` | `⌘Q` |
| L4 `R` 重做 | `Ctrl+Y` | `⇧⌘Z` |
| L4 剪貼／關開分頁／網址列 | `Ctrl+字母` | `⌘字母` |
| L4 刪除四顆 (YUIO) | `Ctrl+U/⌫/Del/K` | `⌘⌫` / `⌥⌫` / `⌥⌦` / `⌃K` |
| L4 行首行尾 | `Home`/`End`（含 Shift 選取） | `⌘←`/`⌘→`（選取＝`⇧⌘←→`） |
| L4 跳字 | `Ctrl+←→`（選取 `C_S`） | `⌥←→`（選取 `LSA` = ⇧⌥） |
| L4 `H` | `LT8(KC_HOME)` | **`TD(6)`**＝tap `⌘←`、hold 滑鼠層——QMK 的 `LT()` 塞不了帶修飾的 tap，只能用 tap dance 實作 Toucan 的 `&lt 7 LG(LEFT)` |
| L4 home row hold | S=`Win`、D=`Ctrl`（TD1/TD2） | S=`Ctrl`、D=`⌘`（對齊 Toucan 的 `&mt LCTRL LG(S)` / `&mt LGUI LG(D)`） |
| L5 截圖 | `Win+Shift+S` | `⇧⌘5` |
| L5 app 切換 (YUIO) | `Ctrl+Win+1~4`（工作列釘選） | `Hyper+L/E/F/T`（Hammerspoon） |

沒動的：所有 macro（M0 本來就是 mac 語意；M12/M13 是 Windows 用的
GUI 刪行 fallback，未綁鍵、留著）、combo、L3（符號＋Hyper 拇指，HID
兩平台相同）、L6/7/9~15（全 TRNS）。

⚠️ 兩個小心處：
- `LSA(`（⇧⌥）這個 alias 是這份檔第一次用，Vial 載入時若顯示 unknown
  keycode 就是它——回報即可，可退回巢狀或 macro 做法。
- `TD(6)` 是新占用的 tap dance 槽（原本 6 以後全空）。

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
| L3 右拇指**位置** | 內 `Hyper+E` / 外 `⌃⌘R` | 內 `LCG(KC_R)` / 外 `HYPR(KC_E)`——**左右相反**，2026-09-04 決定維持 Piantor 原樣。鍵碼本身 09-09 已同步（`LCG(KC_A)`→`LCG(KC_R)`），只有位置沒對齊 |
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
