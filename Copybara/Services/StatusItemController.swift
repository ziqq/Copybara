// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit

/// Owns the menu-bar status item.
///
/// Left-click opens the search popup (the primary action); right-click shows a
/// context menu with quick settings, Clear History, and Quit. The menu is
/// rebuilt on each open so counts and preference checkmarks stay fresh.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let store: HistoryStore
    private let presentMenu: (NSMenu, NSStatusBarButton) -> Void

    /// Invoked on left-click — opens/toggles the popup.
    var onPrimaryAction: (() -> Void)?
    /// Invoked before the context menu opens, to dismiss the search popup.
    var onOpenContextMenu: (() -> Void)?
    /// Invoked when the user chooses "Settings".
    var onOpenSettings: (() -> Void)?
    /// Invoked to skip recording the next copy (⌥⇧-click / menu).
    var onIgnoreNext: (() -> Void)?
    /// Invoked to check for app updates.
    var onCheckForUpdates: (() -> Void)?

    init(store: HistoryStore, presentMenu: @escaping (NSMenu, NSStatusBarButton) -> Void = { menu, button in
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }) {
        self.store = store
        self.presentMenu = presentMenu
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
    }

    /// The status button's frame in screen coordinates, used to anchor the popup.
    func statusButtonScreenRect() -> NSRect? {
        guard statusItem.isVisible else { return nil }
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    func applyVisibility(_ visibility: IconVisibility) {
        statusItem.isVisible = visibility != .dock
    }

    var isVisible: Bool { statusItem.isVisible }

    deinit { NSStatusBar.system.removeStatusItem(statusItem) }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = MenuBarIcon.image()
        button.target = self
        button.action = #selector(handleStatusClick)
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

    @objc private func handleStatusClick() {
        handleClick(event: NSApp.currentEvent)
    }

    func handleClick(event: NSEvent?) {
        guard let event else { onPrimaryAction?(); return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.type == .rightMouseUp || (event.type == .leftMouseUp && flags.contains(.control)) {
            showContextMenu()
            return
        }
        guard event.type == .leftMouseUp else { return }
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
        onOpenContextMenu?()
        let menu = buildMenu()
        presentMenu(menu, button)
    }

    func buildMenu() -> NSMenu {
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

        let updates = NSMenuItem(title: L10n.string("Check for Updates…"), action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)

        let settings = NSMenuItem(title: L10n.string("Settings"), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        settings.submenu = buildSettingsMenu()
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

        removeDefaultIcons(from: menu)
        return menu
    }

    private func buildSettingsMenu() -> NSMenu {
        let menu = NSMenu(title: L10n.string("Settings"))
        menu.autoenablesItems = false

        let ignoreAll = NSMenuItem(title: L10n.string("Ignore All Copies"), action: #selector(toggleIgnoreAllFromMenu), keyEquivalent: "")
        ignoreAll.target = self
        ignoreAll.state = AppSettings.shared.ignoreAllCopies ? .on : .off
        menu.addItem(ignoreAll)

        let ignoreNext = NSMenuItem(title: L10n.string("Ignore Next Copy"), action: #selector(ignoreNextFromMenu), keyEquivalent: "")
        ignoreNext.target = self
        menu.addItem(ignoreNext)

        menu.addItem(.separator())

        let position = NSMenuItem(title: L10n.string("Open popup at"), action: nil, keyEquivalent: "")
        let positions = NSMenu(title: position.title)
        positions.autoenablesItems = false
        for value in [PopupPosition.remembered, .menuBarIcon, .center, .cursor] {
            let item = NSMenuItem(title: value.title, action: #selector(changePopupPosition(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value.rawValue
            item.state = AppSettings.shared.popupPosition == value ? .on : .off
            positions.addItem(item)
        }
        position.submenu = positions
        menu.addItem(position)

        let startup = NSMenuItem(title: L10n.string("Launch at login"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        startup.target = self
        startup.isEnabled = LaunchAtLoginManager.isSupported
        startup.state = LaunchAtLoginManager.isEnabled ? .on : .off
        menu.addItem(startup)

        menu.addItem(.separator())

        let open = NSMenuItem(title: L10n.string("Open Settings"), action: #selector(openSettings), keyEquivalent: ",")
        open.target = self
        menu.addItem(open)
        return menu
    }

    private func removeDefaultIcons(from menu: NSMenu) {
        for item in menu.items where !item.isSeparatorItem {
            // macOS 26 preserves default action icons when nil is assigned
            // first. Assigning an image before clearing it opts out instead.
            // https://developer.apple.com/forums/thread/800414
            item.image = NSImage()
            item.image = nil
            if let submenu = item.submenu { removeDefaultIcons(from: submenu) }
        }
    }

    // MARK: - Actions

    @objc private func openPopup() {
        // Show the search window after the context menu finishes tracking.
        DispatchQueue.main.async { [weak self] in self?.onPrimaryAction?() }
    }
    @objc private func openSettings() {
        // Let NSMenu finish tracking before creating and activating a window.
        DispatchQueue.main.async { [weak self] in self?.onOpenSettings?() }
    }
    @objc private func checkForUpdates() { onCheckForUpdates?() }
    @objc private func clearAll() { store.clearAll() }
    @objc private func toggleIgnoreAllFromMenu() { toggleIgnoreAll() }
    @objc private func ignoreNextFromMenu() { onIgnoreNext?() }
    @objc private func changePopupPosition(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let position = PopupPosition(rawValue: raw) else { return }
        AppSettings.shared.popupPosition = position
    }
    @objc private func toggleLaunchAtLogin() {
        // Registration can prompt; let the menu finish tracking first.
        DispatchQueue.main.async {
            LaunchAtLoginManager.setEnabled(!LaunchAtLoginManager.isEnabled)
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
