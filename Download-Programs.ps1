#Requires -Version 5.1
<#
.SYNOPSIS
    Скрипт массового скачивания программ с красивым оформлением терминала.
.DESCRIPTION
    Скачивает все необходимые программы в папку C:\Downloads_Pack, 
    распределяя их по категориям. Поддерживает запуск через iwr | iex.
.NOTES
    Автор: larlamas
    Версия: 1.0
    Запуск: 
      Локально:   .\Download-Programs.ps1
      Из GitHub:  irm https://raw.githubusercontent.com/larlamas/mail-generator/main/Download-Programs.ps1 | iex
    
    РЕКОМЕНДАЦИИ ПЕРЕД ЗАПУСКОМ:
    1. Запустите PowerShell от имени Администратора
    2. Выполните: Set-ExecutionPolicy Bypass -Scope Process -Force
    3. Для обхода TLS ошибок скрипт автоматически настраивает [Net.SecurityProtocolType]::Tls12
#>

# ═══════════════════════════════════════════════════════════════
# КОНФИГУРАЦИЯ
# ═══════════════════════════════════════════════════════════════
$Global:RootPath = "C:\Downloads_Pack"
$Global:TotalDownloaded = 0
$Global:TotalFailed = 0
$Global:TotalSkipped = 0
$Global:FailedList = @()
$Global:StartTime = Get-Date

# Принудительно включаем TLS 1.2 / 1.3 для всех загрузок
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# Отключаем прогресс-бар Invoke-WebRequest для ускорения загрузки
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
   ║              Programs Download Manager v1.0                      ║
   ║              Путь: C:\Downloads_Pack                             ║
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

function Show-DownloadStart {
    param(
        [string]$FileName,
        [int]$FileNumber,
        [int]$TotalFiles
    )
    
    Write-Host "    ⬇  " -ForegroundColor Blue -NoNewline
    Write-Host "[$FileNumber/$TotalFiles] " -ForegroundColor DarkGray -NoNewline
    Write-Host "$FileName" -ForegroundColor White -NoNewline
    Write-Host " ... " -ForegroundColor DarkGray -NoNewline
}

function Show-DownloadSuccess {
    param([string]$Size)
    Write-Host "✅ OK " -ForegroundColor Green -NoNewline
    Write-Host "($Size)" -ForegroundColor DarkGray
}

function Show-DownloadFailed {
    param([string]$Reason)
    Write-Host "❌ ОШИБКА" -ForegroundColor Red
    Write-Host "       └─ $Reason" -ForegroundColor DarkRed
}

function Show-DownloadSkipped {
    param([string]$Reason)
    Write-Host "⏭  Пропущено" -ForegroundColor DarkYellow
    Write-Host "       └─ $Reason" -ForegroundColor DarkYellow
}

function Get-HumanFileSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Show-ProgressBar {
    param(
        [int]$Current,
        [int]$Total
    )
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
# ОСНОВНАЯ ФУНКЦИЯ ЗАГРУЗКИ
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
            Show-DownloadStart -FileName $FileName -FileNumber $FileNumber -TotalFiles $TotalFiles
            Show-DownloadSkipped -Reason "Файл уже существует ($(Get-HumanFileSize $existingSize))"
            $Global:TotalSkipped++
            return
        }
    }
    
    Show-DownloadStart -FileName $FileName -FileNumber $FileNumber -TotalFiles $TotalFiles
    
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        $webClient.DownloadFile($Url, $outputPath)
        $webClient.Dispose()
        
        if (Test-Path $outputPath) {
            $fileSize = (Get-Item $outputPath).Length
            if ($fileSize -gt 0) {
                Show-DownloadSuccess -Size (Get-HumanFileSize $fileSize)
                $Global:TotalDownloaded++
            }
            else {
                Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
                Show-DownloadFailed -Reason "Файл пустой (0 байт)"
                $Global:TotalFailed++
                $Global:FailedList += $FileName
            }
        }
        else {
            Show-DownloadFailed -Reason "Файл не создан"
            $Global:TotalFailed++
            $Global:FailedList += $FileName
        }
    }
    catch {
        # Fallback на Invoke-WebRequest
        try {
            Invoke-WebRequest -Uri $Url -OutFile $outputPath -UseBasicParsing -ErrorAction Stop `
                -Headers @{"User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" }
            
            if ((Test-Path $outputPath) -and ((Get-Item $outputPath).Length -gt 0)) {
                $fileSize = (Get-Item $outputPath).Length
                Show-DownloadSuccess -Size (Get-HumanFileSize $fileSize)
                $Global:TotalDownloaded++
            }
            else {
                Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
                Show-DownloadFailed -Reason "Файл пустой после fallback"
                $Global:TotalFailed++
                $Global:FailedList += $FileName
            }
        }
        catch {
            Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
            $errMsg = $_.Exception.Message
            if ($errMsg.Length -gt 80) { $errMsg = $errMsg.Substring(0, 77) + "..." }
            Show-DownloadFailed -Reason $errMsg
            $Global:TotalFailed++
            $Global:FailedList += $FileName
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

# Очистка экрана
Clear-Host

# Показываем баннер
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
if ($isAdmin) {
    Write-Host "Администратор ✅" -ForegroundColor Green
}
else {
    Write-Host "Обычный пользователь ⚠" -ForegroundColor Yellow
}
Write-Host "  │  TLS:       1.2 / 1.3 ✅" -ForegroundColor DarkGray
Write-Host "  │  Целевая:   $Global:RootPath" -ForegroundColor DarkGray
Write-Host "  └──────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray

# Подсчёт общего количества файлов
$totalFiles = 0
foreach ($cat in $Categories) { $totalFiles += $cat.Files.Count }
Write-Host ""
Write-Host "  📦 Всего файлов к загрузке: " -ForegroundColor White -NoNewline
Write-Host "$totalFiles" -ForegroundColor Yellow -NoNewline
Write-Host " в " -ForegroundColor White -NoNewline
Write-Host "$($Categories.Count)" -ForegroundColor Yellow -NoNewline
Write-Host " категориях" -ForegroundColor White
Write-Host ""

# Создаём корневую папку
if (-not (Test-Path $Global:RootPath)) {
    New-Item -ItemType Directory -Path $Global:RootPath -Force | Out-Null
    Write-Host "  📁 Создана папка: $Global:RootPath" -ForegroundColor Green
}
else {
    Write-Host "  📁 Папка существует: $Global:RootPath" -ForegroundColor DarkGray
}

# Пауза перед началом
Write-Host ""
Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  ▶  Начинаем загрузку через 3 секунды..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# Глобальный счётчик файлов
$globalFileNum = 0

# Обработка каждой категории
$catNum = 0
foreach ($category in $Categories) {
    $catNum++
    
    Show-CategoryHeader -CategoryName $category.Name -Icon $category.Icon `
        -CategoryNumber $catNum -TotalCategories $Categories.Count
    
    $localNum = 0
    foreach ($file in $category.Files) {
        $localNum++
        $globalFileNum++
        
        Start-FileDownload -Url $file.Url -FileName $file.FileName `
            -Category $category.Folder `
            -FileNumber $localNum -TotalFiles $category.Files.Count
    }
    
    # Прогресс-бар после каждой категории
    Show-ProgressBar -Current $globalFileNum -Total $totalFiles
}

# Итоги
Show-Summary

# Предложение открыть папку
Write-Host ""
$openFolder = Read-Host "  Открыть папку с загрузками? (Y/n)"
if ($openFolder -ne 'n' -and $openFolder -ne 'N') {
    Start-Process explorer.exe $Global:RootPath
}

Write-Host ""
Write-Host "  👋 Готово! Спасибо за использование Download Pack." -ForegroundColor Cyan
Write-Host ""
