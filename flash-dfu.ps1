<#
.SYNOPSIS
    走序列 DFU 刷 Toucan —— 給「UF2 磁碟被擋掉」的機器用的 flash.sh 替代品。

.DESCRIPTION
    2026-09-08：公司 GPO 在當時那台機器上設了
        HKCU\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices
            Deny_All = 1
    「所有卸除式存放裝置類別：拒絕所有存取」。UF2 bootloader 的磁碟**掛得起來**
    （會拿到 D: 之類的代號），但讀寫一律 Access is denied，所以 .uf2 拖不進去。

    XIAO nRF52840 的 Adafruit bootloader 除了 UF2 磁碟，同時也開了一個 CDC
    序列埠並支援序列 DFU。那是序列埠不是卸除式儲存，完全不經過上面那條政策。
    這個腳本就走這條：

        .uf2 --(tools/uf2-to-hex.mjs)--> .hex --(genpkg)--> .zip --(dfu serial)--> 板子

    換一台電腦要用的話，先跑 `.\flash-dfu.ps1 setup`，它會檢查 Node.js、
    自動下載 adafruit-nrfutil 並驗證能跑。

.NOTES
    安全鎖：flash.sh 靠讀 bootloader 磁碟裡的 INFO_UF2.TXT 判斷板子，磁碟現在
    讀不到，所以改用 **bootloader 的 USB 序號**。2026-09-08 實測序號在 app 模式
    與 bootloader 模式相同（都是 nRF52840 的晶片 ID），而且它能分辨左右半 ——
    這點比 INFO_UF2.TXT 的 Board-ID 更強，那個只分得出 dongle 與半邊。

.PARAMETER Uf2
    可以是 **檔案**、**資料夾**（會抓裡面最新的一個符合的 .uf2，含子資料夾），
    或 **GitHub Actions 下載的 .zip**（會自動解開找裡面的 .uf2）。
    不給的話會依序搜尋 $env:TOUCAN_UF2_DIR、目前目錄、repo、repo-build、
    ~/Downloads、~/Desktop。

.EXAMPLE
    .\flash-dfu.ps1 setup               # 換新電腦第一次跑：檢查並安裝工具
    .\flash-dfu.ps1 probe               # 看現在哪顆板子在 bootloader
    .\flash-dfu.ps1 left
    .\flash-dfu.ps1 left -Uf2 D:\somewhere\firmware
    .\flash-dfu.ps1 left -Uf2 C:\Users\me\Downloads\artifact.zip
    .\flash-dfu.ps1 left -Wait 0        # 不等，沒偵測到就直接失敗
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet('left', 'right', 'reset', 'probe', 'setup')]
    [string]$Board = 'probe',
    [string]$Uf2,
    [string]$Port,
    [int]$Baud = 115200,
    [int]$Wait = 60,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$TOOLDIR     = Join-Path $env:USERPROFILE 'Tools/adafruit-nrfutil'
$NRFUTIL     = Join-Path $TOOLDIR 'adafruit-nrfutil.exe'
$NRFUTIL_VER = '0.5.3.post17'
$NRFUTIL_URL = "https://github.com/adafruit/Adafruit_nRF52_nrfutil/releases/download/$NRFUTIL_VER/adafruit-nrfutil--$NRFUTIL_VER-win.zip"
$BOOT_VIDPID = 'VID_2886&PID_0064'      # XIAO nRF52840 的 Adafruit bootloader
$CONVERTER   = Join-Path $PSScriptRoot 'tools/uf2-to-hex.mjs'

# 序號 = nRF52840 晶片 ID。app 模式（VID_1D50&PID_615E）與 bootloader 模式
# （VID_2886&PID_0064）相同，所以兩邊都認得出來。
$KNOWN = @{
    'B2AF9AAE792235E5' = 'left'
    '784AA79E10321892' = 'right'
    '6D1223706D497DBF' = 'dongle'
}
# 三顆都登記完了（右半在 2026-09-08 第一次走序列 DFU 時登記）。換板子時腳本會印
# 出未登記的序號並停下來，確認之後補進上面那張表即可。

$UF2_PATTERN = @{
    'left'  = 'toucan_left*.uf2'
    'right' = 'toucan_right*.uf2'
    'reset' = 'settings_reset*.uf2'
}

function Fail {
    param([string]$Msg, [string[]]$Hints)
    Write-Output ""
    Write-Output "[X] $Msg"
    if ($Hints) { Write-Output ""; foreach ($h in $Hints) { Write-Output "  $h" } }
    exit 1
}

# ── 工具檢查／安裝 ───────────────────────────────────────────────────────
function Test-NodeInstalled {
    $cmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $cmd) { return $null }
    $ver = ''
    try { $ver = (& node --version) } catch { }
    return [pscustomobject]@{ Path = $cmd.Source; Version = $ver }
}

function Install-Nrfutil {
    Write-Output "  下載 adafruit-nrfutil $NRFUTIL_VER ..."
    if (-not (Test-Path -LiteralPath $TOOLDIR)) { New-Item -ItemType Directory -Path $TOOLDIR -Force | Out-Null }
    $zip = Join-Path $env:TEMP "adafruit-nrfutil-$NRFUTIL_VER.zip"
    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $NRFUTIL_URL -OutFile $zip -UseBasicParsing -ErrorAction Stop
    } catch {
        $ProgressPreference = $oldProgress
        Fail "下載失敗：$($_.Exception.Message)" @(
            "手動下載這個檔案，解壓到 $TOOLDIR ：",
            "    $NRFUTIL_URL",
            "公司網路可能擋 GitHub release，那就換網路或用手機熱點抓。"
        )
    }
    $ProgressPreference = $oldProgress
    try {
        Expand-Archive -LiteralPath $zip -DestinationPath $TOOLDIR -Force -ErrorAction Stop
    } catch {
        Fail "解壓失敗：$($_.Exception.Message)" @("下載的檔案在 $zip，可以手動解到 $TOOLDIR 。")
    }
    if (-not (Test-Path -LiteralPath $NRFUTIL)) {
        $found = @(Get-ChildItem -LiteralPath $TOOLDIR -Filter 'adafruit-nrfutil.exe' -File -Recurse -ErrorAction SilentlyContinue)
        if ($found.Count -gt 0) { Copy-Item -LiteralPath $found[0].FullName -Destination $NRFUTIL -Force }
    }
    if (-not (Test-Path -LiteralPath $NRFUTIL)) { Fail "解壓後仍然找不到 adafruit-nrfutil.exe" @("自己看一下 $TOOLDIR 裡面有什麼。") }
}

if ($Board -eq 'setup') {
    Write-Output "=== Toucan 序列 DFU 環境檢查 ==="
    Write-Output ""

    Write-Output "1. Node.js（跑 tools/uf2-to-hex.mjs 用）"
    $node = Test-NodeInstalled
    if ($node) {
        Write-Output ("   [OK] " + $node.Version + "  " + $node.Path)
    } else {
        Write-Output "   [X]  找不到 node"
        Write-Output "        winget install OpenJS.NodeJS.LTS"
        Write-Output "        裝完要「重開一個終端機」PATH 才會生效。"
    }
    Write-Output ""

    Write-Output "2. adafruit-nrfutil（打包並送出 DFU）"
    if (Test-Path -LiteralPath $NRFUTIL) {
        $v = ''
        try { $v = (& $NRFUTIL version) } catch { }
        Write-Output ("   [OK] " + $v + "  " + $NRFUTIL)
    } else {
        Write-Output "   [ ]  沒裝，現在自動安裝..."
        Install-Nrfutil
        $v = ''
        try { $v = (& $NRFUTIL version) } catch { }
        if ($v) { Write-Output ("   [OK] " + $v + "  " + $NRFUTIL) }
        else { Write-Output "   [X]  裝好了但跑不起來，手動確認 $NRFUTIL" }
    }
    Write-Output ""

    Write-Output "3. 轉換器 tools/uf2-to-hex.mjs"
    if (Test-Path -LiteralPath $CONVERTER) { Write-Output ("   [OK] " + $CONVERTER) }
    else { Write-Output ("   [X]  找不到 " + $CONVERTER + " —— 它應該跟腳本一起在 repo 裡") }
    Write-Output ""

    Write-Output "4. 這台機器擋不擋 UF2 磁碟（擋的話才需要這個腳本）"
    $denied = $false
    $sep = [string][char]92
    foreach ($hive in @('HKCU:', 'HKLM:')) {
        $p = $hive + $sep + ('SOFTWARE/Policies/Microsoft/Windows/RemovableStorageDevices'.Replace('/', $sep))
        try {
            $v = Get-ItemProperty -Path $p -ErrorAction Stop
            if ($v.Deny_All -eq 1) { Write-Output ("   [!]  " + $hive + " Deny_All = 1（所有卸除式儲存被擋）"); $denied = $true }
        } catch { }
    }
    if (-not $denied) {
        Write-Output "   [OK] 沒看到 Deny_All 政策 —— 這台說不定可以直接拖 .uf2，"
        Write-Output "        真的可以的話用 flash.sh（Git Bash）比較省事。"
    }
    Write-Output ""
    Write-Output "檢查完畢。接著：.\flash-dfu.ps1 probe"
    exit 0
}

function Get-BootloaderDevices {
    $result = @()
    $ports = @()
    try {
        $ports = Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object {
            $_.Name -match 'COM\d+' -and $_.PNPDeviceID -like "*$BOOT_VIDPID*"
        }
    } catch {
        Fail "查詢 USB 裝置失敗：$($_.Exception.Message)" @("通常是 WMI 出問題，重開機或跑 'winmgmt /verifyrepository' 看看。")
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

function Get-Uf2FromZip {
    param([string]$ZipPath, [string]$Pattern)
    $dest = Join-Path $env:TEMP ("toucan-zip-" + (Get-Date -Format 'HHmmss'))
    try {
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $dest -Force -ErrorAction Stop
    } catch {
        Fail "解壓 $ZipPath 失敗：$($_.Exception.Message)" @("確認它是 GitHub Actions 下載的 artifact zip，不是損毀的檔案。")
    }
    $hits = @(Get-ChildItem -LiteralPath $dest -Filter $Pattern -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($hits.Count -eq 0) {
        $all = @(Get-ChildItem -LiteralPath $dest -Filter '*.uf2' -File -Recurse -ErrorAction SilentlyContinue)
        $hint = @("zip 裡沒有符合 '$Pattern' 的檔案。")
        if ($all.Count -gt 0) {
            $hint += "裡面有的 .uf2："
            foreach ($a in $all) { $hint += "    " + $a.Name }
            $hint += "確定要刷的話用 -Uf2 直接指向其中一個，並加 -Force。"
        } else {
            $hint += "裡面根本沒有 .uf2。"
        }
        Fail "zip 裡找不到韌體" $hint
    }
    # ⚠️ 函式裡一律用 Write-Host 不用 Write-Output：Write-Output 會混進回傳值，
    #    讓呼叫端拿到「訊息 + FileInfo」的陣列（$uf2File.Length 就會變成元素個數）。
    Write-Host ("  從 zip 取出：" + $hits[0].Name)
    return $hits[0]
}

function Resolve-Uf2File {
    param([string]$Requested, [string]$BoardName)
    $pattern = $UF2_PATTERN[$BoardName]

    # ── 使用者明確指定：檔案／資料夾／zip 都吃 ──────────────────────
    if ($Requested) {
        $expanded = [Environment]::ExpandEnvironmentVariables($Requested)
        if (-not (Test-Path -LiteralPath $expanded)) {
            Fail "-Uf2 指定的路徑不存在：$expanded" @(
                "檢查有沒有打錯字；路徑含空白要加引號：",
                "    .\flash-dfu.ps1 $BoardName -Uf2 ""C:\path with space\fw.uf2"""
            )
        }
        $item = Get-Item -LiteralPath $expanded
        if ($item.PSIsContainer) {
            $hits = @(Get-ChildItem -LiteralPath $item.FullName -Filter $pattern -File -Recurse -Depth 3 -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
            if ($hits.Count -eq 0) {
                $all = @(Get-ChildItem -LiteralPath $item.FullName -Filter '*.uf2' -File -Recurse -Depth 3 -ErrorAction SilentlyContinue)
                $hint = @("在 $($item.FullName)（含 3 層子資料夾）找不到符合 '$pattern' 的檔案。")
                if ($all.Count -gt 0) {
                    $hint += "這個資料夾裡有的 .uf2："
                    foreach ($a in $all) { $hint += "    " + $a.Name }
                    $hint += "要刷其中一個就用 -Uf2 直接指檔案，必要時加 -Force。"
                }
                Fail "資料夾裡沒有 $BoardName 的韌體" $hint
            }
            if ($hits.Count -gt 1) { Write-Host ("  資料夾裡有 " + $hits.Count + " 個符合的，取最新的") }
            return $hits[0]
        }
        if ($item.Extension -eq '.zip') { return (Get-Uf2FromZip $item.FullName $pattern) }
        return $item
    }

    # ── 自動搜尋 ────────────────────────────────────────────────────
    $dirs = @()
    if ($env:TOUCAN_UF2_DIR) { $dirs += $env:TOUCAN_UF2_DIR }
    $dirs += (Get-Location).Path
    $dirs += $PSScriptRoot
    $dirs += ($PSScriptRoot + '-build')                       # flash.sh 的 BUILD 目錄
    $dirs += (Join-Path $env:USERPROFILE 'Downloads')
    $dirs += (Join-Path $env:USERPROFILE 'Desktop')

    $searched = @()
    foreach ($d in $dirs) {
        if (-not $d) { continue }
        if ($searched -contains $d) { continue }
        $searched += $d
        if (-not (Test-Path -LiteralPath $d)) { continue }
        $hits = @(Get-ChildItem -LiteralPath $d -Filter $pattern -File -Recurse -Depth 2 -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        if ($hits.Count -gt 0) {
            Write-Host ("自動找到：" + $hits[0].FullName)
            if ($hits.Count -gt 1) { Write-Host ("  （這個位置有 " + $hits.Count + " 個符合的，取最新的）") }
            return $hits[0]
        }
    }

    $hint = @("搜尋過的位置（每個往下找 2 層）：")
    foreach ($s in $searched) {
        if (Test-Path -LiteralPath $s) { $hint += "    $s" }
        else { $hint += "    $s  (不存在)" }
    }
    $hint += ""
    $hint += "解法（三選一）："
    $hint += "  1. 直接指路徑 —— 檔案／資料夾／artifact zip 都吃："
    $hint += "       .\flash-dfu.ps1 $BoardName -Uf2 D:\my\firmware"
    $hint += "  2. 設環境變數，之後就不用每次指："
    $hint += "       [Environment]::SetEnvironmentVariable('TOUCAN_UF2_DIR','D:\my\firmware','User')"
    $hint += "  3. 從 CI 直接下載："
    $hint += "       gh run download -R vi000246/zmk-keyboard-toucan"
    Fail "找不到 $BoardName 的 .uf2（樣式 '$pattern'）" $hint
}

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
if (-not (Test-NodeInstalled)) {
    Fail "找不到 node" @(
        "轉換器 tools/uf2-to-hex.mjs 需要 Node.js：",
        "    winget install OpenJS.NodeJS.LTS",
        "裝完重開一個終端機，再跑 .\flash-dfu.ps1 setup 確認。"
    )
}
if (-not (Test-Path -LiteralPath $NRFUTIL)) {
    Fail "找不到 adafruit-nrfutil.exe：$NRFUTIL" @(
        "跑這行會自動下載安裝（官方 Windows 執行檔，不需要 Python）：",
        "    .\flash-dfu.ps1 setup"
    )
}
if (-not (Test-Path -LiteralPath $CONVERTER)) {
    Fail "找不到轉換器：$CONVERTER" @("它應該跟腳本一起在 repo 裡，確認沒被刪掉或搬走。")
}

# ── 決定 .uf2 ────────────────────────────────────────────────────────────
$uf2File = Resolve-Uf2File $Uf2 $Board
# 防呆：萬一以後有人在 Resolve-Uf2File 裡寫了 Write-Output，回傳的會是
# 「訊息 + FileInfo」的陣列，$uf2File.Length 就會變成元素個數而不是檔案大小。
if ($uf2File -is [array]) { $uf2File = $uf2File[-1] }
if (-not ($uf2File -is [System.IO.FileInfo])) {
    Fail "內部錯誤：解析 .uf2 時拿到非預期的型別 $($uf2File.GetType().Name)" @("這是腳本的 bug，不是你的操作問題。")
}
$leaf = $uf2File.Name

if ($uf2File.Length -eq 0) { Fail "檔案是空的：$($uf2File.FullName)" @("重新下載一次 artifact。") }
if ($uf2File.Length % 512 -ne 0) {
    Fail "不像合法的 UF2：$leaf 大小 $($uf2File.Length) bytes，不是 512 的倍數" @("下載可能不完整，重抓一次。")
}
Write-Output ("使用韌體：{0}  ({1:N0} bytes, {2})" -f $leaf, $uf2File.Length, $uf2File.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))

if (-not ($leaf -like $UF2_PATTERN[$Board])) {
    if ($Force) {
        Write-Output "[!] 檔名 '$leaf' 不像 $Board 的韌體，但 -Force 已指定，繼續。"
    } else {
        Fail "檔名對不上：'$leaf' 不符合 $Board 的樣式 '$($UF2_PATTERN[$Board])'" @(
            "刷錯韌體會讓那一半失效，所以預設擋下來。",
            "確定沒錯的話加 -Force。"
        )
    }
}

# ── 決定 COM port，並確認板子身分 ────────────────────────────────────────
if ($Port) {
    Write-Output "[!] 手動指定 $Port，跳過序號比對 —— 刷錯板子的風險由你自己扛。"
} else {
    if ($devices.Count -eq 0 -and $Wait -gt 0) {
        Write-Output ""
        Write-Output "沒偵測到 bootloader —— 請雙擊板子的 reset 鍵（左半也可以按 BT 層的 B）。等 $Wait 秒..."
        $deadline = (Get-Date).AddSeconds($Wait)
        while ((Get-Date) -lt $deadline -and $devices.Count -eq 0) {
            Start-Sleep -Milliseconds 1000
            $devices = @(Get-BootloaderDevices)
        }
    }
    if ($devices.Count -eq 0) {
        Fail "沒有偵測到 bootloader 裝置（找的是 $BOOT_VIDPID）" @(
            "1. 雙擊板子上的 reset 鍵，或按 BT 層的 B（只會重置左半）。",
            "2. 確認 USB 線是資料線不是純充電線。",
            "3. .\flash-dfu.ps1 probe 可以看目前所有 COM 裝置。",
            "4. 等久一點：-Wait 120"
        )
    }
    if ($devices.Count -gt 1) {
        Write-Output "偵測到多個 bootloader 裝置："
        $devices | Format-Table Port, Serial, Board -AutoSize | Out-String -Width 120 | Write-Output
        Fail "一次只能有一個" @("拔掉其他板子再試，或用 -Port 指定（會跳過序號比對）。")
    }

    $dev = $devices[0]
    Write-Output ("偵測到 bootloader：{0}  序號 {1}  = {2}" -f $dev.Port, $dev.Serial, $dev.Board)

    if ($dev.Serial -eq '') {
        Fail "抓不到這顆板子的 USB 序號，無法確認是哪一半" @(
            "用 .\flash-dfu.ps1 probe 看完整的 PNPDeviceID。",
            "真的要刷就用 -Port $($dev.Port)（跳過比對）。"
        )
    }
    if ($Board -eq 'reset') {
        if ($dev.Board -eq '(未登記)') {
            Fail "序號 $($dev.Serial) 沒登記過，不知道這是哪一顆板子" @(
                "確認之後把這行加進腳本的 KNOWN 表：",
                "    '$($dev.Serial)' = 'right'"
            )
        }
        Write-Output "settings_reset 對任何一半都適用，將刷入 $($dev.Board)。"
    } elseif ($dev.Board -ne $Board) {
        $hint = @()
        if ($dev.Board -eq '(未登記)') {
            $hint += "如果這確實是 $Board，把這行加進腳本的 KNOWN 表之後再跑："
            $hint += "    '$($dev.Serial)' = '$Board'"
            $hint += "（右半的序號本來就還沒登記，第一次刷右半會走到這裡。）"
        } else {
            $hint += "拔錯板子了。要刷 $($dev.Board) 的話跑："
            $hint += "    .\flash-dfu.ps1 $($dev.Board)"
        }
        Fail "板子對不上：你要刷 '$Board'，但接著的是 '$($dev.Board)'（序號 $($dev.Serial)）" $hint
    }
    $Port = $dev.Port
}

# ── 轉換 → 打包 → 刷 ─────────────────────────────────────────────────────
$work = Join-Path $env:TEMP ("toucan-dfu-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$hex = Join-Path $work 'fw.hex'
$zip = Join-Path $work 'fw.zip'

Write-Output ""
Write-Output "-- 1/3 UF2 -> HEX --"
& node $CONVERTER $uf2File.FullName $hex
if ($LASTEXITCODE -ne 0) {
    Fail "轉換失敗（原因見上面）" @("如果是 family 不符，代表這個 .uf2 不是給 nRF52840 的，別刷。")
}

Write-Output ""
Write-Output "-- 2/3 打包 DFU --"
& $NRFUTIL dfu genpkg --dev-type 0x0052 --application $hex $zip
if ($LASTEXITCODE -ne 0) { Fail "打包失敗" @("暫存檔留在 $work，可以自己看 fw.hex。") }

Write-Output ""
Write-Output "-- 3/3 序列 DFU -> $Port --"
if (-not $PSBoundParameters.ContainsKey('Port')) {
    $still = @(Get-BootloaderDevices | Where-Object { $_.Port -eq $Port })
    if ($still.Count -eq 0) {
        Fail "$Port 在準備過程中消失了（板子離開 bootloader 了？）" @("重新雙擊 reset 再跑一次。")
    }
}
& $NRFUTIL --verbose dfu serial --package $zip -p $Port -b $Baud --singlebank
if ($LASTEXITCODE -ne 0) {
    Fail "刷機失敗" @(
        "1. 板子可能已離開 bootloader —— 重新雙擊 reset 再跑一次。",
        "2. COM 埠被別的程式佔用（Vial / ZMK Studio / 序列監控）就先關掉。",
        "3. 暫存檔留在 $work。"
    )
}

Write-Output ""
Write-Output "[OK] 完成：$leaf -> $Board ($Port)"
Write-Output "     暫存檔在 $work"
