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
    /// Whether the app currently holds the Accessibility permission.
    var hasAccessibilityPermission: Bool { AXIsProcessTrusted() }

    /// Prompts the user to grant Accessibility permission if not already granted.
    /// Returns the current trust state.
    @discardableResult
    func ensureAccessibilityPermission() -> Bool {
        // "AXTrustedCheckOptionPrompt" is the string value of
        // kAXTrustedCheckOptionPrompt; used literally to avoid SDK-specific
        // Unmanaged/CFString import differences.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Writes `text` to the general pasteboard without pasting.
    func stage(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Synthesizes ⌘V into whatever app is currently frontmost.
    /// Requires Accessibility permission; no-ops (with a log) otherwise.
    func pasteIntoFrontmostApp() {
        guard hasAccessibilityPermission else {
            Log.paste.error("Cannot paste: Accessibility permission is missing")
            return
        }
        synthesizeCommandV()
    }

    /// Convenience: stage `text` and immediately paste it into the frontmost app.
    func paste(text: String) {
        stage(text: text)
        pasteIntoFrontmostApp()
    }

    private func synthesizeCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 9 // ANSI 'v'

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
