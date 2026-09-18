import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global shortcut that toggles the search popup. Default: ⌘⇧V (V = paste,
    /// like Windows' Win+V clipboard history).
    static let togglePopup = Self("togglePopup", default: .init(.v, modifiers: [.command, .shift]))
}

/// Owns the global hotkey that toggles the search popup, backed by the
/// `KeyboardShortcuts` package (which also provides the rebinding UI).
final class HotKeyManager {
    /// Invoked on the main queue when the global shortcut fires.
    var onToggle: (() -> Void)?

    /// Registers the global shortcut handler.
    func register() {
        // onKeyDown fires as soon as the chord is pressed — snappier and more
        // reliable for the first press than waiting for key-up.
        KeyboardShortcuts.onKeyDown(for: .togglePopup) { [weak self] in
            self?.onToggle?()
        }
        Log.app.debug("Global shortcut registered for togglePopup")
    }

    /// Removes the global shortcut handler.
    func unregister() {
        KeyboardShortcuts.disable(.togglePopup)
    }
}
