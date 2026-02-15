# 📦 Download Pack — Массовое скачивание программ

## 🚀 Быстрый запуск (из GitHub)

Откройте **PowerShell от имени Администратора** и выполните:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/larlamas/mail-generator/main/Download-Programs/Download-Programs.ps1 | iex
```

## 📋 Локальный запуск

```powershell
# 1. Откройте PowerShell от имени Администратора
# 2. Разрешите выполнение скриптов:
Set-ExecutionPolicy Bypass -Scope Process -Force

# 3. Запустите скрипт:
.\Download-Programs.ps1
```

---

## ⚠️ Рекомендации перед запуском

### 1. Права администратора
Скрипт создаёт папки в `C:\Downloads_Pack`. Для этого **необходимы права Администратора**.

**Как запустить PowerShell от Администратора:**
- Нажмите `Win + X` → выберите `Terminal (Администратор)` или `PowerShell (Администратор)`
- Или найдите PowerShell в меню Пуск → ПКМ → "Запуск от имени администратора"

### 2. Политика выполнения скриптов (ExecutionPolicy)
По умолчанию Windows блокирует запуск `.ps1` скриптов. Выполните одну из команд:

```powershell
# Вариант 1 — Разрешить только для текущей сессии (рекомендуется):
Set-ExecutionPolicy Bypass -Scope Process -Force

# Вариант 2 — Разрешить для текущего пользователя навсегда:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Вариант 3 — Разрешить глобально (не рекомендуется):
Set-ExecutionPolicy Unrestricted -Force
```

### 3. TLS-протокол
Скрипт **автоматически** настраивает TLS 1.2/1.3. Если вы получаете ошибки SSL, выполните вручную:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
```

### 4. Антивирус / Брандмауэр
Некоторые антивирусы могут блокировать массовое скачивание. Рекомендуется:
- **Windows Defender**: добавьте исключение для папки `C:\Downloads_Pack`
- **Брандмауэр**: убедитесь, что PowerShell имеет доступ к интернету

```powershell
# Добавить исключение в Windows Defender:
Add-MpPreference -ExclusionPath "C:\Downloads_Pack"
```

### 5. Прокси / VPN
Если вы за прокси, настройте его в PowerShell:

```powershell
# Настройка прокси (если требуется):
[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy("http://proxy:8080")
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
```

---

## 📁 Структура папок после загрузки

```
C:\Downloads_Pack\
├── 01_Programs\
│   ├── SteamSetup.exe
│   ├── DiscordSetup.exe
│   └── TelegramSetup.exe
│
├── 02_Start_Progs\
│   ├── 7z2600-x64.exe
│   ├── DirectX_WebSetup.exe
│   ├── Visual-C-Runtimes-All-in-One-Dec-2025.zip
│   └── dotnet-runtime-6.0.36-win-x64.exe
│
├── 03_Optimization\
│   ├── BoosterX.exe
│   ├── ISLC_v1.0.3.7.exe
│   └── Autoruns.zip
│
├── 04_Videocard\
│   ├── NVCleanstall_1.19.0.exe
│   ├── DDU-v18.1.4.1_setup.exe
│   ├── GPU-Z.2.69.0.exe
│   ├── nvidiaProfileInspector.zip
│   └── CRU-test-2026-01.zip
│
└── 05_Drivers\
    ├── SDI_1.26.0.7z
    ├── AMD_Chipset_Software_7.11.26.2142.exe
    ├── NVIDIA_591.86_Driver.exe
    ├── L-Connect3_v2.1.15.exe
    ├── X2_CrazyLight_Software.exe
    ├── X2_CrazyLight_Mini_FW_Update.svg
    ├── Samsung_Magician_9.0.0.910.exe
    ├── Focusrite_Control_v3.27.0.exe
    ├── Focusrite_Control_v3.6.0.1822.exe
    └── AMD_Ryzen_Master_3.0.1.exe
```

---

## 🔄 Выгрузка в GitHub и использование через `iwr | iex`

### Шаг 1: Загрузите скрипт в репозиторий

```powershell
cd c:\Programs_gravity\Prog_1
git add Download-Programs.ps1
git commit -m "feat: add download pack script"
git push origin main
```

### Шаг 2: Запуск с любого ПК

```powershell
# Полная однострочная команда для запуска на любом ПК:
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/larlamas/mail-generator/main/Download-Programs/Download-Programs.ps1 | iex"
```

### Шаг 3: Создание ярлыка

Создайте `.bat` файл на рабочем столе:

```bat
@echo off
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/larlamas/mail-generator/main/Download-Programs/Download-Programs.ps1 | iex"
pause
```

---

## 🛠 Особенности скрипта

| Функция | Описание |
|---------|----------|
| 🎨 Красивый вывод | ASCII-баннер, цветной вывод, прогресс-бар |
| 📁 Категории | Файлы сортируются по 5 категориям в отдельные папки |
| ⏭ Пропуск дублей | Если файл уже скачан — пропускается |
| 🔄 Fallback | Если WebClient не сработал — автоматический переход на Invoke-WebRequest |
| 📊 Итоги | Сводка по загрузкам с подсчётом ошибок |
| 🔒 TLS 1.2/1.3 | Автоматическая настройка безопасного соединения |
| 🌐 User-Agent | Установлен User-Agent для обхода блокировок ботов |
