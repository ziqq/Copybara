import AppKit

/// Places an item on the pasteboard and pastes it into the frontmost app by
/// synthesizing a ⌘V keystroke.
///
/// Synthesizing keystrokes requires the Accessibility permission — the only
/// permission Copybara ever asks for. It is requested lazily, on the first paste.
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

    /// Copies `text` to the pasteboard and pastes it into the frontmost app.
    func paste(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard hasAccessibilityPermission else {
            Log.paste.error("Cannot paste: Accessibility permission is missing")
            return
        }
        synthesizeCommandV()
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
