// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import Sparkle

/// Checks for updates on demand and lets Sparkle verify, install, and relaunch.
@MainActor
final class UpdaterController {
    private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func checkForUpdates() {
        // Present update UI after the status menu finishes tracking.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.controller.updater.canCheckForUpdates else { return }
            self.controller.checkForUpdates(nil)
        }
    }
}
