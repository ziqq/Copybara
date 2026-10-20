// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global shortcut that toggles the search popup. Default: ⌘⇧V (V = paste,
    /// like Windows' Win+V clipboard history).
    static let togglePopup = Self("togglePopup", default: .init(.v, modifiers: [.command, .shift]))
}

/// Owns the global hotkey that toggles the search popup, backed by the
/// `KeyboardShortcuts` package (which also provides the rebinding UI).
final class HotKeyManager {
    private let settings: AppSettings
    private let resetShortcut: () -> Void
    private let registerKeyDown: (@escaping () -> Void) -> Void
    private let disableShortcut: () -> Void

    /// Invoked on the main queue when the global shortcut fires.
    var onToggle: (() -> Void)?

    init(settings: AppSettings = .shared,
         resetShortcut: @escaping () -> Void = { KeyboardShortcuts.reset(.togglePopup) },
         registerKeyDown: @escaping (@escaping () -> Void) -> Void = { KeyboardShortcuts.onKeyDown(for: .togglePopup, action: $0) },
         disableShortcut: @escaping () -> Void = { KeyboardShortcuts.disable(.togglePopup) }) {
        self.settings = settings
        self.resetShortcut = resetShortcut
        self.registerKeyDown = registerKeyDown
        self.disableShortcut = disableShortcut
    }

    /// Registers the global shortcut handler.
    func register() {
        // One-time migration: drop a previously stored ⌘⇧C so the new ⌘⇧V default
        // takes effect (a stored value overrides the code default).
        if !settings.didMigrateHotkeyToV {
            resetShortcut()
            settings.didMigrateHotkeyToV = true
        }

        // onKeyDown fires as soon as the chord is pressed — snappier and more
        // reliable for the first press than waiting for key-up.
        registerKeyDown { [weak self] in
            Log.app.info("Toggle-popup shortcut fired")
            self?.onToggle?()
        }
        let current = KeyboardShortcuts.getShortcut(for: .togglePopup)
        Log.app.info("Global shortcut registered for togglePopup: \(String(describing: current), privacy: .public)")
    }

    /// Removes the global shortcut handler.
    func unregister() {
        disableShortcut()
    }
}
