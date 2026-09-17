import SwiftUI

/// Copybara — a fast, keyboard-first, local-only clipboard manager for macOS.
///
/// The app runs as a menu-bar agent (`LSUIElement`); `AppDelegate` owns the
/// runtime services. The only SwiftUI scene is the Settings window.
@main
struct CopybaraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
