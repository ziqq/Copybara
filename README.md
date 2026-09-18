<div align="center">

# 🐹 Copybara

**A fast, keyboard-first, privacy-respecting clipboard manager for macOS.**

*Like a capybara that quietly keeps everything you copy — calm, friendly, always there.*

[![CI](https://github.com/ziqq/Copybara/actions/workflows/ci.yml/badge.svg)](https://github.com/ziqq/Copybara/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/ziqq/Copybara/branch/main/graph/badge.svg)](https://codecov.io/gh/ziqq/Copybara)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/macOS-12%2B-black?logo=apple)

<br>

<img src="docs/images/popup.png" alt="Copybara search popup" width="760">

</div>

---

Copybara lives in your menu bar and remembers your clipboard history. Hit a global
hotkey, type a few letters, press <kbd>Return</kbd> — it pastes straight into the app
you were working in. Everything stays local. Nothing goes to the cloud.

It's an independent, native clipboard manager built from scratch in Swift/SwiftUI.

## Why

Copying things is constant. Losing what you copied ten seconds ago is annoying.
A clipboard manager should be **instant, invisible, and trustworthy** — and do
exactly one job well. That is the entire scope of Copybara.

## Principles

- **Keyboard-first** — the mouse is optional; everything works from the keyboard.
- **Local-only** — history never leaves the device; no accounts, no sync, no telemetry.
- **Lightweight** — a menu-bar agent that stays out of the way and sips resources.
- **Instant** — open and search with zero perceptible delay.

## Features

### MVP (v0.1)
- Background clipboard monitoring (text).
- Local history with a configurable size limit.
- Menu-bar icon + global hotkey to open (default <kbd>⌘</kbd><kbd>⇧</kbd><kbd>C</kbd>).
- Instant fuzzy search over history.
- Arrow-key navigation, <kbd>Return</kbd> to paste into the active app.
- Clear history; launch at login.

### v0.2 — power-user features
- Pin favorite items, delete individual clips, quick-paste with <kbd>⌘1</kbd>–<kbd>9</kbd>.
- Images, rich text (RTF), and file references; paste-without-formatting (<kbd>⌥⇧↩</kbd>).
- Ignore passwords (`ConcealedType`), transient types, and an app blocklist.
- Side preview panel on hover / <kbd>→</kbd>, with source app, time, and copy count.
- Search modes (fuzzy / exact / regex) and sorting.
- **Liquid Glass** appearance on macOS 26 (toggleable), with a "Show icon in:
  Menu bar / Dock / Both" and popup-position setting.

### Later (optional)
- Snippets/templates, auto-update (Sparkle), multiple paste formats.

## Requirements

- **macOS 12.0 (Monterey) or later.** Newer-OS APIs are adopted behind
  `if #available` checks so the app runs everywhere down to 12.
- **Accessibility permission** — required only so Copybara can paste into the
  frontmost app (it synthesizes <kbd>⌘</kbd><kbd>V</kbd>). Copybara never reads the
  screen or other apps' contents.

## Tech stack

| Concern | Choice |
|---|---|
| Language / UI | Swift + SwiftUI (AppKit for the menu bar & window) |
| App type | Menu-bar agent (`LSUIElement`), optional Dock icon |
| Architecture | **VOODO** (View · Observable Object · Data Object) for screens + a service layer |
| Persistence | Core Data (baseline for macOS 12+) |
| Clipboard | `NSPasteboard` change-count polling |
| Global hotkey | [`KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) |
| Settings | [`Defaults`](https://github.com/sindresorhus/Defaults) |
| Paste | `CGEvent` synthesized <kbd>⌘</kbd><kbd>V</kbd> |
| Launch at login | `SMAppService` (13+) with a login-item fallback on 12 |

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full design and
[`docs/CONCEPT.md`](docs/CONCEPT.md) for the product concept.

## Documentation

- [Concept](docs/CONCEPT.md) — what Copybara is and why.
- [Architecture](docs/ARCHITECTURE.md) — modules, data flow, conventions.
- [Roadmap](docs/ROADMAP.md) — milestones and scope.
- [Release](docs/RELEASE.md) — signing, notarization, appcast.
- [Monetization](docs/MONETIZATION.md) — funding strategy (planning).

## Building from source

Copybara uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the
Xcode project from [`project.yml`](project.yml) (the `.xcodeproj` is not checked in).

```bash
brew install xcodegen
git clone https://github.com/ziqq/Copybara.git
cd Copybara
xcodegen generate
open Copybara.xcodeproj
```

Then pick your signing team in *Signing & Capabilities* and run. On first paste,
grant Accessibility in *System Settings → Privacy & Security → Accessibility*.

### No paid Apple Developer account?

You don't need one to use Copybara yourself. Sign in Xcode with a **free Apple ID**
(Personal Team) and run — it's signed locally and runs on your Mac indefinitely
(the iOS 7-day limit doesn't apply to Mac apps you build locally).

To build a DMG without signing, run `./scripts/build_dmg.sh` (no `DEVELOPMENT_TEAM`).
It runs on your Mac; on **other** Macs, Gatekeeper blocks unsigned apps — open via
right-click → *Open*, or clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/Copybara.app
```

A paid account ($99/yr) is only needed to ship a **signed, notarized** DMG that
installs cleanly for others — see [`docs/RELEASE.md`](docs/RELEASE.md).

Run the tests from the command line:

```bash
xcodebuild -project Copybara.xcodeproj -scheme Copybara -destination 'platform=macOS' \
  -enableCodeCoverage YES test
```

## Coverage

CI runs the unit tests with coverage and uploads it to
[Codecov](https://codecov.io/gh/ziqq/Copybara) on every push.

<a href="https://codecov.io/gh/ziqq/Copybara">
  <img src="https://codecov.io/gh/ziqq/Copybara/branch/main/graphs/sunburst.svg" alt="Coverage sunburst" width="220">
</a>

## Status

✅ v0.2 feature-complete — capture (text/image/RTF/files), keyboard-driven search
(fuzzy/exact/regex), paste (with a plain-text option), pin, delete, per-item
quick-paste, privacy filters + app blocklist, and clear commands. Remaining work
is polish and release (icon, onboarding, auto-update). See [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Contributing

Contributions are welcome — see [`CONTRIBUTING.md`](CONTRIBUTING.md) and the
[changelog](CHANGELOG.md).

## Support

If Copybara is useful to you, consider supporting its development:

- [GitHub Sponsors](https://github.com/sponsors/ziqq)
- Buy Me a Coffee — _TODO: add link_
- Boosty — _TODO: add link_

See [`docs/MONETIZATION.md`](docs/MONETIZATION.md) for the funding strategy.

## License

[MIT](LICENSE) © 2026 Anton Ustinoff
