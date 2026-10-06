// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import SwiftUI

/// Presents the first-run onboarding window and owns its lifetime.
@MainActor
final class OnboardingController {
    private let paster: Paster
    private let settings: AppSettings
    private(set) var window: NSWindow?

    init(paster: Paster, settings: AppSettings = .shared) {
        self.paster = paster
        self.settings = settings
    }

    /// Also restores permission guidance when an update loses Accessibility.
    func showIfNeeded() {
        guard !settings.hasCompletedOnboarding || !paster.hasAccessibilityPermission else { return }
        show()
    }

    func show() {
        if window == nil {
            let root = OnboardingView(
                onGrant: { [weak self] in
                    guard let self else { return }
                    if !self.paster.ensureAccessibilityPermission() {
                        Self.openAccessibilitySettings()
                    }
                },
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
        NSApp.unhideWithoutActivation()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    private func finish() {
        settings.hasCompletedOnboarding = true
        window?.close()
    }

    /// Opens the Accessibility pane of System Settings.
    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
