<!--
Copyright (c) 2026 Anton Ustinoff. All rights reserved.
Use and redistribution are subject to LICENSE.
-->

# Changelog


## Planned
- [ ] Multiple paste formats (plain vs rich) selection.
- [ ] Configurable per-app ignore/allow rules.
- [ ] Diagnostics: on-device crash/hang reporting via MetricKit, opt-in log export
      (no third-party telemetry).
- [ ] Signed, notarized DMG (optional; needs a paid Apple Developer account).


## Unreleased
- **CHANGED**: Removed the ellipsis from Settings in all ten menu languages.
- **FIXED**: The update prompt without release notes wraps its version text in
  a compact window while Sparkle continues to download, verify, and install.


## 0.1.5 — 2026-10-06
- **FIXED**: The nonactivating history panel no longer opts into automatic
  hiding when Copybara becomes inactive while the destination app stays active.


## 0.1.4 — 2026-10-06
- **CHANGED**: Replaced the menu-bar mascot with two clean overlapping copies.
- **FIXED**: The popup reopens on the first click after a failed paste handoff
  hides the application; opening Settings also restores hidden windows.
- **FIXED**: Missing Accessibility permission reopens the permission guide even
  after onboarding. Grant Access opens the system pane if the permission is
  still missing; recovery instructions are translated into all ten languages.


## 0.1.3 — 2026-10-05
- **ADDED**: Signed in-app updates with Sparkle: download, verify, install, and
  relaunch from Check for Updates. Versions before 0.1.3 need one manual install.
- **CHANGED**: Adopted the Copybara License: personal and internal business use
  are permitted; redistribution and monetization require prior written
  permission. Added author notices to repository files.
- **CHANGED**: Redesigned the menu-bar icon with a distinctive capybara profile,
  an elongated muzzle, and clear facial cutouts at small sizes.
- **CHANGED**: Automatic paste sends the shortcut through the session keyboard
  stream after verifying the destination app, instead of posting directly to its PID.
- **FIXED**: Opening the status icon's context menu dismisses the history popup.
  Control-click opens only the menu; Show Copybara waits until the menu closes.


- **FIXED**: Pending history loads and searches no longer restore deleted rows
  or overwrite pin changes; older pages still finish loading.
- **FIXED**: Rich text preserves its formatting when plain text or a differently
  formatted copy has the same text.
- **FIXED**: First copied uses a separate persistent timestamp, with migration
  of existing history; repeated copies update only the last-copy date.
- **FIXED**: Dock-only mode hides the menu-bar icon; retention cleanup also runs
  during uninterrupted use, keeping pinned clips.
- **FIXED**: Unread clipboard changes are discarded at blocked-app transitions,
  including when the app switches before the next poll.
- **FIXED**: Background thumbnails transfer CGImage instead of NSImage, avoiding
  the macOS 14-only Sendable requirement on supported older systems.


## 0.1.2 — 2026-10-03
- **ADDED**: Localization in English, Russian, German, French, Spanish, Italian,
  Portuguese, Simplified Chinese, Japanese, and Korean, following the app language
  selected in macOS.
- **CHANGED**: The menu has no action icons; Check for Updates, Settings, and
  Clear All appear in that order. Removed the ambiguous Clear menu item.
- **FIXED**: Settings opens after the menu closes, in a bounded, scrollable window
  without measuring the entire form to determine the window size.
- **FIXED**: The search panel keeps the destination app active; paste verifies
  focus and event-posting permission and targets that app. Images offer both
  PNG and TIFF for native editors.


## 0.1.1 — 2026-09-29
- **CHANGED**: Update menu bar icon.


## 0.1.0 — 2026-09-24
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
- **CHANGED**: The DMG is `Copybara-<version>.dmg`, ad-hoc signed as
  `dev.ustinoff.copybara`, and checked after packaging; local builds can sign
  with your team from `Config/Local.xcconfig` so Accessibility survives rebuilds.
- **FIXED**: Square corners showed around the Liquid Glass popup.
- **FIXED**: Paste went into Copybara itself instead of the app you were in —
  the target app is now kept for the paste and gets focus back reliably.
- **FIXED**: Paste into Chromium/Electron apps (Claude, Discord, VS Code, Telegram).
- **FIXED**: The Settings window didn't open on macOS 14+; changes to history
  size, retention and "Ignore all copies" now apply immediately, the
  Accessibility status refreshes, and "Launch at login" shows the real state.

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
