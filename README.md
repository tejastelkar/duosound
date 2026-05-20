# DuoSound

A native macOS menu bar app that lets you play audio on two or more output devices simultaneously — with one click.

No drivers. No SoundFlower. No BlackHole. Pure CoreAudio.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## What it does

- **Lists all connected audio output devices** — Built-in, Bluetooth, USB, AirPlay
- **Select 2 or more devices** via checkboxes
- **Play on Both** — creates a CoreAudio Multi-Output Device and sets it as system default in one click
- **Per-device volume sliders** — control each device's volume independently
- **Reset** — restores your original default output and destroys the aggregate
- **⌥⌘D global hotkey** — toggle multi-output without opening the app
- **Disconnect notifications** — native macOS banner when a device drops mid-session
- **Persists selections** between launches

## How it works

Uses `AudioHardwareCreateAggregateDevice` with `kAudioAggregateDeviceIsStackedKey = 1` — the same CoreAudio HAL API that macOS's built-in Audio MIDI Setup uses to create Multi-Output Devices. No third-party audio drivers required.

## Building

Requires macOS 13+ and Swift 5.9+ (Xcode CLI tools or full Xcode).

```bash
# Build .app + .dmg
bash build.sh
```

The built app is at `dist/DuoSound.app` and the DMG at `dist/DuoSound-1.0.dmg`.

To clear macOS quarantine on a local build:
```bash
xattr -cr dist/DuoSound.app
```

## Project structure

```
DuoSound/
├── DuoSoundApp.swift          # NSStatusItem + NSPanel, hotkey, app lifecycle
├── GlobalHotKey.swift         # Carbon RegisterEventHotKey wrapper (⌥⌘D)
├── ContentView.swift          # Main popover SwiftUI view
├── Models/
│   └── AudioDevice.swift      # Device value type (id, uid, name, transport)
├── Services/
│   └── AudioDeviceManager.swift  # CoreAudio HAL wrapper
├── State/
│   └── AppState.swift         # ObservableObject — devices, selection, aggregate
└── Views/
    ├── DeviceRowView.swift     # Device row with checkbox + volume slider
    ├── AggregateCardView.swift # Active multi-output card with audio meter
    ├── ActionBarView.swift     # Play on Both / Reset buttons
    ├── BannerView.swift        # Info/warn/error banners
    ├── PermissionGateView.swift
    ├── VisualEffectView.swift  # NSVisualEffectView bridge
    └── WindowConfigurator.swift
```

## License

MIT
