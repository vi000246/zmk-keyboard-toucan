# CLAUDE.md

## ⚠️ 最重要：Windows 版和 macOS 版是**不同分支**，不是不同檔案

同一份 keymap 依平台分家在兩個長期分支上，**檔名相同、內容不同**。
動手前先確認自己在哪：`git branch --show-current`

| 分支 | 平台 | 熱鍵語意 | Piantor `.vil` |
|---|---|---|---|
| `prospector-scanner` | **macOS** | `LG(` = ⌘（Cmd）、`LG(LEFT_BRACKET)` 上一頁、`LG(LS(T))` 重開分頁… | `piantor/piantor-macos-*.vil` |
| `prospector-scanner-windows` | **Windows** | `LC(` = Ctrl、`LA(LEFT)` 上一頁、`LC(LS(T))` 重開分頁… | `piantor/piantor-windows-*.vil` |
| `prospector-dongle` | （main）| dongle 版韌體基準，**沒有** scanner module | 無 |

兩個平台分支之間**只差三種東西**：

1. `config/toucan.keymap` —— 帶修飾鍵的熱鍵（Ctrl ↔ ⌘、Alt+方向 ↔ ⌘[]…）
2. `piantor/*.vil` —— 每個分支只放**自己平台**那一份，另一個平台的不 checkout 進來
3. `piantor/README.md` —— 載入步驟與對照表跟著平台走

其餘（scanner module、boards、config/*.conf、regen.sh…）兩邊要一致。

### 規則

- **功能性改動（新增/移動/刪除某顆鍵）要兩個分支都做**，只是鍵碼各自用該平台的原生寫法。
  只改一邊 = 下次切平台就發現鍵不見了。
- **不要把 `.vil` 從一個平台分支 cherry-pick 到另一個**。macOS 版是由 Windows 版**轉出**的
  （只重建 `layout` / `tap_dance` 的文字、原地拼接，`uid`/`macro`/`combo`/`settings` 逐位元組不變），
  轉換規則寫在各分支的 `piantor/README.md`。
- `.vil` 自帶 `settings` QSID 21（Magic → Swap Control and GUI）：`0` = 關、`256` = 開。
  **載入 `.vil` 會套用這個旗標**，不要另外去 Vial 手撥。
- 舊版 `.vil` 一律放 `piantor/rollback/`，讓 `piantor/` 同層永遠只看得到一個 `.vil`
  —— 2026-09-04 發生過誤載回退檔的事故。

### 層對照

Toucan（ZMK，13 層）的 `layer_7`（SCRL）＝ Piantor（Vial，16 層）的 **L8**。
Toucan L0-L7 與 Piantor L0-L8 的對應在 `piantor/README.md` 有完整表。

## Toucan 硬體

只能刷 **Toucan2**（Azoteq TPS43 / I2C），刷成 Toucan1（Cirque / SPI）的症狀是
**觸控板完全沒反應但按鍵正常**。細節見根目錄 `README.md`。
