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
        // One-time migration: drop a previously stored ⌘⇧C so the new ⌘⇧V default
        // takes effect (a stored value overrides the code default).
        if !AppSettings.shared.didMigrateHotkeyToV {
            KeyboardShortcuts.reset(.togglePopup)
            AppSettings.shared.didMigrateHotkeyToV = true
        }

        // onKeyDown fires as soon as the chord is pressed — snappier and more
        // reliable for the first press than waiting for key-up.
        KeyboardShortcuts.onKeyDown(for: .togglePopup) { [weak self] in
            Log.app.info("Toggle-popup shortcut fired")
            self?.onToggle?()
        }
        let current = KeyboardShortcuts.getShortcut(for: .togglePopup)
        Log.app.info("Global shortcut registered for togglePopup: \(String(describing: current), privacy: .public)")
    }

    /// Removes the global shortcut handler.
    func unregister() {
        KeyboardShortcuts.disable(.togglePopup)
    }
}
