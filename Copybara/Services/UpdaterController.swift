import Sparkle

/// Wraps Sparkle's standard updater so the rest of the app can trigger an update
/// check without importing Sparkle directly.
///
/// The updater reads `SUFeedURL` and `SUPublicEDKey` from Info.plist. Until a real
/// appcast is hosted and a public key is set (see docs/RELEASE.md), automatic and
/// manual checks simply fail to find an update.
@MainActor
final class UpdaterController {
    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Triggers a user-initiated update check (shows Sparkle's UI).
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
