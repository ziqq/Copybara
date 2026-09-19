# Changelog


## Planned
- [ ] Snippets / templates with placeholders.
- [ ] Multiple paste formats (plain vs rich) selection.
- [ ] Configurable per-app ignore/allow rules.
- [ ] Diagnostics: on-device crash/hang reporting via MetricKit, opt-in log export
      (no third-party telemetry).
- [ ] Signed, notarized DMG (optional; needs a paid Apple Developer account).


## Unreleased
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
