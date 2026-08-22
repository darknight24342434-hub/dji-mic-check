# dji-mic-check

Local Windows tooling to use a DJI wireless lapel microphone receiver as an ordinary recording device: list capture devices, measure the signal level, and force the receiver to act as input only.

Chinese documentation: [README.zh-TW.md](README.zh-TW.md) — it also covers hardware wiring and troubleshooting in more depth.

## What it does

Connect a DJI wireless mic receiver to a Windows PC and it shows up as a normal recording endpoint. These scripts handle the three things that are awkward to do by hand:

- **Enumerate recording devices** — ask ffmpeg's DirectShow backend which capture devices Windows currently exposes, numbered so you can refer to one without typing its full name.
- **Measure the signal** — record a fixed-length WAV from a chosen device and run ffmpeg's `volumedetect` on it, so you get a `max_volume` figure in dB instead of guessing whether audio is arriving.
- **Force input-only** — plug in the receiver and Windows may hand playback over to the receiver's headphone jack. A PowerShell script sets the receiver as the default *recording* endpoint for all three roles (Console, Multimedia, Communications) while leaving the playback default untouched.

Everything runs locally. The tools shell out to ffmpeg and to Windows' own audio APIs. No network calls, no API keys, no accounts.

Speech-to-text is deliberately **not** part of this repo. Pair it with a local offline transcriber (faster-whisper, for example). Earlier cloud-transcription subcommands were removed.

## Requirements

- Windows (the DirectShow capture backend and the audio-endpoint COM interfaces are Windows-only)
- Python 3.9 or newer — only the standard library is used, so there is nothing to `pip install`
- `ffmpeg` on `PATH` (`ffmpeg -version` must work)
- PowerShell 5.1 or newer for the `.ps1` scripts
- A DJI wireless microphone receiver, paired with its transmitter

## Install

```powershell
git clone https://github.com/<your-account>/dji-mic-check.git
cd dji-mic-check
```

That is the whole install. Confirm ffmpeg is reachable:

```powershell
ffmpeg -version
```

## Configuration

There are no environment variables and no config file. Behaviour is controlled entirely by command-line arguments.

`voice_input.py devices` takes no arguments. `voice_input.py record` accepts:

| Option | Default | Meaning |
|---|---|---|
| `--device` | (auto) | Device full name, a case-insensitive substring, or the number shown by `devices`. If omitted, selection falls back to `--prefer`, then to keywords like `dji` / `mic` / `usb`, then to the first device. |
| `--prefer` | `DJI` | Substring preferred when `--device` is not given. |
| `--require-prefer` | off | Fail with an error instead of falling back when nothing matches `--prefer`. |
| `--seconds` | `5.0` | Recording length in seconds. |
| `--output` | `test_recording.wav` | Output WAV path. Parent directories are created. |
| `--audio-filter` | `highpass=f=80,lowpass=f=7800,dynaudnorm=f=150:g=8:p=0.90,alimiter=limit=0.95` | ffmpeg audio filter chain applied while recording; the default boosts and levels speech. |
| `--raw-audio` | off | Disable the filter chain and record unprocessed audio. |

`Set-DJI-InputOnly.ps1` takes one parameter, `-Match` (default `"Wireless Microphone RX"`), the substring used to find the target recording device.

## Usage

List the recording devices Windows currently exposes:

```powershell
python .\voice_input.py devices
```

Or via the wrappers — `.\List-Devices.ps1`, or `List-Devices.cmd` if PowerShell script execution is blocked.

Record five seconds and print the level, which is what `Test-DJI-Mic.ps1` does:

```powershell
.\Test-DJI-Mic.ps1
```

It runs the equivalent of:

```powershell
python .\voice_input.py record --device "Wireless Microphone RX" --seconds 5 --output dji_test.wav
ffmpeg -hide_banner -i dji_test.wav -af volumedetect -f null NUL
```

Record from a specific device, by substring or by the number from `devices`:

```powershell
python .\voice_input.py record --device DJI --seconds 5 --output test.wav
python .\voice_input.py record --device 2 --seconds 5 --output test.wav
```

If a device name contains non-ASCII characters, prefer its number or a plain-ASCII fragment to avoid command-line encoding problems.

Make the receiver the recording default without touching playback:

```powershell
.\Set-DJI-InputOnly.ps1
.\Set-DJI-InputOnly.ps1 -Match "High Definition Audio"
```

The script prints the current playback default, the current recording default, and every active recording device before it switches, then prints the new recording default and confirms playback was left alone.

## Output

`record` writes a mono 16 kHz WAV to `--output`. Reading the level from ffmpeg's `volumedetect` output:

| `max_volume` | Interpretation |
|---|---|
| −6 to −20 dB | Healthy, usable |
| below −35 dB | Too quiet; recognition will be poor. Raise the receiver's output gain or the Windows input level |
| near 0 dB | Too loud; clipping |

The single most useful check is comparing a take **while speaking** against one **in silence**. If the two readings are only a few dB apart, no signal is arriving at all — that is a broken wireless link, not a volume problem, and no amount of adjusting on the PC side will fix it.

## Troubleshooting order

Always confirm the wireless link before touching anything on the PC. When the link is down, PC-side measurements only show noise, and the numbers look exactly like "the volume is too low", which sends you off adjusting the wrong thing.

1. Look at the receiver's screen: is the transmitter shown, and does the level meter move when you speak? If not, fix pairing / unmute the transmitter / charge it.
2. Only then check the PC: is the cable in the microphone jack rather than the headphone jack, is the Windows input level up and unmuted, is the cable seated properly.
3. If audio arrives but is quiet, raise the receiver's output gain or the Windows input level and aim for −6 to −20 dB.

## Limitations

- **Windows only.** Device enumeration uses ffmpeg's `dshow` input, and `Set-DJI-InputOnly.ps1` calls the undocumented `IPolicyConfig` COM interface. Neither works on macOS or Linux.
- **`IPolicyConfig` is undocumented.** It is the standard way to change the default audio endpoint from a script and works across current Windows versions, but Microsoft does not support it and a future Windows release could break it.
- **No transcription.** By design. This repo only gets audio in and verifies it.
- **Device names are matched by substring**, so an ambiguous fragment matching several devices raises an error asking for a full name or number. Names with non-ASCII characters can be awkward to pass on the command line.
- **The 3.5 mm analogue path is what was actually verified.** Feeding the receiver's 3.5 mm output into the PC's microphone jack works. Connecting the receiver over USB Type-C so it appears directly as a USB audio device is plausible — a device named `Wireless Microphone RX` was detected that way once — but it failed on another machine for reasons that were never diagnosed. Treat the USB route as unverified.
- **No tests, no packaging.** These are single-purpose scripts run by hand.

## License

MIT — see [LICENSE](LICENSE).
