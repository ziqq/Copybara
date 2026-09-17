# Copybara — Roadmap

Milestones are ordered; each builds on the previous. Scope is intentionally
small — Copybara does one thing well.

## M0 — Foundations (project skeleton)
- [ ] Xcode project: menu-bar agent (`LSUIElement`), macOS 12 deployment target.
- [ ] SPM dependencies: `KeyboardShortcuts`, `Defaults`.
- [ ] Folder structure per `docs/ARCHITECTURE.md`.
- [ ] `CoreDataStack` + `Copybara.xcdatamodeld` (`ClipEntity`).
- [ ] `AppDelegate` wiring; activation policy toggle.

## M1 — MVP (v0.1): text history, keyboard paste
- [ ] `ClipboardMonitor` — changeCount polling for text.
- [ ] `PasteboardFilter` — drop concealed/transient/auto-generated types.
- [ ] `HistoryStore` — insert/dedup/size-cap/fetch.
- [ ] `StatusItemController` + `PopupWindow` (NSPanel).
- [ ] `PopupView` / `PopupOO` — search field, results list, selection.
- [ ] `FuzzyMatcher` — instant filtering.
- [ ] `HotKeyManager` — default ⌘⇧C toggles the popup.
- [ ] `Paster` — set pasteboard + synthesize ⌘V (Accessibility prompt).
- [ ] Clear history.
- [ ] Launch at login (`SMAppService` 13+, fallback on 12).
- [ ] Unit tests: `FuzzyMatcher`, `PasteboardFilter`, `HistoryStore`.

**Definition of done:** install, grant Accessibility once, then recall & paste any
recent text clip entirely from the keyboard; survives reboot via launch-at-login.

## M2 — v0.2: parity with Maccy
- [ ] Pin favorites (excluded from size-cap trimming).
- [ ] Images, RTF, and file references.
- [ ] App blocklist + finer privacy controls.
- [ ] Hover preview.
- [ ] Settings screen (`SettingsView`/`SettingsOO`): history size, hotkey,
      paste behavior, "Show icon in: Menu bar / Dock / Both".

## M3 — Polish & release
- [ ] App icon + capybara mascot artwork.
- [ ] Onboarding for the Accessibility permission.
- [ ] Sparkle auto-update + notarized DMG.
- [ ] README screenshots / demo GIF.

## Later (optional, opt-in)
- [ ] Snippets/templates.
- [ ] Multiple paste formats (plain vs rich).
- [ ] Configurable ignore rules per app.

## Explicitly out of scope
- Cloud sync across devices.
- Cross-platform (Windows/Linux).
- Anything that reads other apps' content beyond the clipboard.
