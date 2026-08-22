@echo off
chcp 65001 >nul
setlocal
set PYTHONUTF8=1
cd /d "%~dp0"
python "%~dp0voice_input.py" devices
echo.
pause
