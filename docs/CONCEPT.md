# Copybara — Product Concept

## One-liner

> Press <kbd>⌘</kbd><kbd>⇧</kbd><kbd>C</kbd> → type a few letters → <kbd>Return</kbd> → it's pasted.

A menu-bar clipboard manager for macOS that makes your entire copy history
instantly reachable from the keyboard, while keeping every byte on-device.

## The problem

The clipboard holds exactly one thing. The moment you copy something new, the
previous item is gone. In real work you constantly need the last few (or few
dozen) things you copied: a code snippet, a URL, an address, a one-time code, a
paragraph you're moving around. Re-finding and re-copying them is friction that
happens hundreds of times a day.

## The idea

Copybara is a small, focused utility. It does **one** thing: keep a searchable
history of what you copy, and let you paste any of it back in a keystroke. It
deliberately does *not* try to be a notes app,
a snippet IDE, or a sync service.

## Who it's for

Anyone who lives on the keyboard: developers, writers, designers, support and
ops people — anyone who copies and pastes all day and wants the last N clips one
shortcut away.

## Principles (non-negotiable)

1. **Keyboard-first.** The whole loop — open, search, select, paste — is doable
   without touching the mouse. The mouse is a convenience, never a requirement.
2. **Local-only / privacy.** History is stored only on the device. No accounts,
   no cloud, no sync, no analytics. Passwords and "secret" pasteboard types are
   ignored by design.
3. **Lightweight.** A background menu-bar agent with a tiny memory and CPU
   footprint. It launches at login and disappears into the workflow.
4. **Instant.** Opening the window and searching must feel immediate. Perceived
   latency is a bug.

## Core loop

1. You copy something anywhere in macOS.
2. Copybara notices the change and stores it in local history (unless it's a
   secret/transient type or from a blocked app).
3. Later, you press the global hotkey.
4. A small window appears with the search field focused and history listed.
5. You type to fuzzy-filter, use arrow keys to move, press <kbd>Return</kbd>.
6. The item is placed on the clipboard and pasted into the app you were in.

## Scope

### In scope (MVP, v0.1)
- Text clipboard history with a size cap.
- Menu-bar presence + global hotkey.
- Fuzzy search, keyboard navigation, paste-on-select.
- Clear history, launch at login.

### In scope (v0.2)
- Pinning, images/RTF/files, privacy filters (concealed/transient types, app
  blocklist), hover preview, settings UI, Dock/menu-bar visibility toggle.

### Out of scope (for now)
- Cloud sync across devices.
- Full snippet/template management (may come later, clearly opt-in).
- Cross-platform (Windows/Linux) — this is a native macOS app.

## What "done" looks like for v0.1

A person can install Copybara, grant Accessibility once, and from then on recall
and paste any recent text clip entirely from the keyboard, with the app running
quietly in the menu bar and surviving reboots via launch-at-login.

## Naming

**Copybara** = *capybara* + *copy*. The word literally contains "copy", the
capybara is a calm, friendly mascot that fits a quiet always-on utility, and it
avoids the generic "clip/paste" naming everyone else uses.

## Prior art

Copybara is an independent implementation built entirely from scratch — not a
fork or copy of any existing app. Where established macOS clipboard managers have
proven approaches (change-count polling, concealed-type filtering, keyboard-driven
paste), we adopt the *approach*, not the code.
