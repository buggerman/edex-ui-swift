# Security Policy

## Supported Versions

Only the latest commit on `main` receives security fixes. There are no versioned releases at this time.

| Version | Supported |
|---|---|
| `main` (latest) | ✅ |

## Scope

eDEX-UI Swift is a local desktop application. It does not expose any network services, does not accept inbound connections, and does not handle untrusted remote data beyond:

- **IP geolocation** — a single outbound request to `ip-api.com` to display your public IP and location.
- **Latency check** — a HEAD request to `1.1.1.1` to measure ping.
- **Terminal PTY** — a local pseudo-terminal running your default shell (`/bin/zsh`). The terminal emulator does not sanitize shell output; malicious terminal escape sequences from a remote host (e.g. via SSH) could affect the display.

The app runs **without the macOS sandbox** by design — sandboxing would block PTY creation, `ps`, `getifaddrs`, and FSEvents. Do not run this app with elevated privileges.

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Report vulnerabilities privately via [GitHub Security Advisories](https://github.com/buggerman/edex-ui-swift/security/advisories/new).

Include:
- A description of the vulnerability and its potential impact
- Steps to reproduce
- macOS version and chip (e.g. M3 Pro, macOS 14.4)

You can expect an acknowledgement within **7 days** and a resolution or status update within **30 days**.
