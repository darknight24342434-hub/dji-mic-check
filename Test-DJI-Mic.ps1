$ErrorActionPreference = "Stop"
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Output = Join-Path $ScriptDir "dji_test.wav"

python "$ScriptDir\voice_input.py" record --device "Wireless Microphone RX" --seconds 5 --output $Output
ffmpeg -hide_banner -i $Output -af volumedetect -f null NUL

Write-Host ""
Write-Host "測試錄音已存到：$Output"
Write-Host "如果 max_volume 低於 -35 dB，請提高 DJI 或 Windows 的麥克風輸入音量。"
