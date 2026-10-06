// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import SwiftUI

/// Presents the preferences window and owns its lifetime.
///
/// An AppKit window rather than the SwiftUI `Settings` scene: a menu-bar agent
/// can't open that scene programmatically on macOS 14+ (`showSettingsWindow:`
/// is ignored and `SettingsLink` needs a SwiftUI view to click).
@MainActor
final class SettingsWindowController {
    private(set) var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingView(rootView: SettingsView())
            if #available(macOS 13.0, *) {
                // The window owns its size; measuring the whole settings form
                // here can re-enter AppKit's window layout while opening it.
                hosting.sizingOptions = []
            }
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.contentView = hosting
            window.title = L10n.string("Copybara Settings")
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.unhideWithoutActivation()
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
