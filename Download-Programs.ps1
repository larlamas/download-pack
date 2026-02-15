#Requires -Version 5.1
<#
.SYNOPSIS
    Скрипт массового скачивания программ с красивым оформлением терминала.
.DESCRIPTION
    Скачивает все необходимые программы в папку C:\Downloads_Pack,
    распределяя их по категориям. Поддерживает параллельную загрузку.
.NOTES
    Автор: larlamas
    Версия: 2.0 (Turbo Edition)
    Запуск:
      Локально:   .\Download-Programs.ps1
      Из GitHub:  irm https://raw.githubusercontent.com/larlamas/download-pack/main/Download-Programs.ps1 | iex

    РЕКОМЕНДАЦИИ ПЕРЕД ЗАПУСКОМ:
    1. Запустите PowerShell от имени Администратора
    2. Выполните: Set-ExecutionPolicy Bypass -Scope Process -Force
    3. TLS 1.2/1.3 настраивается автоматически
#>

# ═══════════════════════════════════════════════════════════════
# КОНФИГУРАЦИЯ
# ═══════════════════════════════════════════════════════════════
$Global:RootPath = "C:\Downloads_Pack"
$Global:TotalDownloaded = 0
$Global:TotalFailed = 0
$Global:TotalSkipped = 0
$Global:TotalBytes = 0
$Global:FailedList = [System.Collections.ArrayList]::new()
$Global:StartTime = Get-Date

# ── Настройки скорости ──
$Global:MaxParallel = 4          # Кол-во параллельных загрузок
$Global:BufferSize = 262144     # 256 KB буфер для HttpClient
$Global:TimeoutSec = 300        # Таймаут на загрузку (5 минут)

# Принудительно TLS 1.2 / 1.3
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# Увеличиваем лимит одновременных соединений .NET (по умолчанию всего 2!)
[Net.ServicePointManager]::DefaultConnectionLimit = 32
[Net.ServicePointManager]::Expect100Continue = $false

# Отключаем прогресс-бар Invoke-WebRequest для ускорения
$ProgressPreference = 'SilentlyContinue'

# ═══════════════════════════════════════════════════════════════
# ВИЗУАЛЬНЫЕ ФУНКЦИИ
# ═══════════════════════════════════════════════════════════════

function Show-Banner {
    $banner = @"

   ╔══════════════════════════════════════════════════════════════════╗
   ║                                                                  ║
   ║    ██████╗  ██████╗ ██╗    ██╗███╗   ██╗██╗      ██████╗  █████╗ ║
   ║    ██╔══██╗██╔═══██╗██║    ██║████╗  ██║██║     ██╔═══██╗██╔══██╗║
   ║    ██║  ██║██║   ██║██║ █╗ ██║██╔██╗ ██║██║     ██║   ██║███████║║
   ║    ██║  ██║██║   ██║██║███╗██║██║╚██╗██║██║     ██║   ██║██╔══██║║
   ║    ██████╔╝╚██████╔╝╚███╔███╔╝██║ ╚████║███████╗╚██████╔╝██║  ██║║
   ║    ╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝║
   ║                                                                  ║
   ║          ██████╗  █████╗  ██████╗██╗  ██╗                        ║
   ║          ██╔══██╗██╔══██╗██╔════╝██║ ██╔╝                        ║
   ║          ██████╔╝███████║██║     █████╔╝                         ║
   ║          ██╔═══╝ ██╔══██║██║     ██╔═██╗                         ║
   ║          ██║     ██║  ██║╚██████╗██║  ██╗                        ║
   ║          ╚═╝     ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝                        ║
   ║                                                                  ║
   ║         Programs Download Manager v2.0 ⚡ Turbo                  ║
   ║         Путь: C:\Downloads_Pack                                  ║
   ║                                                                  ║
   ╚══════════════════════════════════════════════════════════════════╝

"@
    Write-Host $banner -ForegroundColor Cyan
}

function Show-CategoryHeader {
    param(
        [string]$CategoryName,
        [string]$Icon,
        [int]$CategoryNumber,
        [int]$TotalCategories
    )
    Write-Host ""
    Write-Host "  ┌──────────────────────────────────────────────────────────────┐" -ForegroundColor DarkCyan
    Write-Host "  │  $Icon  " -ForegroundColor DarkCyan -NoNewline
    Write-Host "$CategoryName" -ForegroundColor Yellow -NoNewline
    $padding = 56 - $CategoryName.Length - 2
    if ($padding -lt 0) { $padding = 0 }
    Write-Host (" " * $padding) -NoNewline
    Write-Host "[$CategoryNumber/$TotalCategories]" -ForegroundColor DarkGray -NoNewline
    Write-Host " │" -ForegroundColor DarkCyan
    Write-Host "  └──────────────────────────────────────────────────────────────┘" -ForegroundColor DarkCyan
    Write-Host ""
}

function Show-DownloadResult {
    param(
        [string]$FileName,
        [string]$Status,     # OK, FAIL, SKIP
        [string]$Detail,
        [int]$FileNumber,
        [int]$TotalFiles
    )
    Write-Host "    " -NoNewline
    switch ($Status) {
        "OK" {
            Write-Host "⬇  " -ForegroundColor Blue -NoNewline
            Write-Host "[$FileNumber/$TotalFiles] " -ForegroundColor DarkGray -NoNewline
            Write-Host "$FileName " -ForegroundColor White -NoNewline
            Write-Host "✅ " -ForegroundColor Green -NoNewline
            Write-Host "$Detail" -ForegroundColor DarkGray
        }
        "FAIL" {
            Write-Host "⬇  " -ForegroundColor Blue -NoNewline
            Write-Host "[$FileNumber/$TotalFiles] " -ForegroundColor DarkGray -NoNewline
            Write-Host "$FileName " -ForegroundColor White -NoNewline
            Write-Host "❌ ОШИБКА" -ForegroundColor Red
            Write-Host "       └─ $Detail" -ForegroundColor DarkRed
        }
        "SKIP" {
            Write-Host "⏭  " -ForegroundColor DarkYellow -NoNewline
            Write-Host "[$FileNumber/$TotalFiles] " -ForegroundColor DarkGray -NoNewline
            Write-Host "$FileName " -ForegroundColor White -NoNewline
            Write-Host "Пропущено" -ForegroundColor DarkYellow -NoNewline
            Write-Host " ($Detail)" -ForegroundColor DarkGray
        }
    }
}

function Get-HumanFileSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Get-HumanSpeed {
    param([double]$BytesPerSec)
    if ($BytesPerSec -ge 1MB) { return "{0:N1} MB/s" -f ($BytesPerSec / 1MB) }
    if ($BytesPerSec -ge 1KB) { return "{0:N1} KB/s" -f ($BytesPerSec / 1KB) }
    return "{0:N0} B/s" -f $BytesPerSec
}

function Show-ProgressBar {
    param([int]$Current, [int]$Total)
    $percent = [math]::Round(($Current / $Total) * 100)
    $filled = [math]::Round($percent / 2)
    $empty = 50 - $filled
    $bar = "█" * $filled + "░" * $empty
    Write-Host "`r  [$bar] $percent% ($Current/$Total)" -ForegroundColor Cyan -NoNewline
    if ($Current -eq $Total) { Write-Host "" }
}

function Show-Summary {
    $elapsed = (Get-Date) - $Global:StartTime
    $elapsedStr = "{0:mm\:ss}" -f $elapsed
    $totalSizeStr = Get-HumanFileSize $Global:TotalBytes
    if ($elapsed.TotalSeconds -gt 0) {
        $avgSpeed = Get-HumanSpeed ($Global:TotalBytes / $elapsed.TotalSeconds)
    }
    else {
        $avgSpeed = "N/A"
    }

    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "  ║                    📊  ИТОГИ ЗАГРУЗКИ                       ║" -ForegroundColor Magenta
    Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Magenta
    Write-Host "  ║                                                              ║" -ForegroundColor Magenta
    Write-Host "  ║   ✅ Успешно скачано:   " -ForegroundColor Magenta -NoNewline
    Write-Host ("{0,-3}" -f $Global:TotalDownloaded) -ForegroundColor Green -NoNewline
    Write-Host "                                   ║" -ForegroundColor Magenta
    Write-Host "  ║   ❌ Ошибки загрузки:   " -ForegroundColor Magenta -NoNewline
    Write-Host ("{0,-3}" -f $Global:TotalFailed) -ForegroundColor Red -NoNewline
    Write-Host "                                   ║" -ForegroundColor Magenta
    Write-Host "  ║   ⏭  Пропущено:         " -ForegroundColor Magenta -NoNewline
    Write-Host ("{0,-3}" -f $Global:TotalSkipped) -ForegroundColor Yellow -NoNewline
    Write-Host "                                   ║" -ForegroundColor Magenta
    Write-Host "  ║   📥 Скачано:           " -ForegroundColor Magenta -NoNewline
    Write-Host ("{0,-12}" -f $totalSizeStr) -ForegroundColor White -NoNewline
    Write-Host "                         ║" -ForegroundColor Magenta
    Write-Host "  ║   ⚡ Ср. скорость:      " -ForegroundColor Magenta -NoNewline
    Write-Host ("{0,-12}" -f $avgSpeed) -ForegroundColor Cyan -NoNewline
    Write-Host "                         ║" -ForegroundColor Magenta
    Write-Host "  ║   ⏱  Время:             " -ForegroundColor Magenta -NoNewline
    Write-Host ("{0,-8}" -f $elapsedStr) -ForegroundColor Cyan -NoNewline
    Write-Host "                              ║" -ForegroundColor Magenta
    Write-Host "  ║   📂 Папка:             C:\Downloads_Pack" -ForegroundColor Magenta -NoNewline
    Write-Host "                   ║" -ForegroundColor Magenta
    Write-Host "  ║                                                              ║" -ForegroundColor Magenta
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

    if ($Global:FailedList.Count -gt 0) {
        Write-Host ""
        Write-Host "  ⚠  Не удалось скачать:" -ForegroundColor Red
        foreach ($item in $Global:FailedList) {
            Write-Host "     • $item" -ForegroundColor DarkRed
        }
    }

    Write-Host ""
    Write-Host "  📂 Открыть папку: " -ForegroundColor DarkGray -NoNewline
    Write-Host "explorer.exe C:\Downloads_Pack" -ForegroundColor White
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
# ФУНКЦИЯ БЫСТРОЙ ЗАГРУЗКИ (HttpClient + большой буфер)
# ═══════════════════════════════════════════════════════════════

function Start-FastDownload {
    param(
        [string]$Url,
        [string]$OutputPath,
        [int]$BufferSize = 262144,
        [int]$TimeoutSec = 300
    )

    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $true
    $handler.MaxAutomaticRedirections = 10

    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
    $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")

    try {
        $response = $client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result

        if (-not $response.IsSuccessStatusCode) {
            throw "HTTP $($response.StatusCode)"
        }

        $stream = $response.Content.ReadAsStreamAsync().Result
        $fileStream = [System.IO.File]::Create($OutputPath)
        $buffer = New-Object byte[] $BufferSize
        $totalRead = 0

        while (($read = $stream.Read($buffer, 0, $BufferSize)) -gt 0) {
            $fileStream.Write($buffer, 0, $read)
            $totalRead += $read
        }

        $fileStream.Close()
        $stream.Close()
        $client.Dispose()

        return $totalRead
    }
    catch {
        if ($client) { $client.Dispose() }
        throw $_
    }
}

# ═══════════════════════════════════════════════════════════════
# ОСНОВНАЯ ФУНКЦИЯ ЗАГРУЗКИ С ЗАМЕРОМ СКОРОСТИ
# ═══════════════════════════════════════════════════════════════

function Start-FileDownload {
    param(
        [string]$Url,
        [string]$FileName,
        [string]$Category,
        [int]$FileNumber,
        [int]$TotalFiles
    )

    $categoryPath = Join-Path $Global:RootPath $Category
    if (-not (Test-Path $categoryPath)) {
        New-Item -ItemType Directory -Path $categoryPath -Force | Out-Null
    }

    $outputPath = Join-Path $categoryPath $FileName

    # Пропуск, если файл уже скачан
    if (Test-Path $outputPath) {
        $existingSize = (Get-Item $outputPath).Length
        if ($existingSize -gt 0) {
            Show-DownloadResult -FileName $FileName -Status "SKIP" `
                -Detail (Get-HumanFileSize $existingSize) `
                -FileNumber $FileNumber -TotalFiles $TotalFiles
            $Global:TotalSkipped++
            return
        }
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        # Метод 1: Быстрый HttpClient с большим буфером
        $bytesDownloaded = Start-FastDownload -Url $Url -OutputPath $outputPath `
            -BufferSize $Global:BufferSize -TimeoutSec $Global:TimeoutSec

        $sw.Stop()

        if ($bytesDownloaded -gt 0) {
            $speed = $bytesDownloaded / $sw.Elapsed.TotalSeconds
            $sizeStr = Get-HumanFileSize $bytesDownloaded
            $speedStr = Get-HumanSpeed $speed

            Show-DownloadResult -FileName $FileName -Status "OK" `
                -Detail "$sizeStr @ $speedStr" `
                -FileNumber $FileNumber -TotalFiles $TotalFiles

            $Global:TotalDownloaded++
            $Global:TotalBytes += $bytesDownloaded
        }
        else {
            Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
            Show-DownloadResult -FileName $FileName -Status "FAIL" `
                -Detail "Файл пустой (0 байт)" `
                -FileNumber $FileNumber -TotalFiles $TotalFiles
            $Global:TotalFailed++
            $Global:FailedList.Add($FileName) | Out-Null
        }
    }
    catch {
        $sw.Stop()
        Remove-Item $outputPath -Force -ErrorAction SilentlyContinue

        # Fallback: WebClient
        try {
            $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
            $wc.DownloadFile($Url, $outputPath)
            $wc.Dispose()
            $sw2.Stop()

            if ((Test-Path $outputPath) -and ((Get-Item $outputPath).Length -gt 0)) {
                $fileSize = (Get-Item $outputPath).Length
                $speed = $fileSize / $sw2.Elapsed.TotalSeconds
                $sizeStr = Get-HumanFileSize $fileSize
                $speedStr = Get-HumanSpeed $speed

                Show-DownloadResult -FileName $FileName -Status "OK" `
                    -Detail "$sizeStr @ $speedStr (fallback)" `
                    -FileNumber $FileNumber -TotalFiles $TotalFiles

                $Global:TotalDownloaded++
                $Global:TotalBytes += $fileSize
            }
            else {
                Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
                Show-DownloadResult -FileName $FileName -Status "FAIL" `
                    -Detail "Файл пустой после fallback" `
                    -FileNumber $FileNumber -TotalFiles $TotalFiles
                $Global:TotalFailed++
                $Global:FailedList.Add($FileName) | Out-Null
            }
        }
        catch {
            Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
            $errMsg = $_.Exception.Message
            if ($errMsg.Length -gt 70) { $errMsg = $errMsg.Substring(0, 67) + "..." }
            Show-DownloadResult -FileName $FileName -Status "FAIL" `
                -Detail $errMsg `
                -FileNumber $FileNumber -TotalFiles $TotalFiles
            $Global:TotalFailed++
            $Global:FailedList.Add($FileName) | Out-Null
        }
    }
}

# ═══════════════════════════════════════════════════════════════
# ПАРАЛЛЕЛЬНАЯ ЗАГРУЗКА ЦЕЛОЙ КАТЕГОРИИ
# ═══════════════════════════════════════════════════════════════

function Start-ParallelCategoryDownload {
    param(
        [array]$Files,
        [string]$CategoryFolder,
        [int]$MaxJobs
    )

    $categoryPath = Join-Path $Global:RootPath $CategoryFolder
    if (-not (Test-Path $categoryPath)) {
        New-Item -ItemType Directory -Path $categoryPath -Force | Out-Null
    }

    # Скрипт-блок для фоновой загрузки
    $downloadScript = {
        param($Url, $OutputPath, $BufferSize, $TimeoutSec)

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        [Net.ServicePointManager]::DefaultConnectionLimit = 32

        $result = @{ Success = $false; Bytes = 0; Speed = 0; Error = "" }
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $handler = New-Object System.Net.Http.HttpClientHandler
            $handler.AllowAutoRedirect = $true
            $handler.MaxAutomaticRedirections = 10
            $client = New-Object System.Net.Http.HttpClient($handler)
            $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
            $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

            $response = $client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
            if (-not $response.IsSuccessStatusCode) { throw "HTTP $($response.StatusCode)" }

            $stream = $response.Content.ReadAsStreamAsync().Result
            $fileStream = [System.IO.File]::Create($OutputPath)
            $buffer = New-Object byte[] $BufferSize
            $totalRead = 0
            while (($read = $stream.Read($buffer, 0, $BufferSize)) -gt 0) {
                $fileStream.Write($buffer, 0, $read)
                $totalRead += $read
            }
            $fileStream.Close(); $stream.Close(); $client.Dispose()
            $sw.Stop()

            if ($totalRead -gt 0) {
                $result.Success = $true
                $result.Bytes = $totalRead
                $result.Speed = $totalRead / $sw.Elapsed.TotalSeconds
            }
        }
        catch {
            # Fallback: WebClient
            try {
                $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                $wc.DownloadFile($Url, $OutputPath)
                $wc.Dispose()
                $sw2.Stop()

                $fi = Get-Item $OutputPath -ErrorAction SilentlyContinue
                if ($fi -and $fi.Length -gt 0) {
                    $result.Success = $true
                    $result.Bytes = $fi.Length
                    $result.Speed = $fi.Length / $sw2.Elapsed.TotalSeconds
                }
                else {
                    Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
                    $result.Error = "Файл пустой"
                }
            }
            catch {
                Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
                $result.Error = $_.Exception.Message
                if ($result.Error.Length -gt 70) { $result.Error = $result.Error.Substring(0, 67) + "..." }
            }
        }
        return $result
    }

    # Запускаем задания пачками
    $jobs = @()
    $fileNum = 0
    $totalInCat = $Files.Count

    foreach ($file in $Files) {
        $fileNum++
        $outPath = Join-Path $categoryPath $file.FileName

        # Пропуск, если файл уже скачан
        if ((Test-Path $outPath) -and ((Get-Item $outPath).Length -gt 0)) {
            $existingSize = (Get-Item $outPath).Length
            Show-DownloadResult -FileName $file.FileName -Status "SKIP" `
                -Detail (Get-HumanFileSize $existingSize) `
                -FileNumber $fileNum -TotalFiles $totalInCat
            $Global:TotalSkipped++
            continue
        }

        Write-Host "    ⬇  " -ForegroundColor Blue -NoNewline
        Write-Host "[$fileNum/$totalInCat] " -ForegroundColor DarkGray -NoNewline
        Write-Host "$($file.FileName) " -ForegroundColor White -NoNewline
        Write-Host "⏳ Загрузка..." -ForegroundColor DarkYellow

        $job = Start-Job -ScriptBlock $downloadScript `
            -ArgumentList $file.Url, $outPath, $Global:BufferSize, $Global:TimeoutSec

        $jobs += @{
            Job        = $job
            FileName   = $file.FileName
            FileNumber = $fileNum
            TotalFiles = $totalInCat
        }

        # Контроль параллельности: ждём, если набралось $MaxJobs
        while (($jobs | Where-Object { $_.Job.State -eq 'Running' }).Count -ge $MaxJobs) {
            Start-Sleep -Milliseconds 500
        }

        # Обработка завершённых
        $completed = $jobs | Where-Object { $_.Job.State -ne 'Running' }
        foreach ($c in $completed) {
            $result = Receive-Job -Job $c.Job
            Remove-Job -Job $c.Job -Force

            if ($result.Success) {
                $sizeStr = Get-HumanFileSize $result.Bytes
                $speedStr = Get-HumanSpeed $result.Speed
                Show-DownloadResult -FileName $c.FileName -Status "OK" `
                    -Detail "$sizeStr @ $speedStr" `
                    -FileNumber $c.FileNumber -TotalFiles $c.TotalFiles
                $Global:TotalDownloaded++
                $Global:TotalBytes += $result.Bytes
            }
            else {
                Show-DownloadResult -FileName $c.FileName -Status "FAIL" `
                    -Detail $result.Error `
                    -FileNumber $c.FileNumber -TotalFiles $c.TotalFiles
                $Global:TotalFailed++
                $Global:FailedList.Add($c.FileName) | Out-Null
            }
        }
        $jobs = @($jobs | Where-Object { $_.Job.State -eq 'Running' -or $_.Job.Id -notin ($completed.Job.Id) })
    }

    # Дожидаемся оставшихся
    $remaining = $jobs | Where-Object { $_.Job -ne $null }
    if ($remaining.Count -gt 0) {
        $remaining.Job | Wait-Job | Out-Null
        foreach ($c in $remaining) {
            $result = Receive-Job -Job $c.Job
            Remove-Job -Job $c.Job -Force

            if ($result.Success) {
                $sizeStr = Get-HumanFileSize $result.Bytes
                $speedStr = Get-HumanSpeed $result.Speed
                Show-DownloadResult -FileName $c.FileName -Status "OK" `
                    -Detail "$sizeStr @ $speedStr" `
                    -FileNumber $c.FileNumber -TotalFiles $c.TotalFiles
                $Global:TotalDownloaded++
                $Global:TotalBytes += $result.Bytes
            }
            else {
                Show-DownloadResult -FileName $c.FileName -Status "FAIL" `
                    -Detail $result.Error `
                    -FileNumber $c.FileNumber -TotalFiles $c.TotalFiles
                $Global:TotalFailed++
                $Global:FailedList.Add($c.FileName) | Out-Null
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════
# ОПРЕДЕЛЕНИЕ СПИСКА ЗАГРУЗОК ПО КАТЕГОРИЯМ
# ═══════════════════════════════════════════════════════════════

$Categories = @(
    @{
        Name   = "PROGRAMS"
        Icon   = "🎮"
        Folder = "01_Programs"
        Files  = @(
            @{ Url = "https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe"; FileName = "SteamSetup.exe" }
            @{ Url = "https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64"; FileName = "DiscordSetup.exe" }
            @{ Url = "https://telegram.org/dl/desktop/win64"; FileName = "TelegramSetup.exe" }
        )
    },
    @{
        Name   = "START PROGS — Базовые компоненты"
        Icon   = "⚙️"
        Folder = "02_Start_Progs"
        Files  = @(
            @{ Url = "https://www.7-zip.org/a/7z2600-x64.exe"; FileName = "7z2600-x64.exe" }
            @{ Url = "https://download.microsoft.com/download/1/7/1/1718ccc4-6315-4d8e-9543-8e28a4e18c4c/dxwebsetup.exe"; FileName = "DirectX_WebSetup.exe" }
            @{ Url = "https://nl1-dl.techpowerup.com/files/yVj4unqbFybs53DtKdfJ9A/1771191835/Visual-C-Runtimes-All-in-One-Dec-2025.zip"; FileName = "Visual-C-Runtimes-All-in-One-Dec-2025.zip" }
            @{ Url = "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/6.0.36/windowsdesktop-runtime-6.0.36-win-x64.exe"; FileName = "dotnet-runtime-6.0.36-win-x64.exe" }
        )
    },
    @{
        Name   = "OPTIMIZATION — Оптимизация системы"
        Icon   = "🚀"
        Folder = "03_Optimization"
        Files  = @(
            @{ Url = "https://dl.boosterx.org/BoosterX.exe"; FileName = "BoosterX.exe" }
            @{ Url = "https://www.wagnardsoft.com/ISLC/ISLC%20v1.0.3.7.exe"; FileName = "ISLC_v1.0.3.7.exe" }
            @{ Url = "https://download.sysinternals.com/files/Autoruns.zip"; FileName = "Autoruns.zip" }
        )
    },
    @{
        Name   = "VIDEOCARD — Видеокарта"
        Icon   = "🖥️"
        Folder = "04_Videocard"
        Files  = @(
            @{ Url = "https://nl1-dl.techpowerup.com/files/9QEeaOQAH8zcOSfZlt9_Uw/1771197642/NVCleanstall_1.19.0.exe"; FileName = "NVCleanstall_1.19.0.exe" }
            @{ Url = "https://nl1-dl.techpowerup.com/files/p76N8gwtPRPEg6xAZevfgQ/1771197703/DDU-v18.1.4.1_setup.exe"; FileName = "DDU-v18.1.4.1_setup.exe" }
            @{ Url = "https://nl1-dl.techpowerup.com/files/KUf2FQXSWuwuSaY4Kdjh4Q/1771197789/GPU-Z.2.69.0.exe"; FileName = "GPU-Z.2.69.0.exe" }
            @{ Url = "https://github.com/Orbmu2k/nvidiaProfileInspector/releases/download/2.4.0.31/nvidiaProfileInspector.zip"; FileName = "nvidiaProfileInspector.zip" }
            @{ Url = "https://www.monitortests.com/download/cru-test/cru-test-2026-01.zip"; FileName = "CRU-test-2026-01.zip" }
        )
    },
    @{
        Name   = "DRIVERS — Драйверы"
        Icon   = "💽"
        Folder = "05_Drivers"
        Files  = @(
            @{ Url = "https://driveroff.net/drv/SDI_1.26.0.7z"; FileName = "SDI_1.26.0.7z" }
            @{ Url = "https://nl1-dl.techpowerup.com/files/YWDgCLKJMu0AMc5mIRnsNA/1771197767/AMD_Chipset_Software_7.11.26.2142.exe"; FileName = "AMD_Chipset_Software_7.11.26.2142.exe" }
            @{ Url = "https://nl1-dl.techpowerup.com/files/cJX7Ynfxb01_TC1FDjXZKw/1771197730/591.86-desktop-win10-win11-64bit-international-dch-whql.exe"; FileName = "NVIDIA_591.86_Driver.exe" }
            @{ Url = "https://lianli-update.oss-cn-beijing.aliyuncs.com/L3_CX/20260123-L-Connect%203-x64-hotfix-hotfix-change-sdk-v2.1.15-f93e2a64.exe"; FileName = "L-Connect3_v2.1.15.exe" }
            @{ Url = "https://drive.usercontent.google.com/download?id=1yC3Fg2yfSplqsACATQifmbL62FU_P3p2&export=download&authuser=0&confirm=t&uuid=a25d3845-aa1d-4e54-ac6a-e2e5493f0433&at=APcXIO006tLTPcoV1vcZY4znI_Vm%3A1771155597078"; FileName = "X2_CrazyLight_Software.exe" }
            @{ Url = "https://www.pulsar.gg/cdn/shop/t/79/assets/download.svg?v=8351372234618339141713834745"; FileName = "X2_CrazyLight_Mini_FW_Update.svg" }
            @{ Url = "https://download.semiconductor.samsung.com/resources/software-resources/Samsung_Magician_Installer_Official_9.0.0.910.exe"; FileName = "Samsung_Magician_9.0.0.910.exe" }
            @{ Url = "https://fael-downloads-prod.focusrite.com/customer/prod/downloads/focusrite_control_v3_27_0.exe"; FileName = "Focusrite_Control_v3.27.0.exe" }
            @{ Url = "https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/Focusrite%20Control%20-%203.6.0.1822_0.exe"; FileName = "Focusrite_Control_v3.6.0.1822.exe" }
            @{ Url = "https://www2.ati.com/drivers/amd_ryzen_master_3_0_1_4819.exe"; FileName = "AMD_Ryzen_Master_3.0.1.exe" }
        )
    }
)

# ═══════════════════════════════════════════════════════════════
# ЗАПУСК
# ═══════════════════════════════════════════════════════════════

Clear-Host
Show-Banner

# Информация о среде
Write-Host "  ┌──────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
Write-Host "  │  📋 Информация о системе                                    │" -ForegroundColor DarkGray
Write-Host "  ├──────────────────────────────────────────────────────────────┤" -ForegroundColor DarkGray
Write-Host "  │  OS:        $([System.Environment]::OSVersion.VersionString)" -ForegroundColor DarkGray
Write-Host "  │  PS:        $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
Write-Host "  │  Дата:      $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')" -ForegroundColor DarkGray
Write-Host "  │  Права:     " -ForegroundColor DarkGray -NoNewline
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) { Write-Host "Администратор ✅" -ForegroundColor Green }
else { Write-Host "Обычный пользователь ⚠" -ForegroundColor Yellow }
Write-Host "  │  TLS:       1.2 / 1.3 ✅" -ForegroundColor DarkGray
Write-Host "  │  Буфер:     $(Get-HumanFileSize $Global:BufferSize) ⚡" -ForegroundColor DarkGray
Write-Host "  │  Соединения: $([Net.ServicePointManager]::DefaultConnectionLimit)" -ForegroundColor DarkGray
Write-Host "  │  Целевая:   $Global:RootPath" -ForegroundColor DarkGray
Write-Host "  └──────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray

# Подсчёт файлов
$totalFiles = 0
foreach ($cat in $Categories) { $totalFiles += $cat.Files.Count }
Write-Host ""
Write-Host "  📦 Всего файлов к загрузке: " -ForegroundColor White -NoNewline
Write-Host "$totalFiles" -ForegroundColor Yellow -NoNewline
Write-Host " в " -ForegroundColor White -NoNewline
Write-Host "$($Categories.Count)" -ForegroundColor Yellow -NoNewline
Write-Host " категориях" -ForegroundColor White

# Выбор режима
Write-Host ""
Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  Выберите режим загрузки:" -ForegroundColor White
Write-Host ""
Write-Host "    [1] ⚡ Параллельная загрузка" -ForegroundColor Cyan -NoNewline
Write-Host "  ($($Global:MaxParallel) файла одновременно — БЫСТРО)" -ForegroundColor DarkGray
Write-Host "    [2] 📥 Последовательная загрузка" -ForegroundColor White -NoNewline
Write-Host "  (по одному — стабильно)" -ForegroundColor DarkGray
Write-Host ""
$modeChoice = Read-Host "  Режим (1/2, Enter = 1)"
if ([string]::IsNullOrWhiteSpace($modeChoice)) { $modeChoice = "1" }
$useParallel = ($modeChoice -eq "1")

if ($useParallel) {
    Write-Host ""
    Write-Host "  ⚡ Режим: ПАРАЛЛЕЛЬНАЯ загрузка ($($Global:MaxParallel) потока)" -ForegroundColor Cyan
}
else {
    Write-Host ""
    Write-Host "  📥 Режим: ПОСЛЕДОВАТЕЛЬНАЯ загрузка" -ForegroundColor White
}

# Создаём корневую папку
if (-not (Test-Path $Global:RootPath)) {
    New-Item -ItemType Directory -Path $Global:RootPath -Force | Out-Null
    Write-Host "  📁 Создана папка: $Global:RootPath" -ForegroundColor Green
}
else {
    Write-Host "  📁 Папка существует: $Global:RootPath" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  ▶  Начинаем загрузку через 3 секунды..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# Глобальный счётчик
$globalFileNum = 0
$catNum = 0

foreach ($category in $Categories) {
    $catNum++

    Show-CategoryHeader -CategoryName $category.Name -Icon $category.Icon `
        -CategoryNumber $catNum -TotalCategories $Categories.Count

    if ($useParallel) {
        # ⚡ Параллельная загрузка
        Start-ParallelCategoryDownload -Files $category.Files `
            -CategoryFolder $category.Folder -MaxJobs $Global:MaxParallel
        $globalFileNum += $category.Files.Count
    }
    else {
        # 📥 Последовательная загрузка
        $localNum = 0
        foreach ($file in $category.Files) {
            $localNum++
            $globalFileNum++
            Start-FileDownload -Url $file.Url -FileName $file.FileName `
                -Category $category.Folder `
                -FileNumber $localNum -TotalFiles $category.Files.Count
        }
    }

    Show-ProgressBar -Current $globalFileNum -Total $totalFiles
}

# Итоги
Show-Summary

# Открыть папку
Write-Host ""
$openFolder = Read-Host "  Открыть папку с загрузками? (Y/n)"
if ($openFolder -ne 'n' -and $openFolder -ne 'N') {
    Start-Process explorer.exe $Global:RootPath
}

Write-Host ""
Write-Host "  👋 Готово! Спасибо за использование Download Pack v2.0 ⚡" -ForegroundColor Cyan
Write-Host ""
