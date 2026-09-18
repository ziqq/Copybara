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

## M1 — MVP (v0.1): text history, keyboard paste ✅
- [x] `ClipboardMonitor` — changeCount polling for text. *(landed in M0)*
- [x] `PasteboardFilter` — drop concealed/transient/auto-generated types. *(M0)*
- [x] `HistoryStore` — insert/dedup/size-cap/fetch. *(M0)*
- [x] `FuzzyMatcher` — instant filtering. *(M0)*
- [x] `PopupView` / `PopupOO` — search field, results list, live filter.
- [x] Host `PopupView` in `PopupWindow` (NSPanel), anchored under the status item.
- [x] Keyboard navigation (↑/↓), paste-on-Return, Esc-to-dismiss (`PopupController`).
- [x] `HotKeyManager` — default ⌘⇧C toggles the popup (via `KeyboardShortcuts`),
      rebindable in Settings.
- [x] `Paster` — stage + synthesize ⌘V, re-activating the previous app, with the
      Accessibility prompt.
- [x] Launch at login (`SMAppService` 13+; no-op with notice on 12).
- [x] Unit tests: `PasteboardFilter`, `HistoryStore` (in-memory store).

**Definition of done:** install, grant Accessibility once, then recall & paste any
recent text clip entirely from the keyboard; survives reboot via launch-at-login.

> ⚠️ The interactive paste loop (⌘⇧C → search → Return → paste) is implemented
> and compiles, but end-to-end behavior depends on the Accessibility grant and
> must be verified by running the app. Remaining M1 polish: adopt the `Defaults`
> package, and tune popup positioning/animation.

## M2 — v0.2: parity with Maccy
- [x] Per-item keyboard actions: pin/unpin (⌥P), delete (⌥⌫), quick-paste ⌘1–9.
- [x] Pin favorites (excluded from size-cap trimming; sorted to the top).
- [x] Popup position preference (menu bar icon / cursor / center).
- [ ] Paste without formatting (⌥⇧Return) — needs RTF support first.
- [x] Row metadata: source-app icon, timestamp, copy count, match highlight.
- [x] Hover preview — tooltip with full content, source app, time, copy count.
- [x] Clear unpinned (⌥⌘⌫) vs clear all incl. pins (⇧⌥⌘⌫).
- [ ] Images, RTF, and file references.
- [ ] App blocklist + finer privacy controls ("ignore next / all copies").
- [x] Settings screen (`SettingsView`/`SettingsOO`): history size, hotkey,
      icon visibility, popup position, launch at login.

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
