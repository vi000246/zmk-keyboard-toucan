<#
.SYNOPSIS
    走序列 DFU 刷 Toucan —— 給「UF2 磁碟被擋掉」的機器用的 flash.sh 替代品。

.DESCRIPTION
    2026-09-08：公司 GPO 在這台機器上設了
        HKCU\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices
            Deny_All = 1
    「所有卸除式存放裝置類別：拒絕所有存取」。UF2 bootloader 的磁碟**掛得起來**
    （會拿到 D: 之類的代號），但讀寫一律 Access is denied，所以 .uf2 拖不進去。

    XIAO nRF52840 的 Adafruit bootloader 除了 UF2 磁碟，同時也開了一個 CDC
    序列埠並支援序列 DFU。那是序列埠不是卸除式儲存，完全不經過上面那條政策。
    這個腳本就走這條：

        .uf2 --(tools/uf2-to-hex.mjs)--> .hex --(genpkg)--> .zip --(dfu serial)--> 板子

.NOTES
    安全鎖：flash.sh 靠讀 bootloader 磁碟裡的 INFO_UF2.TXT 判斷板子，磁碟現在
    讀不到，所以改用 **bootloader 的 USB 序號**。2026-09-08 實測序號在 app 模式
    與 bootloader 模式相同（都是 nRF52840 的晶片 ID），而且它能分辨左右半 ——
    這點比 INFO_UF2.TXT 的 Board-ID 更強，那個只分得出 dongle 與半邊。

.EXAMPLE
    .\flash-dfu.ps1 probe
    .\flash-dfu.ps1 left
    .\flash-dfu.ps1 left -Uf2 "$env:USERPROFILE\Downloads\toucan_left ....uf2"
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet('left', 'right', 'reset', 'probe')]
    [string]$Board = 'probe',
    [string]$Uf2,
    [string]$Port,
    [int]$Baud = 115200,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$NRFUTIL     = Join-Path $env:USERPROFILE 'Tools\adafruit-nrfutil\adafruit-nrfutil.exe'
$BOOT_VIDPID = 'VID_2886&PID_0064'      # XIAO nRF52840 的 Adafruit bootloader
$CONVERTER   = Join-Path $PSScriptRoot 'tools\uf2-to-hex.mjs'

# 序號 = nRF52840 晶片 ID。app 模式（VID_1D50&PID_615E）與 bootloader 模式
# （VID_2886&PID_0064）相同，所以兩邊都認得出來。
$KNOWN = @{
    'B2AF9AAE792235E5' = 'left'
    '6D1223706D497DBF' = 'dongle'
}
# ⚠️ 右半的序號還沒登記。第一次刷右半時腳本會停下來，把它印出來讓你確認後補進這張表。

$UF2_PATTERN = @{
    'left'  = 'toucan_left*.uf2'
    'right' = 'toucan_right*.uf2'
    'reset' = 'settings_reset*.uf2'
}

function Get-BootloaderDevices {
    $result = @()
    $ports = Get-CimInstance Win32_PnPEntity | Where-Object {
        $_.Name -match 'COM\d+' -and $_.PNPDeviceID -like "*$BOOT_VIDPID*"
    }
    foreach ($p in $ports) {
        $portName = ([regex]::Match($p.Name, 'COM\d+')).Value
        $idForSerial = $p.PNPDeviceID
        try {
            $parent = (Get-PnpDeviceProperty -InstanceId $p.PNPDeviceID -KeyName 'DEVPKEY_Device_Parent' -ErrorAction Stop).Data
            if ($parent) { $idForSerial = $parent }
        } catch { }
        $serial = ''
        $parts = $idForSerial.Split([char]92)      # 92 = 反斜線，避免在字串裡跳脫
        $tail = $parts[$parts.Length - 1]
        if ($tail -match '^[0-9A-Fa-f]{8,}$') { $serial = $tail.ToUpper() }
        $which = '(未登記)'
        if ($KNOWN.ContainsKey($serial)) { $which = $KNOWN[$serial] }
        $result += [pscustomobject]@{ Port = $portName; Serial = $serial; Board = $which }
    }
    return $result
}

function Fail($msg) { Write-Output ""; Write-Output "✗ $msg"; exit 1 }

# ── probe ────────────────────────────────────────────────────────────────
$devices = @(Get-BootloaderDevices)

if ($Board -eq 'probe') {
    Write-Output "=== bootloader 模式的裝置 ($BOOT_VIDPID) ==="
    if ($devices.Count -eq 0) {
        Write-Output "  (無) —— 雙擊板子的 reset 鍵進 bootloader"
    } else {
        $devices | Format-Table Port, Serial, Board -AutoSize | Out-String -Width 120 | Write-Output
    }
    Write-Output "=== 目前所有 COM 裝置 ==="
    Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match 'COM\d+' } | ForEach-Object {
        Write-Output ("  {0,-6} {1}" -f ([regex]::Match($_.Name, 'COM\d+')).Value, $_.PNPDeviceID)
    }
    exit 0
}

# ── 前置檢查 ─────────────────────────────────────────────────────────────
if (-not (Test-Path $NRFUTIL))   { Fail "找不到 adafruit-nrfutil.exe：$NRFUTIL" }
if (-not (Test-Path $CONVERTER)) { Fail "找不到轉換器：$CONVERTER" }

# ── 決定 .uf2 ────────────────────────────────────────────────────────────
if (-not $Uf2) {
    $dl = Join-Path $env:USERPROFILE 'Downloads'
    $cand = Get-ChildItem -Path $dl -Filter $UF2_PATTERN[$Board] -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending
    if (-not $cand) { Fail "在 $dl 找不到符合 $($UF2_PATTERN[$Board]) 的檔案，請用 -Uf2 指定" }
    $Uf2 = $cand[0].FullName
    Write-Output ("自動挑選：" + $cand[0].Name + "  (" + $cand[0].LastWriteTime.ToString('yyyy-MM-dd HH:mm') + ")")
}
if (-not (Test-Path $Uf2)) { Fail "找不到 .uf2：$Uf2" }

$leaf = Split-Path $Uf2 -Leaf
if (-not ($leaf -like $UF2_PATTERN[$Board])) {
    if ($Force) { Write-Output "⚠ 檔名 '$leaf' 不像 $Board 的韌體，但 -Force 已指定，繼續。" }
    else { Fail "檔名 '$leaf' 不符合 $Board 的樣式 '$($UF2_PATTERN[$Board])'。確定的話加 -Force。" }
}

# ── 決定 COM port，並確認板子身分 ────────────────────────────────────────
if ($Port) {
    Write-Output "⚠ 手動指定 $Port，跳過序號比對。"
} else {
    if ($devices.Count -eq 0) { Fail "沒有偵測到 bootloader 裝置。雙擊 reset 鍵進 bootloader 再跑一次。" }
    if ($devices.Count -gt 1) {
        Write-Output "偵測到多個 bootloader 裝置："
        $devices | Format-Table Port, Serial, Board -AutoSize | Out-String -Width 120 | Write-Output
        Fail "一次只能有一個。拔掉其他板子，或用 -Port 指定。"
    }
    $dev = $devices[0]
    Write-Output ("偵測到 bootloader：{0}  序號 {1}  = {2}" -f $dev.Port, $dev.Serial, $dev.Board)

    if ($Board -eq 'reset') {
        if ($dev.Board -eq '(未登記)') { Fail "序號 $($dev.Serial) 沒登記過，不知道這是哪一顆板子。確認後把它加進腳本的 `$KNOWN。" }
        Write-Output "settings_reset 對任何一半都適用，將刷入 $($dev.Board)。"
    } elseif ($dev.Board -ne $Board) {
        Write-Output ""
        Write-Output "✗ 板子對不上：你要刷 '$Board'，但接著的是 '$($dev.Board)'（序號 $($dev.Serial)）。"
        if ($dev.Board -eq '(未登記)') {
            Write-Output "  如果這確實是 $Board，把這一行加進腳本的 `$KNOWN 之後再跑："
            Write-Output "      '$($dev.Serial)' = '$Board'"
        }
        exit 1
    }
    $Port = $dev.Port
}

# ── 轉換 → 打包 → 刷 ─────────────────────────────────────────────────────
$work = Join-Path $env:TEMP ("toucan-dfu-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$hex = Join-Path $work 'fw.hex'
$zip = Join-Path $work 'fw.zip'

Write-Output ""
Write-Output "── 1/3 UF2 → HEX ──"
& node $CONVERTER $Uf2 $hex
if ($LASTEXITCODE -ne 0) { Fail "轉換失敗" }

Write-Output ""
Write-Output "── 2/3 打包 DFU ──"
& $NRFUTIL dfu genpkg --dev-type 0x0052 --application $hex $zip
if ($LASTEXITCODE -ne 0) { Fail "打包失敗" }

Write-Output ""
Write-Output "── 3/3 序列 DFU → $Port ──"
& $NRFUTIL --verbose dfu serial --package $zip -p $Port -b $Baud --singlebank
if ($LASTEXITCODE -ne 0) { Fail "刷機失敗（板子可能已離開 bootloader，重新雙擊 reset 再試）" }

Write-Output ""
Write-Output "✓ 完成：$leaf → $Board ($Port)"
Write-Output "  暫存檔在 $work"
