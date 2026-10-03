// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit

/// Places an item on the pasteboard and pastes it into the frontmost app by
/// synthesizing a ⌘V keystroke.
///
/// Synthesizing keystrokes requires the Accessibility permission — the only
/// permission Copybara ever asks for. It is requested lazily, on the first paste.
///
/// Staging and pasting are separate steps because the caller usually needs to
/// re-activate the target app (which lost focus to Copybara's popup) *between*
/// putting the text on the pasteboard and sending ⌘V.
final class Paster {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    /// Whether the app currently holds the Accessibility permission.
    var hasAccessibilityPermission: Bool { AXIsProcessTrusted() && CGPreflightPostEventAccess() }

    /// Prompts the user to grant Accessibility permission if not already granted.
    /// Returns the current trust state.
    @discardableResult
    func ensureAccessibilityPermission() -> Bool {
        // "AXTrustedCheckOptionPrompt" is the string value of
        // kAXTrustedCheckOptionPrompt; used literally to avoid SDK-specific
        // Unmanaged/CFString import differences.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if trusted && !CGPreflightPostEventAccess() {
            CGRequestPostEventAccess()
        }
        return hasAccessibilityPermission
    }

    /// Writes `text` to the pasteboard without pasting.
    func stage(text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Writes a stored item to the pasteboard in its native representation.
    /// With `plain` true, only the plain-text form is written (strip formatting).
    func stage(item: ClipItemDO, plain: Bool = false) {
        pasteboard.clearContents()

        switch item.kind {
        case .text, .snippet:
            pasteboard.setString(item.textToPaste, forType: .string)
        case .rtf:
            if !plain, let data = item.data {
                pasteboard.setData(data, forType: .rtf)
            }
            pasteboard.setString(item.preview, forType: .string)
        case .image:
            if let data = item.data {
                pasteboard.setData(data, forType: .png)
                // Native editors commonly request TIFF even when browsers
                // accept PNG. Offer both representations of the same image.
                if let tiff = NSImage(data: data)?.tiffRepresentation {
                    pasteboard.setData(tiff, forType: .tiff)
                }
            }
        case .file:
            if !plain, let data = item.data, let paths = FilePayload.paths(from: data) {
                let urls = paths.map(URL.init(fileURLWithPath:)) as [NSURL]
                pasteboard.writeObjects(urls)
            } else {
                pasteboard.setString(item.preview, forType: .string)
            }
        }
    }

    /// Synthesizes ⌘V into whatever app is currently frontmost.
    /// Requires Accessibility permission; no-ops (with a log) otherwise.
    func pasteIntoFrontmostApp(expectedPID: pid_t? = nil) {
        guard hasAccessibilityPermission else {
            Log.paste.error("Cannot paste: Accessibility permission is missing")
            return
        }
        guard let target = NSWorkspace.shared.frontmostApplication,
              target.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              expectedPID == nil || target.processIdentifier == expectedPID else {
            Log.paste.error("Cannot paste: target app no longer has focus")
            return
        }
        synthesizeCommandV(into: target.processIdentifier)
    }

    /// Convenience: stage `text` and immediately paste it into the frontmost app.
    func paste(text: String) {
        stage(text: text)
        pasteIntoFrontmostApp()
    }

    private func synthesizeCommandV(into pid: pid_t) {
        let source = CGEventSource(stateID: .combinedSessionState)
        // Don't let keys the user is still physically holding (e.g. ⌘ from ⌘1
        // or ⇧ from the hotkey) leak into the synthesized chord.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let vKeyCode: CGKeyCode = 9 // ANSI 'v' — layout-independent key position
        // Chromium/Electron apps (Claude, Discord, VS Code, Telegram…) check the
        // device-dependent "left ⌘" bit, not just the generic Command mask.
        let flags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x000008)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = flags
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = flags

        keyDown?.postToPid(pid)
        keyUp?.postToPid(pid)
    }
}
