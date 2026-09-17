import AppKit

/// Wires up the app's services and owns their lifetime.
///
/// Copybara runs as a menu-bar agent: there is no main window. The status item
/// is created here, the clipboard monitor is started, and the activation policy
/// is set from the user's icon-visibility preference.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = HistoryStore()
    private lazy var monitor = ClipboardMonitor(store: store)
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicy(AppSettings.shared.iconVisibility)

        let controller = StatusItemController(store: store)
        controller.onOpenSettings = { [weak self] in self?.showSettings() }
        statusItemController = controller

        monitor.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iconVisibilityChanged(_:)),
            name: .copybaraIconVisibilityChanged,
            object: nil
        )

        Log.app.info("Copybara launched")
    }

    // MARK: - Activation policy

    private func applyActivationPolicy(_ visibility: IconVisibility) {
        switch visibility {
        case .menuBar:
            NSApp.setActivationPolicy(.accessory)
        case .dock, .both:
            NSApp.setActivationPolicy(.regular)
        }
    }

    @objc private func iconVisibilityChanged(_ note: Notification) {
        guard let raw = note.userInfo?["value"] as? String,
              let visibility = IconVisibility(rawValue: raw) else { return }
        applyActivationPolicy(visibility)
    }

    // MARK: - Settings

    private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 13, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
