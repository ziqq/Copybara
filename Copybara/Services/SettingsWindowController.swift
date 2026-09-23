import AppKit
import SwiftUI

/// Presents the preferences window and owns its lifetime.
///
/// An AppKit window rather than the SwiftUI `Settings` scene: a menu-bar agent
/// can't open that scene programmatically on macOS 14+ (`showSettingsWindow:`
/// is ignored and `SettingsLink` needs a SwiftUI view to click).
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Copybara Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
