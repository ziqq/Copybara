// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import Sparkle

/// Checks for updates on demand and lets Sparkle verify, install, and relaunch.
@MainActor
final class UpdaterController {
    private let driver = CompactUpdateUserDriver(hostBundle: .main)
    private lazy var updater = SPUUpdater(hostBundle: .main, applicationBundle: .main,
                                         userDriver: driver, delegate: nil)
    private var startError: Error?

    init() {
        do { try updater.start() }
        catch {
            startError = error
            Log.app.error("Cannot start updater: \(error.localizedDescription, privacy: .public)")
        }
    }

    func checkForUpdates() {
        // Present update UI after the status menu finishes tracking.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let error = self.startError {
                self.driver.showUpdaterError(error) {}
                return
            }
            guard self.updater.canCheckForUpdates else { return }
            self.updater.checkForUpdates()
        }
    }
}

/// Uses Sparkle's installer and progress UI, with a compact prompt for the
/// simple two-choice update shown when the feed contains no release notes.
@MainActor
final class CompactUpdateUserDriver: SPUStandardUserDriver {
    private var updateAlert: NSAlert?
    private let presentAlert: @MainActor (NSAlert) -> NSApplication.ModalResponse

    init(hostBundle: Bundle, presentAlert: @escaping @MainActor (NSAlert) -> NSApplication.ModalResponse = { $0.runModal() }) {
        self.presentAlert = presentAlert
        super.init(hostBundle: hostBundle, delegate: nil)
    }

    static func makeAlert(version: String, current: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = L10n.string("Update available")
        // An explicit wrapping accessory keeps long translations from
        // expanding the window to the width of the entire sentence.
        let label = NSTextField(wrappingLabelWithString:
            L10n.format("Copybara %@ is available — you have %@.", version, current))
        label.preferredMaxLayoutWidth = 360
        label.frame = NSRect(x: 0, y: 0, width: 360, height: 50)
        alert.accessoryView = label
        let bundle = Bundle(for: SPUStandardUserDriver.self)
        alert.addButton(withTitle: bundle.localizedString(forKey: "Install Update", value: nil, table: "Sparkle"))
        alert.addButton(withTitle: bundle.localizedString(forKey: "Skip This Version", value: nil, table: "Sparkle"))
        return alert
    }

    override func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState,
                                  reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard !appcastItem.isInformationOnlyUpdate, !appcastItem.isMajorUpgrade,
              !appcastItem.isCriticalUpdate, appcastItem.releaseNotesURL == nil,
              appcastItem.itemDescription == nil, state.stage == .notDownloaded else {
            super.showUpdateFound(with: appcastItem, state: state, reply: reply)
            return
        }
        showCompactUpdate(version: appcastItem.displayVersionString, current: UpdateChecker.current(), reply: reply)
    }

    func showCompactUpdate(version: String, current: String, reply: (SPUUserUpdateChoice) -> Void) {
        // Reset the standard driver's checking UI before taking over this
        // not-yet-downloaded update. The updater's session stays in Sparkle.
        super.dismissUpdateInstallation()
        NSApp.unhideWithoutActivation()
        NSApp.activate(ignoringOtherApps: true)
        let alert = Self.makeAlert(version: version, current: current)
        updateAlert = alert
        let result = presentAlert(alert)
        updateAlert = nil
        switch result {
        case .alertFirstButtonReturn: reply(.install)
        case .alertSecondButtonReturn: reply(.skip)
        default: reply(.dismiss)
        }
    }

    override func dismissUpdateInstallation() {
        if let updateAlert {
            NSApp.abortModal()
            updateAlert.window.close()
        }
        super.dismissUpdateInstallation()
    }

    override func showUpdateInFocus() {
        guard let updateAlert else { super.showUpdateInFocus(); return }
        NSApp.activate(ignoringOtherApps: true)
        updateAlert.window.makeKeyAndOrderFront(nil)
    }
}
