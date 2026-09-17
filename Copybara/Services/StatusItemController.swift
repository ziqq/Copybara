import AppKit

/// Owns the menu-bar status item and the menu shown when it is clicked.
///
/// The menu is rebuilt each time it opens so the item count stays fresh. In M1
/// the primary action becomes "open the search popup"; for now the menu exposes
/// the history count plus Settings, Clear, and Quit.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let store: HistoryStore

    /// Invoked when the user chooses "Settings…".
    var onOpenSettings: (() -> Void)?

    init(store: HistoryStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        configureMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Copybara")
        button.image?.isTemplate = true
        button.toolTip = "Copybara"
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let count = store.recentItems(limit: 100_000).count
        let header = NSMenuItem(
            title: "Copybara — \(count) \(count == 1 ? "item" : "items")",
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let clear = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        clear.isEnabled = count > 0
        menu.addItem(clear)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Copybara", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func openSettings() { onOpenSettings?() }
    @objc private func clearHistory() { store.clearAll() }
    @objc private func quit() { NSApp.terminate(nil) }
}
