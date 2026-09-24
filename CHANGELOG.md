# Changelog


## Planned
- [ ] Multiple paste formats (plain vs rich) selection.
- [ ] Configurable per-app ignore/allow rules.
- [ ] Diagnostics: on-device crash/hang reporting via MetricKit, opt-in log export
      (no third-party telemetry).
- [ ] Signed, notarized DMG (optional; needs a paid Apple Developer account).


## Unreleased


## 0.1.0 — 2026-09-24
- **FIXED**: Paste went into Copybara itself instead of the app you were in —
  the target app is now kept for the paste and gets focus back reliably.
- **FIXED**: Paste into Chromium/Electron apps (Claude, Discord, VS Code, Telegram).
- **FIXED**: The Settings window didn't open on macOS 14+; changes to history
  size, retention and "Ignore all copies" now apply immediately, the
  Accessibility status refreshes, and "Launch at login" shows the real state.
- **ADDED**: Delete single clips with the mouse — a ✕ on hover and a right-click
  menu (Paste, Paste as Plain Text, Copy, Pin/Unpin, Delete). Deleting a snippet
  now removes it.
- **CHANGED**: The popup shows your whole history (it was capped at 200 clips).
- **CHANGED**: Stays fast with very large histories (measured at 100k clips):
  opens at once, search runs in the background and narrows as you type,
  delete/pin no longer reload the list, and rows render page by page
  (`⌘↓` jumps to the end of the loaded rows).
- **CHANGED**: Image thumbnails are downsampled and cached; image, RTF and file
  payloads load only when a clip is pasted, copied or previewed.
- **CHANGED**: The Accessibility warning no longer hides the footer actions, and
  only the system permission prompt is shown (no second dialog on top).
- **FIXED**: Square corners showed around the Liquid Glass popup.
- **CHANGED**: The DMG is `Copybara-<version>.dmg`, ad-hoc signed as
  `dev.ustinoff.copybara`, and checked after packaging; local builds can sign
  with your team from `Config/Local.xcconfig` so Accessibility survives rebuilds.

- **ADDED**: Snippet placeholders — `${date}`, `${time}`, `${datetime}`,
  `${clipboard}`, `${uuid}`, expanded at paste time; multi-line snippet editor.
- **ADDED**: Copy without pasting — `⌘C` in the popup (and the ⌘K menu) puts the
  selected item on the clipboard and closes.
- **ADDED**: Snippets — reusable text templates managed in Settings, always shown
  in the popup and pasted like any clip.
- **ADDED**: Filter results by content type (All / Text / Images / Files) — cycle
  with ⌘L; the active scope shows as a pill in the search field.
- **ADDED**: Transform-on-paste from the ⌘K menu — Paste Trimmed / lowercased /
  UPPERCASED for text clips.
- **ADDED**: History retention — auto-remove non-pinned clips older than 7/30/90 days
  (or keep forever), configurable in Settings.
- **ADDED**: On-demand update check via GitHub Releases (menu → *Check for Updates…*)
  and a tag-based release workflow that builds and publishes the DMG.
- **ADDED**: ⌘1–9 quick-paste hints on the first nine rows.
- **ADDED**: Raycast-style footer with an actions menu (`⌘K`) — Paste, Paste as
  Plain Text, Pin/Unpin, Delete, and Clear History, each with its shortcut.
- **CHANGED**: Default open shortcut is now `⌘⇧V` (was `⌘⇧C`), matching Windows' Win+V.
- **FIXED**: Arrow keys stopped navigating the list (they carry function/numeric-pad
  modifier flags); selection and `⌘↑`/`⌘↓` jumps work again alongside search focus.
- **ADDED**: Draggable popup with a Raycast-style default position (centered, upper
  third); drag it anywhere to reposition — it snaps to a grid and reopens where you
  left it ("Last position" mode).
- **ADDED**: Jump to the first / last item with `⌘↑` / `⌘↓`.
- **CHANGED**: Default popup position is now "Last position" (was the menu-bar icon).
- **ADDED**: Menu-bar agent that records clipboard history locally (text, images,
  RTF, and file references) with SHA-256 de-duplication and a configurable size cap.
- **ADDED**: Keyboard-driven search popup — global hotkey `⌘⇧V`, instant search
  (fuzzy / exact / regex), arrow navigation, paste on `↩`, paste-without-formatting
  (`⌥⇧↩`), and quick-paste `⌘1`–`⌘9`.
- **ADDED**: Per-item actions — pin (`⌥P`), delete (`⌥⌫`), clear unpinned (`⌥⌘⌫`),
  and clear all including pins (`⇧⌥⌘⌫`).
- **ADDED**: Side preview panel on hover or `→`, showing the full content, source
  app, timestamp, and copy count.
- **ADDED**: Privacy controls — ignores concealed/transient pasteboard types, an
  app blocklist, and ignore-next (`⌥⇧`-click) / ignore-all (`⌥`-click) from the
  menu-bar icon.
- **ADDED**: Settings — history size, sort order (last / first / most copied),
  search mode, icon visibility (menu bar / Dock / both), popup position (icon /
  cursor / center), launch at login, and a Liquid Glass toggle.
- **ADDED**: Liquid Glass appearance on macOS 26 (toggleable), with a vibrant
  material fallback on older systems.
- **ADDED**: First-run onboarding for the Accessibility permission and a capybara
  app icon.
- **ADDED**: Continuous integration (build, tests, and coverage upload to Codecov),
  the MIT license, and documentation (concept, architecture, roadmap, release,
  monetization).
- **CHANGED**: Global shortcut now fires on key-down for a reliable first press;
  the search field is focused as soon as the popup opens.
- **FIXED**: Popup could crash or jump due to layout recursion while resizing the
  window and preview panel; resizes are now deferred off the layout pass.
- **FIXED**: Popup could open near the Dock when the menu-bar icon was hidden;
  positioning now validates the anchor and falls back to the cursor.
- **FIXED**: Paste could land in the wrong app; Copybara now waits for the target
  app to regain focus before pasting, and clearly surfaces a missing Accessibility
  permission instead of failing silently.
