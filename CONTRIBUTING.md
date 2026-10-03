<!--
Copyright (c) 2026 Anton Ustinoff. All rights reserved.
Use and redistribution are subject to LICENSE.
-->

# Contributing to Copybara

Thanks for your interest! Copybara is a small, focused, native macOS clipboard
manager. Contributions that keep it lean, fast, and privacy-respecting are very
welcome.

## Principles

Please keep changes aligned with the project's non-negotiables:

- **Local-only.** No network calls, no telemetry, no accounts. Clipboard data
  never leaves the device.
- **Keyboard-first and fast.** The core loop (open → search → paste) must stay
  instant.
- **Small surface.** Copybara does one thing well; resist scope creep.

## Prerequisites

- macOS 12+ and Xcode 16+ (the project uses the macOS 26 SDK; features are gated
  with `if #available`).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.

## Getting started

```bash
git clone https://github.com/ziqq/Copybara.git
cd Copybara
xcodegen generate      # the .xcodeproj is generated, not committed
open Copybara.xcodeproj
```

Sign with your free Apple ID (Personal Team) to run locally, and grant
Accessibility on first paste. See the README for details.

## Running tests

```bash
xcodebuild -project Copybara.xcodeproj -scheme Copybara \
  -destination 'platform=macOS' -enableCodeCoverage YES test
```

CI runs the same tests with coverage on every push and PR. Please add or update
tests for behavior changes — pure logic (`ClipSearch`, `FuzzyMatcher`,
`PasteboardFilter`, `HistoryStore`) is covered with unit tests.

## Architecture & conventions

- Read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) first.
- Screens follow **VOODO**: `XxxView` (SwiftUI), `XxxOO` (`ObservableObject`),
  `XxxDO` (value type). Services are plain nouns (`ClipboardMonitor`, `Paster`).
- Do **not** call newer-OS APIs unconditionally — gate with `@available` /
  `if #available` and provide a macOS 12 path.
- Code, comments, and docs are written in **English**.
- Never commit the generated `Copybara.xcodeproj` (it's gitignored).

## Commits & pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org):
  `feat: …`, `fix: …`, `docs: …`, `chore: …`, `refactor: …`, `test: …`.
- Keep changes scoped and the working tree focused.
- Update [`CHANGELOG.md`](CHANGELOG.md) (and [`CHANGELOG.ru.md`](CHANGELOG.ru.md))
  under **Unreleased** for user-visible changes.
- Make sure `xcodebuild … test` is green before opening a PR.

## Reporting issues

Open a GitHub issue with steps to reproduce, your macOS version, and — for
crashes — the report from `~/Library/Logs/DiagnosticReports/Copybara-*.ips`.
Never paste sensitive clipboard contents into an issue.
