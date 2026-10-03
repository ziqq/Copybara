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
    /// Invoked to skip recording the next copy (⌥⇧-click / menu).
    var onIgnoreNext: (() -> Void)?
    /// Invoked to check for app updates.
    var onCheckForUpdates: (() -> Void)?

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
        button.image = MenuBarIcon.image()
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateAppearance()
    }

    /// Dims the icon and updates the tooltip while copies are being ignored.
    func updateAppearance() {
        guard let button = statusItem.button else { return }
        let ignoring = AppSettings.shared.ignoreAllCopies
        button.appearsDisabled = ignoring
        button.toolTip = ignoring ? L10n.string("Copybara — ignoring copies") : "Copybara"
    }

    // MARK: - Click handling

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { onPrimaryAction?(); return }
        if event.type == .rightMouseUp {
            showContextMenu()
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.option) && flags.contains(.shift) {
            onIgnoreNext?() // ⌥⇧-click — ignore the next copy
        } else if flags.contains(.option) {
            toggleIgnoreAll() // ⌥-click — toggle ignoring all copies
        } else {
            onPrimaryAction?()
        }
    }

    private func toggleIgnoreAll() {
        AppSettings.shared.ignoreAllCopies.toggle()
        updateAppearance()
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        let menu = buildMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let count = store.count()
        let header = NSMenuItem(
            title: L10n.format("Copybara — %ld items", count),
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)

        let open = NSMenuItem(title: L10n.string("Show Copybara"), action: #selector(openPopup), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        let ignoreAll = NSMenuItem(title: L10n.string("Ignore All Copies"), action: #selector(toggleIgnoreAllFromMenu), keyEquivalent: "")
        ignoreAll.target = self
        ignoreAll.state = AppSettings.shared.ignoreAllCopies ? .on : .off
        menu.addItem(ignoreAll)

        let ignoreNext = NSMenuItem(title: L10n.string("Ignore Next Copy"), action: #selector(ignoreNextFromMenu), keyEquivalent: "")
        ignoreNext.target = self
        menu.addItem(ignoreNext)

        menu.addItem(.separator())

        let updates = NSMenuItem(title: L10n.string("Check for Updates…"), action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)

        let settings = NSMenuItem(title: L10n.string("Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let clearAll = NSMenuItem(title: L10n.string("Clear All"), action: #selector(clearAll), keyEquivalent: "\u{8}")
        clearAll.keyEquivalentModifierMask = [.shift, .option, .command]
        clearAll.target = self
        clearAll.isEnabled = count > 0
        menu.addItem(clearAll)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: L10n.string("Quit Copybara"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        for item in menu.items where !item.isSeparatorItem {
            // macOS 26 preserves default action icons when nil is assigned
            // first. Assigning an image before clearing it opts out instead.
            // https://developer.apple.com/forums/thread/800414
            item.image = NSImage()
            item.image = nil
        }

        return menu
    }

    // MARK: - Actions

    @objc private func openPopup() { onPrimaryAction?() }
    @objc private func openSettings() {
        // Let NSMenu finish tracking before creating and activating a window.
        DispatchQueue.main.async { [weak self] in self?.onOpenSettings?() }
    }
    @objc private func checkForUpdates() { onCheckForUpdates?() }
    @objc private func clearAll() { store.clearAll() }
    @objc private func toggleIgnoreAllFromMenu() { toggleIgnoreAll() }
    @objc private func ignoreNextFromMenu() { onIgnoreNext?() }
    @objc private func quit() { NSApp.terminate(nil) }
}
