// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit

/// Runs an on-demand update check and presents the result. Backed by
/// `UpdateChecker` (GitHub Releases) — no Sparkle, no background polling.
@MainActor
final class UpdaterController {
    func checkForUpdates() {
        Task { [weak self] in
            let outcome = await UpdateChecker.check()
            self?.present(outcome)
        }
    }

    private func present(_ outcome: UpdateChecker.Outcome) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()

        switch outcome {
        case .upToDate(let current):
            alert.messageText = L10n.string("You're up to date")
            alert.informativeText = L10n.format("Copybara %@ is the latest version.", current)
            alert.addButton(withTitle: L10n.string("OK"))
            alert.runModal()

        case .available(let release):
            alert.messageText = L10n.string("Update available")
            alert.informativeText = L10n.format("Copybara %@ is available — you have %@.", release.version, UpdateChecker.current())
            alert.addButton(withTitle: L10n.string("Download"))
            alert.addButton(withTitle: L10n.string("Later"))
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(release.downloadURL ?? release.url)
            }

        case .failed(let message):
            alert.messageText = L10n.string("Couldn't check for updates")
            alert.informativeText = message
            alert.addButton(withTitle: L10n.string("Open Releases"))
            alert.addButton(withTitle: L10n.string("OK"))
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(UpdateChecker.releasesPage)
            }
        }
    }
}
