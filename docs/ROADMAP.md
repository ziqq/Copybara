# Copybara — Roadmap

Milestones are ordered; each builds on the previous. Scope is intentionally
small — Copybara does one thing well.

## M0 — Foundations (project skeleton) ✅
- [x] XcodeGen project (`project.yml`): menu-bar agent (`LSUIElement`), macOS 12 target.
- [x] Folder structure per `docs/ARCHITECTURE.md`.
- [x] `CoreDataStack` + `Copybara.xcdatamodeld` (`ClipEntity`).
- [x] `AppDelegate` wiring; activation-policy toggle from icon-visibility.
- [x] Builds clean; `FuzzyMatcher` unit tests pass.
- [ ] SPM dependencies (`KeyboardShortcuts`, `Defaults`) — deferred to M1, where
      they are first used, so they can be pinned to macOS-12-compatible versions.

> Note: some M1 services landed early in M0 because they are self-contained —
> `ClipboardMonitor`, `PasteboardFilter`, and `HistoryStore` are already wired, so
> the app captures text history in the background today. The menu shows the live
> item count and can clear history.

## M1 — MVP (v0.1): text history, keyboard paste
- [x] `ClipboardMonitor` — changeCount polling for text. *(landed in M0)*
- [x] `PasteboardFilter` — drop concealed/transient/auto-generated types. *(M0)*
- [x] `HistoryStore` — insert/dedup/size-cap/fetch. *(M0)*
- [x] `FuzzyMatcher` — instant filtering. *(M0)*
- [x] `PopupView` / `PopupOO` — search field, results list, live filter.
      *(rendered in M0; not yet hosted or keyboard-driven)*
- [ ] Host `PopupView` in `PopupWindow` (NSPanel); position under the status item.
- [ ] Keyboard navigation (↑/↓), paste-on-Return, Esc-to-dismiss.
- [ ] `HotKeyManager` — default ⌘⇧C toggles the popup (via `KeyboardShortcuts`).
- [ ] `Paster` — set pasteboard + synthesize ⌘V, with the Accessibility prompt.
      *(paste logic written in M0; needs to be wired to the popup)*
- [ ] Launch at login (`SMAppService` 13+, fallback on 12).
- [ ] Unit tests: `PasteboardFilter`, `HistoryStore` (in-memory store).

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
