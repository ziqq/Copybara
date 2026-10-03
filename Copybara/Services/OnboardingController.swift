import AppKit
import SwiftUI

/// Presents the first-run onboarding window and owns its lifetime.
@MainActor
final class OnboardingController {
    private let paster: Paster
    private var window: NSWindow?

    init(paster: Paster) {
        self.paster = paster
    }

    /// Shows onboarding once, on first launch.
    func showIfNeeded() {
        guard !AppSettings.shared.hasCompletedOnboarding else { return }
        show()
    }

    func show() {
        if window == nil {
            let root = OnboardingView(
                onGrant: { [weak self] in self?.paster.ensureAccessibilityPermission() },
                onOpenSettings: { Self.openAccessibilitySettings() },
                onFinish: { [weak self] in self?.finish() }
            )
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = L10n.string("Welcome to Copybara")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        AppSettings.shared.hasCompletedOnboarding = true
        window?.close()
    }

    /// Opens the Accessibility pane of System Settings.
    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
