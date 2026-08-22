@echo off
chcp 65001 >nul
setlocal
set PYTHONUTF8=1
cd /d "%~dp0"
python "%~dp0voice_input.py" record --device "Wireless Microphone RX" --seconds 5 --output "%~dp0dji_test.wav"
ffmpeg -hide_banner -i "%~dp0dji_test.wav" -af volumedetect -f null NUL
echo.
echo 測試錄音已存到：%~dp0dji_test.wav
echo 如果 max_volume 低於 -35 dB，請提高 DJI 或 Windows 的麥克風輸入音量。
echo.
pause
