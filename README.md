# eDEX-UI Swift

A native Swift/SwiftUI reimplementation of [eDEX-UI](https://github.com/GitSquared/edex-ui) for macOS, built exclusively for Apple Silicon.

No Electron. No web renderer. No JavaScript runtime. Pure SwiftUI backed by Metal, Mach kernel APIs, and FSEvents — running lean on Apple Silicon.

---

## Screenshots

> Coming soon.

---

## Features

- **Full terminal emulator** — xterm-256color PTY sessions via [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm), Metal-rendered. Multi-tab with skewed tab bar, inline tab rename, and keyboard shortcuts.
- **Real-time system monitoring** — per-core CPU usage (Mach `host_processor_info`), memory breakdown (wired / active / compressed / free) via `vm_statistics64`, GPU VRAM via Metal, top processes via `ps`.
- **Network panel** — live upload/download rates via `getifaddrs` byte-counter deltas, online/offline state via `NWPathMonitor`, IP geolocation, Cloudflare DNS latency.
- **Filesystem browser** — FSEvents-backed tile grid that tracks the active terminal's CWD. Click a directory to `cd` in the terminal; click a file to open in its default app.
- **Five themes** — TRON, APOLLO, BLADE, CYBORG, INTERSTELLAR. All color values ported 1:1 from the original.
- **Augmented-UI aesthetic** — the original's signature corner-clip borders recreated as a native SwiftUI `Shape`.
- **Fullscreen by default** — launches full-screen with hidden title bar, just like the original.

---

## Requirements

| | Minimum |
|---|---|
| macOS | 14.0 (Sonoma) |
| Architecture | Apple Silicon (arm64) only |
| Xcode | 15.0+ |
| Swift | 5.10+ |

x86 Macs are not supported and there are no plans to add support.

---

## Building

**With Xcode (recommended):**

```
open EdexUI/Package.swift
```

Select the `EdexUI` scheme, choose **My Mac** as the run destination, and press ⌘R.

**With Swift Package Manager:**

```bash
cd EdexUI
swift build -c release
swift run
```

The release binary lands at `.build/release/EdexUI`.

---

## Known Limitations

| Feature | Status |
|---|---|
| CPU temperature | Not available — no public API on Apple Silicon |
| GPU utilization % | Not available — no public API on Apple Silicon (VRAM usage shown instead) |
| GPU temperature | Not available — no public API on Apple Silicon |
| Cursor style per theme | SwiftTerm 1.12 exposes cursor style as `internal`; defaults to steady block |

These are platform constraints, not bugs.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘T` | New terminal tab |
| `⌘W` | Close current tab |
| `⌃Tab` | Next tab |
| `⌃⇧Tab` | Previous tab |
| Double-click tab | Rename tab |

---

## Architecture

```
Sources/EdexUI/
├── EdexUIApp.swift           App entry point, window configuration
├── AppDelegate.swift         Fullscreen on launch, title bar hiding
├── Models/                   Data models (CPUData, MemoryInfo, ProcInfo, …)
├── Services/
│   ├── SystemMonitor.swift   Mach APIs: CPU, memory, GPU, processes, disks
│   ├── NetworkMonitor.swift  getifaddrs traffic rates + NWPathMonitor
│   ├── IPInfoService.swift   ip-api.com geolocation
│   └── FileWatcher.swift     FSEvents directory watcher + lsof CWD tracking
├── Theme/                    Five themes + EnvironmentKey injection
├── Views/
│   ├── Shared/               AugmentedPanel shape, real-time Canvas charts
│   ├── System/               Clock, SysInfo, CPU/GPU charts, Memory grid, Processes
│   ├── Terminal/             SwiftTerm NSViewRepresentable, tab bar
│   ├── Network/              Status, traffic chart, disk usage
│   ├── FileSystem/           Adaptive tile grid
│   └── Settings/             Theme picker, hidden files, shortcuts
└── Utilities/
    └── Extensions.swift      Color(hex:), byte formatter, Font helpers
```

---

## Dependencies

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) — terminal emulator (MIT)

Managed via Swift Package Manager. No other third-party dependencies.

---

## Credits

Inspired by [eDEX-UI](https://github.com/GitSquared/edex-ui) by [@GitSquared](https://github.com/GitSquared).

---

## License

MIT — see [LICENSE](LICENSE).
