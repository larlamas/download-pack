#Requires -Version 5.1
# Download Pack v3.0 — Dynamic UI Edition
# irm https://raw.githubusercontent.com/larlamas/download-pack/main/Download-Programs.ps1 | iex

$Global:RootPath = "C:\Downloads_Pack"
$Global:Downloaded = 0; $Global:Failed = 0; $Global:Skipped = 0
$Global:TotalBytes = 0; $Global:FailedList = @()
$Global:StartTime = Get-Date; $Global:BufSize = 262144

# UTF-8 для корректного отображения эмодзи
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
[Net.ServicePointManager]::DefaultConnectionLimit = 32
[Net.ServicePointManager]::Expect100Continue = $false
$ProgressPreference = 'SilentlyContinue'

# ═══════════════ HELPERS ═══════════════
function Sz([long]$b) {
    if ($b -ge 1GB) { return "{0:N2} GB" -f ($b / 1GB) }
    if ($b -ge 1MB) { return "{0:N2} MB" -f ($b / 1MB) }
    if ($b -ge 1KB) { return "{0:N2} KB" -f ($b / 1KB) }
    return "$b B"
}
function Spd([double]$b) {
    if ($b -ge 1MB) { return "{0:N1} MB/s" -f ($b / 1MB) }
    if ($b -ge 1KB) { return "{0:N1} KB/s" -f ($b / 1KB) }
    return "{0:N0} B/s" -f $b
}
function PadLine([string]$s) {
    $w = [Console]::WindowWidth - 1
    if ($s.Length -gt $w) { return $s.Substring(0, $w) }
    return $s.PadRight($w)
}
function WriteAt([int]$y, [string]$text) {
    try { [Console]::SetCursorPosition(0, $y) } catch {}
    Write-Host (PadLine $text) -NoNewline
}

function Resolve-TpuUrl([string]$Url) {
    $ret = @{ Url = $Url; FileName = "" }
    if ($Url -notmatch "techpowerup\.com/download/") { return $ret }
    try {
        Add-Type -AssemblyName System.Net.Http
        $handler = New-Object System.Net.Http.HttpClientHandler
        $handler.AllowAutoRedirect = $false
        $client = New-Object System.Net.Http.HttpClient($handler)
        $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        
        $resp1 = $client.GetAsync($Url).Result
        if (!$resp1.IsSuccessStatusCode) { return $ret }
        $html = $resp1.Content.ReadAsStringAsync().Result
        
        $blocks = [regex]::Matches($html, 'class="filename"[^>]*>\s*(.*?)\s*</div>[\s\S]*?name="id"\s+value="(\d+)"')
        if ($blocks.Count -gt 0) {
            # По умолчанию всегда берём самый первый в списке (он же самый свежий релиз на TechPowerUp)
            $selectedBlock = $blocks[0]
            
            # Дополнительная фильтрация для специфичных программ
            if ($Url -match "nvidia-geforce-graphics-drivers") {
                foreach ($b in $blocks) {
                    if ($b.Groups[1].Value -match "-desktop-win10-win11-64bit-international-dch-whql\.exe") {
                        $selectedBlock = $b
                        break
                    }
                }
            }
            elseif ($Url -match "techpowerup-gpu-z") {
                # Не берем брендированную ASUS ROG версию, если она висит первой
                foreach ($b in $blocks) {
                    if ($b.Groups[1].Value -notmatch "ASUS_ROG") {
                        $selectedBlock = $b
                        break
                    }
                }
            }
            
            $ret.FileName = $selectedBlock.Groups[1].Value.Trim()
            $id = $selectedBlock.Groups[2].Value

            $dict = New-Object "System.Collections.Generic.Dictionary[string,string]"
            $dict.Add("id", $id)
            $dict.Add("server_id", "27") # NL server
            $content = New-Object System.Net.Http.FormUrlEncodedContent($dict)
            
            $resp2 = $client.PostAsync($Url, $content).Result
            if ($resp2.StatusCode -eq 302 -or $resp2.StatusCode -eq 301) {
                $newUrl = $resp2.Headers.Location.OriginalString
                if ($newUrl) {
                    $ret.Url = $newUrl
                }
            }
        }
        $client.Dispose()
    }
    catch { }
    return $ret
}

# ═══════════════ GLOBAL BAR ═══════════════
function Update-Bar([int]$cur, [int]$total, [int]$barY) {
    $pct = if ($total -gt 0) { [math]::Round($cur / $total * 100) } else { 0 }
    $f = [math]::Round($pct / 2); $e = 50 - $f
    $bar = "█" * $f + "░" * $e
    $sizeStr = Sz $Global:TotalBytes
    $line = "  [$bar] $pct% ($cur/$total) — $sizeStr скачано"
    WriteAt $barY $line
}

# ═══════════════ BANNER ═══════════════
function Show-Banner {
    $b = @"

   ╔══════════════════════════════════════════════════════════════════╗
   ║    ██████╗  ██████╗ ██╗    ██╗███╗   ██╗██╗      ██████╗  █████╗ ║
   ║    ██╔══██╗██╔═══██╗██║    ██║████╗  ██║██║     ██╔═══██╗██╔══██╗║
   ║    ██║  ██║██║   ██║██║ █╗ ██║██╔██╗ ██║██║     ██║   ██║███████║║
   ║    ██║  ██║██║   ██║██║███╗██║██║╚██╗██║██║     ██║   ██║██╔══██║║
   ║    ██████╔╝╚██████╔╝╚███╔███╔╝██║ ╚████║███████╗╚██████╔╝██║  ██║║
   ║    ╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝║
   ║          ██████╗  █████╗  ██████╗██╗  ██╗                        ║
   ║          ██╔══██╗██╔══██╗██╔════╝██║ ██╔╝                        ║
   ║          ██████╔╝███████║██║     █████╔╝                         ║
   ║          ██╔═══╝ ██╔══██║██║     ██╔═██╗                         ║
   ║          ██║     ██║  ██║╚██████╗██║  ██╗                        ║
   ║          ╚═╝     ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝                        ║
   ║              Programs Download Manager v3.0 ⚡                   ║
   ╚══════════════════════════════════════════════════════════════════╝
"@
    Write-Host $b -ForegroundColor Cyan
}

# ═══════════════ DOWNLOAD WITH LIVE PROGRESS ═══════════════
function Start-LiveDownload {
    param([string]$Url, [string]$FileName, [string]$CatFolder,
        [int]$Num, [int]$Total, [int]$GlobalNum, [int]$GlobalTotal, [int]$BarY)

    # Resolve TPU URL before checking file existence
    $TargetUrl = $Url
    if ($Url -match "techpowerup\.com/download/") {
        $tpuInfo = Resolve-TpuUrl $Url
        if ($tpuInfo.Url) { $TargetUrl = $tpuInfo.Url }
        if ($tpuInfo.FileName) { $FileName = $tpuInfo.FileName }
    }

    $catPath = Join-Path $Global:RootPath $CatFolder
    if (!(Test-Path $catPath)) { New-Item -ItemType Directory -Path $catPath -Force | Out-Null }
    $outPath = Join-Path $catPath $FileName

    # Позиция строки файла = barY - 1... нет, используем текущую позицию
    $fileY = [Console]::CursorTop

    # === SKIP ===
    if ((Test-Path $outPath) -and ((Get-Item $outPath).Length -gt 0)) {
        $sz = (Get-Item $outPath).Length
        try { [Console]::SetCursorPosition(0, $fileY) } catch {}
        Write-Host "    ⏭  " -NoNewline -ForegroundColor DarkYellow
        Write-Host "[$Num/$Total] " -NoNewline -ForegroundColor DarkGray
        Write-Host "$FileName" -NoNewline -ForegroundColor White
        Write-Host "   $(Sz $sz) — уже скачан" -ForegroundColor DarkGray
        $Global:Skipped++
        Update-Bar $GlobalNum $GlobalTotal $BarY
        return
    }

    # === DOWNLOAD ===
    WriteAt $fileY "    📥 [$Num/$Total] $FileName   Подключение..."

    try {
        $handler = New-Object System.Net.Http.HttpClientHandler
        $handler.AllowAutoRedirect = $true
        $handler.MaxAutomaticRedirections = 10
        $client = New-Object System.Net.Http.HttpClient($handler)
        $client.Timeout = [TimeSpan]::FromSeconds(15)
        $client.DefaultRequestHeaders.Add("User-Agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

        $resp = $client.GetAsync($TargetUrl,
            [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
        if (!$resp.IsSuccessStatusCode) { throw "HTTP $($resp.StatusCode)" }

        $contentLen = 0
        if ($resp.Content.Headers.ContentLength) { $contentLen = $resp.Content.Headers.ContentLength }
        $totalStr = if ($contentLen -gt 0) { Sz $contentLen } else { "???" }

        $stream = $resp.Content.ReadAsStreamAsync().Result
        $fs = [System.IO.File]::Create($outPath)
        $buf = New-Object byte[] $Global:BufSize
        $read = 0; $totalRead = 0
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $lastMs = 0

        while (($read = $stream.Read($buf, 0, $Global:BufSize)) -gt 0) {
            $fs.Write($buf, 0, $read)
            $totalRead += $read
            $ms = $sw.ElapsedMilliseconds

            if ($ms - $lastMs -ge 150) {
                $speed = if ($ms -gt 0) { $totalRead / ($ms / 1000) } else { 0 }
                $dlStr = Sz $totalRead
                $spdStr = Spd $speed
                $pct = if ($contentLen -gt 0) { [math]::Round($totalRead / $contentLen * 100) } else { 0 }
                $bf = [math]::Round($pct / 100 * 12)
                $be = 12 - $bf
                $mini = "█" * $bf + "░" * $be

                $line = "    >> [$Num/$Total] $FileName   $dlStr / $totalStr [$mini] $pct% @ $spdStr"
                WriteAt $fileY $line
                $lastMs = $ms
            }
        }

        $fs.Close(); $stream.Close(); $client.Dispose(); $sw.Stop()

        if ($totalRead -gt 0) {
            $speed = $totalRead / $sw.Elapsed.TotalSeconds
            $sizeStr = Sz $totalRead
            $spdStr = Spd $speed
            $timeStr = "{0:F1}s" -f $sw.Elapsed.TotalSeconds

            try { [Console]::SetCursorPosition(0, $fileY) } catch {}
            Write-Host (PadLine "") -NoNewline
            try { [Console]::SetCursorPosition(0, $fileY) } catch {}
            Write-Host "    ✅ " -NoNewline -ForegroundColor Green
            Write-Host "[$Num/$Total] " -NoNewline -ForegroundColor DarkGray
            Write-Host "$FileName" -NoNewline -ForegroundColor White
            Write-Host "   $sizeStr @ $spdStr ($timeStr)" -ForegroundColor DarkGray

            $Global:Downloaded++
            $Global:TotalBytes += $totalRead
        }
        else {
            throw "Файл пустой (0 байт)"
        }
    }
    catch {
        Remove-Item $outPath -Force -ErrorAction SilentlyContinue
        $errMsg = $_.Exception.Message
        if ($errMsg.Length -gt 60) { $errMsg = $errMsg.Substring(0, 57) + "..." }

        # Fallback: WebClient (тихий режим)
        try {
            WriteAt $fileY "    >> [$Num/$Total] $FileName   Загрузка..."
            $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            $wc.DownloadFile($TargetUrl, $outPath); $wc.Dispose(); $sw2.Stop()

            if ((Test-Path $outPath) -and ((Get-Item $outPath).Length -gt 0)) {
                $fsize = (Get-Item $outPath).Length
                $speed = $fsize / $sw2.Elapsed.TotalSeconds

                try { [Console]::SetCursorPosition(0, $fileY) } catch {}
                Write-Host (PadLine "") -NoNewline
                try { [Console]::SetCursorPosition(0, $fileY) } catch {}
                Write-Host "    ✅ " -NoNewline -ForegroundColor Green
                Write-Host "[$Num/$Total] " -NoNewline -ForegroundColor DarkGray
                Write-Host "$FileName" -NoNewline -ForegroundColor White
                Write-Host "   $(Sz $fsize) @ $(Spd $speed)" -ForegroundColor DarkGray

                $Global:Downloaded++
                $Global:TotalBytes += $fsize
            }
            else { throw "Fallback: пустой файл" }
        }
        catch {
            $errMsg2 = $_.Exception.Message
            if ($errMsg2.Length -gt 60) { $errMsg2 = $errMsg2.Substring(0, 57) + "..." }
            try { [Console]::SetCursorPosition(0, $fileY) } catch {}
            Write-Host (PadLine "") -NoNewline
            try { [Console]::SetCursorPosition(0, $fileY) } catch {}
            Write-Host "    ❌ " -NoNewline -ForegroundColor Red
            Write-Host "[$Num/$Total] " -NoNewline -ForegroundColor DarkGray
            Write-Host "$FileName" -NoNewline -ForegroundColor White
            Write-Host "   $errMsg2" -ForegroundColor DarkRed

            $Global:Failed++
            $Global:FailedList += $FileName
        }
    }

    Update-Bar $GlobalNum $GlobalTotal $BarY
}

# ═══════════════ CATEGORIES ═══════════════
$Categories = @(
    @{ Name = "PROGRAMS"; Icon = "🎮"; Folder = "01_Programs"; Files = @(
            @{Url = "https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe"; FileName = "SteamSetup.exe" }
            @{Url = "https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64"; FileName = "DiscordSetup.exe" }
            @{Url = "https://telegram.org/dl/desktop/win64"; FileName = "TelegramSetup.exe" }
        )
    },
    @{ Name = "START PROGS"; Icon = "⚙️"; Folder = "02_Start_Progs"; Files = @(
            @{Url = "https://www.7-zip.org/a/7z2600-x64.exe"; FileName = "7z2600-x64.exe" }
            @{Url = "https://download.microsoft.com/download/1/7/1/1718ccc4-6315-4d8e-9543-8e28a4e18c4c/dxwebsetup.exe"; FileName = "dxwebsetup.exe" }
            @{Url = "https://www.techpowerup.com/download/visual-c-redistributable-runtime-package-all-in-one/"; FileName = "Visual-C-Runtimes-All-in-One-Dec-2025.zip" }
            @{Url = "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/6.0.36/windowsdesktop-runtime-6.0.36-win-x64.exe"; FileName = "windowsdesktop-runtime-6.0.36-win-x64.exe" }
        )
    },
    @{ Name = "OPTIMIZATION"; Icon = "🚀"; Folder = "03_Optimization"; Files = @(
            @{Url = "https://dl.boosterx.org/BoosterX.exe"; FileName = "BoosterX.exe" }
            @{Url = "https://www.wagnardsoft.com/ISLC/ISLC%20v1.0.3.7.exe"; FileName = "ISLC v1.0.3.7.exe" }
            @{Url = "https://download.sysinternals.com/files/Autoruns.zip"; FileName = "Autoruns.zip" }
        )
    },
    @{ Name = "VIDEOCARD"; Icon = "🖥️"; Folder = "04_Videocard"; Files = @(
            @{Url = "https://www.techpowerup.com/download/techpowerup-nvcleanstall/"; FileName = "NVCleanstall_1.19.0.exe" }
            @{Url = "https://www.techpowerup.com/download/display-driver-uninstaller-ddu/"; FileName = "DDU-v18.1.4.1_setup.exe" }
            @{Url = "https://www.techpowerup.com/download/techpowerup-gpu-z/"; FileName = "GPU-Z.2.69.0.exe" }
            @{Url = "https://github.com/Orbmu2k/nvidiaProfileInspector/releases/download/2.4.0.31/nvidiaProfileInspector.zip"; FileName = "nvidiaProfileInspector.zip" }
            @{Url = "https://download.msi.com/uti_exe/vga/MSIAfterburnerSetup467Beta2.zip"; FileName = "MSIAfterburnerSetup467Beta2.zip" }
        )
    },
    @{ Name = "DRIVERS"; Icon = "💽"; Folder = "05_Drivers"; Files = @(
            @{Url = "https://driveroff.net/drv/SDI_1.26.0.7z"; FileName = "SDI_1.26.0.7z" }
            @{Url = "https://www.techpowerup.com/download/amd-ryzen-chipset-drivers/"; FileName = "AMD_Chipset_Software_7.11.26.2142.exe" }
            @{Url = "https://www.techpowerup.com/download/nvidia-geforce-graphics-drivers/"; FileName = "591.86-desktop-win10-win11-64bit-international-dch-whql.exe" }
            @{Url = "https://lianli-update.oss-cn-beijing.aliyuncs.com/L3_CX/20260123-L-Connect%203-x64-hotfix-hotfix-change-sdk-v2.1.15-f93e2a64.exe"; FileName = "20260123-L-Connect 3-x64-hotfix-hotfix-change-sdk-v2.1.15-f93e2a64.exe" }
            @{Url = "https://drive.usercontent.google.com/download?id=1yC3Fg2yfSplqsACATQifmbL62FU_P3p2&export=download&authuser=0&confirm=t&uuid=a25d3845-aa1d-4e54-ac6a-e2e5493f0433&at=APcXIO006tLTPcoV1vcZY4znI_Vm%3A1771155597078"; FileName = "X2 CrazyLight Software.exe" }
            @{Url = "https://www.pulsar.gg/cdn/shop/t/79/assets/download.svg?v=8351372234618339141713834745"; FileName = "X2 CrazyLight Mini Gaming Mouse Firmware Update.svg" }
            @{Url = "https://download.semiconductor.samsung.com/resources/software-resources/Samsung_Magician_Installer_Official_9.0.0.910.exe"; FileName = "Samsung_Magician_Installer_Official_9.0.0.910.exe" }
            @{Url = "https://fael-downloads-prod.focusrite.com/customer/prod/downloads/focusrite_control_v3_27_0.exe"; FileName = "focusrite_control_v3_27_0.exe" }
            @{Url = "https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/Focusrite%20Control%20-%203.6.0.1822_0.exe"; FileName = "Focusrite Control - 3.6.0.1822_0.exe" }
            @{Url = "https://download.amd.com/Desktop/amd_ryzen_master_3_0_1_4819.exe"; FileName = "amd_ryzen_master_3_0_1_4819.exe" }
        )
    }
)

# ═══════════════ MAIN ═══════════════
Clear-Host
Show-Banner

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "  📋 OS: $([Environment]::OSVersion.VersionString) | PS: $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
Write-Host "  🔐 Права: $(if($isAdmin){'Администратор ✅'}else{'Пользователь ⚠'}) | TLS 1.2/1.3 ✅ | Буфер: $(Sz $Global:BufSize)" -ForegroundColor DarkGray

$totalFiles = 0
foreach ($c in $Categories) { $totalFiles += $c.Files.Count }
Write-Host ""
Write-Host "  📦 Файлов: $totalFiles в $($Categories.Count) категориях → C:\Downloads_Pack" -ForegroundColor White
Write-Host ""

if (!(Test-Path $Global:RootPath)) { New-Item -ItemType Directory -Path $Global:RootPath -Force | Out-Null }

Write-Host "  ▶  Старт через 3 сек..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# Reserve bar line
Write-Host ""
$barY = [Console]::CursorTop
Write-Host ""  # Bar placeholder
Write-Host ""  # Space after bar

$globalNum = 0
$catNum = 0

foreach ($cat in $Categories) {
    $catNum++
    Write-Host ""
    Write-Host "  ┌──────────────────────────────────────────────────────────────┐" -ForegroundColor DarkCyan
    Write-Host "  │  $($cat.Icon)  " -ForegroundColor DarkCyan -NoNewline
    Write-Host "$($cat.Name)" -ForegroundColor Yellow -NoNewline
    $pad = 53 - $cat.Name.Length
    if ($pad -lt 0) { $pad = 0 }
    Write-Host (" " * $pad) -NoNewline
    Write-Host "[$catNum/$($Categories.Count)]" -ForegroundColor DarkGray -NoNewline
    Write-Host " │" -ForegroundColor DarkCyan
    Write-Host "  └──────────────────────────────────────────────────────────────┘" -ForegroundColor DarkCyan
    Write-Host ""

    $localNum = 0
    foreach ($file in $cat.Files) {
        $localNum++
        $globalNum++

        # Adjust bar position (it moves down as we print lines)
        $barY = [Console]::CursorTop + 1

        Start-LiveDownload -Url $file.Url -FileName $file.FileName `
            -CatFolder $cat.Folder -Num $localNum -Total $cat.Files.Count `
            -GlobalNum $globalNum -GlobalTotal $totalFiles -BarY $barY

        # Ensure cursor is below the bar
        if ([Console]::CursorTop -lt ($barY + 1)) {
            try { [Console]::SetCursorPosition(0, $barY + 1) } catch {}
        }
    }
}

# ═══════════════ SUMMARY ═══════════════
$elapsed = (Get-Date) - $Global:StartTime
$elStr = "{0:mm\:ss}" -f $elapsed
$avgSpd = if ($elapsed.TotalSeconds -gt 0) { Spd ($Global:TotalBytes / $elapsed.TotalSeconds) } else { "N/A" }

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "  ║                    📊  ИТОГИ ЗАГРУЗКИ                       ║" -ForegroundColor Magenta
Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Magenta
Write-Host "  ║   ✅ Скачано: $($Global:Downloaded)   ❌ Ошибки: $($Global:Failed)   ⏭ Пропущено: $($Global:Skipped)" -ForegroundColor Magenta
Write-Host "  ║   📥 Объём: $(Sz $Global:TotalBytes)   ⚡ Скорость: $avgSpd   ⏱ Время: $elStr" -ForegroundColor Magenta
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

if ($Global:FailedList.Count -gt 0) {
    Write-Host "  ⚠ Не скачано:" -ForegroundColor Red
    $Global:FailedList | ForEach-Object { Write-Host "    • $_" -ForegroundColor DarkRed }
}

Write-Host ""
$o = Read-Host "  Открыть папку? (Y/n)"
if ($o -ne 'n') { Start-Process explorer.exe $Global:RootPath }
Write-Host "  👋 Готово! Download Pack v3.0 ⚡" -ForegroundColor Cyan
