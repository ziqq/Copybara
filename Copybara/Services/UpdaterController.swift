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
            alert.messageText = "You're up to date"
            alert.informativeText = "Copybara \(current) is the latest version."
            alert.addButton(withTitle: "OK")
            alert.runModal()

        case .available(let release):
            alert.messageText = "Update available"
            alert.informativeText = "Copybara \(release.version) is available — you have \(UpdateChecker.current())."
            alert.addButton(withTitle: "Download")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(release.downloadURL ?? release.url)
            }

        case .failed(let message):
            alert.messageText = "Couldn't check for updates"
            alert.informativeText = message
            alert.addButton(withTitle: "Open Releases")
            alert.addButton(withTitle: "OK")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(UpdateChecker.releasesPage)
            }
        }
    }
}
