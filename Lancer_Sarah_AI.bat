@echo off
title Sarah AI - Assistante 3D
echo Demarrage de Sarah AI...
cd /d "%~dp0"
taskkill /f /im python.exe >nul 2>&1
start /b python serve.py
timeout /t 1 >nul
start http://localhost:8080/sarah_ai_web.html
exit
