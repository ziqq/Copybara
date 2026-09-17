import Foundation

/// Owns the global hotkey that toggles the search popup.
///
/// M0 defines the surface only. The default shortcut is ⌘⇧C.
/// TODO(M1): back this with the `KeyboardShortcuts` package, including the
/// rebinding UI shown in Settings.
final class HotKeyManager {
    /// Invoked when the global shortcut fires.
    var onToggle: (() -> Void)?

    /// Registers the global shortcut.
    func register() {
        // TODO(M1): register ⌘⇧C via KeyboardShortcuts and call `onToggle`.
        Log.app.debug("HotKeyManager.register() is a no-op until M1")
    }

    /// Removes the global shortcut.
    func unregister() {
        // TODO(M1)
    }
}
