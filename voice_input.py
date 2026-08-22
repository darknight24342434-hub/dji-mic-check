#!/usr/bin/env python3
"""
DJI wireless microphone device helper for Windows.

Treat the DJI receiver as an ordinary Windows recording device: list the
available capture devices and record a short WAV to check the signal level.
Purely local — it only shells out to ffmpeg, contacts no external service and
needs no API key.

Speech-to-text is deliberately out of scope; use a local offline transcriber
(for example faster-whisper). Earlier cloud-transcription subcommands were
removed from this tool.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


DEFAULT_AUDIO_FILTER = "highpass=f=80,lowpass=f=7800,dynaudnorm=f=150:g=8:p=0.90,alimiter=limit=0.95"


class VoiceInputError(RuntimeError):
    pass


def run_capture(command: list[str], *, input_text: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        encoding="utf-8",
        errors="replace",
    )


def ensure_ffmpeg() -> None:
    try:
        completed = run_capture(["ffmpeg", "-version"])
    except FileNotFoundError as exc:
        raise VoiceInputError("找不到 ffmpeg。請先安裝 ffmpeg，或確認 ffmpeg.exe 在 PATH 裡。") from exc
    if completed.returncode != 0:
        raise VoiceInputError("ffmpeg 無法執行。")


def list_audio_devices() -> list[str]:
    ensure_ffmpeg()
    completed = run_capture(["ffmpeg", "-hide_banner", "-list_devices", "true", "-f", "dshow", "-i", "dummy"])
    devices: list[str] = []
    pattern = re.compile(r'"(?P<name>.+?)"\s+\(audio\)')
    for line in completed.stdout.splitlines():
        match = pattern.search(line)
        if match:
            devices.append(match.group("name"))
    return devices


def print_devices() -> None:
    devices = list_audio_devices()
    if not devices:
        print("沒有偵測到 Windows 錄音裝置。")
        return
    print("可用錄音裝置：")
    for index, name in enumerate(devices, start=1):
        print(f"{index:>2}. {name}")


def resolve_device(device: str | None, prefer: str | None, require_prefer: bool = False) -> str:
    devices = list_audio_devices()
    if not devices:
        raise VoiceInputError("沒有偵測到任何錄音裝置。請確認 DJI 接收端已插入電腦並開機。")

    if device:
        if device.isdigit():
            number = int(device)
            if 1 <= number <= len(devices):
                return devices[number - 1]
            raise VoiceInputError(f"裝置編號超出範圍：{device}")

        lowered = device.lower()
        exact = [name for name in devices if name.lower() == lowered]
        if exact:
            return exact[0]
        partial = [name for name in devices if lowered in name.lower()]
        if len(partial) == 1:
            return partial[0]
        if len(partial) > 1:
            raise VoiceInputError("找到多個符合的裝置，請改用完整名稱或編號：\n" + "\n".join(partial))
        raise VoiceInputError(f"找不到指定裝置：{device}")

    if prefer:
        lowered = prefer.lower()
        partial = [name for name in devices if lowered in name.lower()]
        if partial:
            return partial[0]
        if require_prefer:
            raise VoiceInputError(
                f"找不到包含「{prefer}」的錄音裝置。請先插上 DJI 接收端，或用 devices 指令查看實際名稱後指定 --device。"
            )

    for keyword in ("dji", "mic", "microphone", "麥克風", "usb"):
        partial = [name for name in devices if keyword in name.lower()]
        if partial:
            return partial[0]

    return devices[0]


def add_audio_filter(command: list[str], audio_filter: str | None) -> list[str]:
    if audio_filter:
        command.extend(["-af", audio_filter])
    return command


def record_fixed(device: str, seconds: float, output_path: Path, audio_filter: str | None) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        "ffmpeg",
        "-y",
        "-hide_banner",
        "-loglevel",
        "warning",
        "-f",
        "dshow",
        "-i",
        f"audio={device}",
        "-ac",
        "1",
        "-ar",
        "16000",
    ]
    add_audio_filter(command, audio_filter)
    command.extend([
        "-t",
        str(seconds),
        str(output_path),
    ])
    print(f"錄音 {seconds:g} 秒：{device}")
    completed = run_capture(command)
    if completed.returncode != 0:
        raise VoiceInputError("錄音失敗：\n" + completed.stdout.strip())


def command_record(args: argparse.Namespace) -> int:
    device = resolve_device(args.device, args.prefer, args.require_prefer)
    output = Path(args.output).expanduser().resolve()
    record_fixed(device, args.seconds, output, None if args.raw_audio else args.audio_filter)
    print(f"已錄音：{output}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="把 DJI 無線麥克風變成 Windows 語音輸入器。")
    subparsers = parser.add_subparsers(dest="command", required=True)

    devices = subparsers.add_parser("devices", help="列出 Windows 可用錄音裝置")
    devices.set_defaults(func=lambda args: (print_devices(), 0)[1])

    record = subparsers.add_parser("record", help="只錄音成 WAV，用來測試麥克風")
    record.add_argument("--device", help="裝置完整名稱、部分名稱或編號")
    record.add_argument("--prefer", default="DJI", help="未指定 device 時優先匹配的文字，預設 DJI")
    record.add_argument("--require-prefer", action="store_true", help="找不到 prefer 文字時直接報錯")
    record.add_argument("--seconds", type=float, default=5.0, help="錄音秒數")
    record.add_argument("--output", default="test_recording.wav", help="輸出 WAV 路徑")
    record.add_argument("--audio-filter", default=DEFAULT_AUDIO_FILTER, help="ffmpeg 音訊濾鏡；預設會強化語音音量")
    record.add_argument("--raw-audio", action="store_true", help="停用語音增強，保留原始錄音")
    record.set_defaults(func=command_record)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except KeyboardInterrupt:
        print("\n已離開。")
        return 130
    except VoiceInputError as exc:
        print(f"錯誤：{exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
