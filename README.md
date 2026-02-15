# 📦 Download Pack — Массовое скачивание программ для Windows

> Скрипт PowerShell для автоматического скачивания всех необходимых программ после переустановки Windows. Красивый терминальный интерфейс, категоризация по папкам, отслеживание прогресса.

---

## 🚀 Быстрый запуск (одна команда)

Откройте **PowerShell от имени Администратора** и выполните:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/larlamas/download-pack/main/Download-Programs.ps1 | iex
```

---

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

### 1. 🔐 Права администратора
Скрипт создаёт папки в `C:\Downloads_Pack`. Для этого **необходимы права Администратора**.

> **Как запустить PowerShell от Администратора:**
> - `Win + X` → `Terminal (Администратор)` / `PowerShell (Администратор)`
> - Или: Пуск → PowerShell → ПКМ → "Запуск от имени администратора"

### 2. 📜 Политика выполнения скриптов

По умолчанию Windows блокирует запуск `.ps1` скриптов:

| Вариант | Команда | Рекомендация |
|---------|---------|--------------|
| Только текущая сессия | `Set-ExecutionPolicy Bypass -Scope Process -Force` | ✅ Рекомендуется |
| Для пользователя | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force` | ⚠️ Осторожно |
| Глобально | `Set-ExecutionPolicy Unrestricted -Force` | ❌ Не рекомендуется |

### 3. 🔒 TLS-протокол
Скрипт **автоматически** настраивает TLS 1.2/1.3. Если ошибки SSL — выполните вручную:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
```

### 4. 🛡️ Антивирус / Брандмауэр

Добавьте исключение в Windows Defender:

```powershell
Add-MpPreference -ExclusionPath "C:\Downloads_Pack"
```

### 5. 🌐 Прокси / VPN

```powershell
[System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy("http://proxy:8080")
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
```

---

## 📁 Структура папок после загрузки

```
C:\Downloads_Pack\
│
├── 📂 01_Programs\
│   ├── SteamSetup.exe
│   ├── DiscordSetup.exe
│   └── TelegramSetup.exe
│
├── 📂 02_Start_Progs\
│   ├── 7z2600-x64.exe
│   ├── DirectX_WebSetup.exe
│   ├── Visual-C-Runtimes-All-in-One-Dec-2025.zip
│   └── dotnet-runtime-6.0.36-win-x64.exe
│
├── 📂 03_Optimization\
│   ├── BoosterX.exe
│   ├── ISLC_v1.0.3.7.exe
│   └── Autoruns.zip
│
├── 📂 04_Videocard\
│   ├── NVCleanstall_1.19.0.exe
│   ├── DDU-v18.1.4.1_setup.exe
│   ├── GPU-Z.2.69.0.exe
│   ├── nvidiaProfileInspector.zip
│   └── CRU-test-2026-01.zip
│
└── 📂 05_Drivers\
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

## 🛠 Особенности

| Функция | Описание |
|---------|----------|
| 🎨 Красивый вывод | ASCII-баннер, цветной вывод, прогресс-бар |
| 📁 Категории | 5 категорий — отдельные папки с нумерацией |
| ⏭ Пропуск дублей | Уже скачанные файлы пропускаются |
| 🔄 Fallback | WebClient → Invoke-WebRequest при ошибке |
| 📊 Итоги | Сводка: скачано / ошибки / пропущено / время |
| 🔒 TLS 1.2/1.3 | Автоматическая настройка протоколов |
| 🌐 User-Agent | Обход блокировок от ботов |

---

## 📦 Создание ярлыка (.bat)

Создайте файл `Run-Download-Pack.bat` на рабочем столе:

```bat
@echo off
title Download Pack
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/larlamas/download-pack/main/Download-Programs.ps1 | iex"
pause
```

---

## 📄 Лицензия

MIT © [larlamas](https://github.com/larlamas)
