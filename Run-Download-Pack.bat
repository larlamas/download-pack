@echo off
title Download Pack - Programs Downloader
color 0B
echo.
echo  ========================================
echo   Download Pack - Запуск загрузки
echo  ========================================
echo.
echo  Запускаю скрипт из GitHub...
echo.
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/larlamas/mail-generator/main/Download-Programs/Download-Programs.ps1 | iex"
echo.
pause
