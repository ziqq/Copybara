import AppKit

/// Owns the menu-bar status item.
///
/// Left-click opens the search popup (the primary action); right-click shows a
/// context menu with Settings, Clear History, and Quit. The menu is rebuilt on
/// each open so the item count stays fresh.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let store: HistoryStore

    /// Invoked on left-click — opens/toggles the popup.
    var onPrimaryAction: (() -> Void)?
    /// Invoked when the user chooses "Settings…".
    var onOpenSettings: (() -> Void)?

    init(store: HistoryStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
    }

    /// The status button's frame in screen coordinates, used to anchor the popup.
    func statusButtonScreenRect() -> NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Copybara")
        button.image?.isTemplate = true
        button.toolTip = "Copybara"
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    // MARK: - Click handling

    @objc private func handleClick() {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
        if isRightClick {
            showContextMenu()
        } else {
            onPrimaryAction?()
        }
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        let menu = buildMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let count = store.recentItems(limit: 100_000).count
        let header = NSMenuItem(
            title: "Copybara — \(count) \(count == 1 ? "item" : "items")",
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)

        let open = NSMenuItem(title: "Show Copybara", action: #selector(openPopup), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

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

        return menu
    }

    // MARK: - Actions

    @objc private func openPopup() { onPrimaryAction?() }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func clearHistory() { store.clearAll() }
    @objc private func quit() { NSApp.terminate(nil) }
}
