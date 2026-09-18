import AppKit

/// Wires up the app's services and owns their lifetime.
///
/// Copybara runs as a menu-bar agent: there is no main window. The status item
/// and popup are created here, the clipboard monitor and global hotkey are
/// started, and the activation policy is set from the icon-visibility preference.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = HistoryStore()
    private let paster = Paster()
    private lazy var monitor = ClipboardMonitor(store: store)
    private lazy var popupController = PopupController(store: store, paster: paster)
    private let hotKeyManager = HotKeyManager()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.sizeLimit = AppSettings.shared.historySize
        applyActivationPolicy(AppSettings.shared.iconVisibility)

        let controller = StatusItemController(store: store)
        controller.onPrimaryAction = { [weak self] in self?.popupController.toggle() }
        controller.onOpenSettings = { [weak self] in self?.showSettings() }
        controller.onIgnoreNext = { [weak self] in self?.monitor.ignoreNextCopy() }
        statusItemController = controller

        popupController.anchorRectProvider = { [weak self] in
            self?.statusItemController?.statusButtonScreenRect()
        }

        hotKeyManager.onToggle = { [weak self] in self?.popupController.toggle() }
        hotKeyManager.register()

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
