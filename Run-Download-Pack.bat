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
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/larlamas/download-pack/main/Download-Programs.ps1 | iex"
echo.
pause
