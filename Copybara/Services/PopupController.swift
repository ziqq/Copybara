import AppKit
import Combine
import SwiftUI

/// Coordinates the search popup: owns the panel and its SwiftUI content, shows
/// and hides it, routes keyboard navigation, sizes the window to the results,
/// and performs paste-on-commit.
///
/// The tricky part is focus: to receive keystrokes, Copybara must become active,
/// which steals focus from the app the user was in. So the controller remembers
/// that app on show and re-activates it right before synthesizing ⌘V.
@MainActor
final class PopupController {
    private let oo: PopupOO
    private let paster: Paster
    private let window: PopupWindow

    private var keyMonitor: Any?
    private weak var previousApp: NSRunningApplication?
    private var cancellables = Set<AnyCancellable>()

    private var previewPanel: NSPanel?
    private var previewHosting: NSHostingView<PreviewCard>?

    /// Supplies the on-screen rect to anchor the popup under (the status button).
    var anchorRectProvider: (() -> NSRect?)?

    init(store: HistoryStore, paster: Paster) {
        self.oo = PopupOO(store: store)
        self.paster = paster
        self.window = PopupWindow()

        let root = PopupView(
            oo: oo,
            onCommit: { [weak self] item in self?.commit(item) },
            onHoverPreview: { [weak self] item in self?.updatePreview(item) }
        )
        window.contentView = makeContentView(hosting: NSHostingView(rootView: root))

        // Keep the window sized to the current number of results.
        oo.$results
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.layoutWindow() }
            .store(in: &cancellables)
    }

    /// Builds a rounded, vibrant container that hosts the SwiftUI content.
    private func makeContentView(hosting: NSHostingView<PopupView>) -> NSView {
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = PopupMetrics.cornerRadius
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 0.5
        effect.layer?.borderColor = NSColor.separatorColor.cgColor

        hosting.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor)
        ])
        return effect
    }

    var isVisible: Bool { window.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    // MARK: - Show / hide

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        oo.reset()
        layoutWindow()
        installKeyMonitor()

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window.makeKeyAndOrderFront(nil)
    }

    func hide() {
        removeKeyMonitor()
        updatePreview(nil)
        window.orderOut(nil)
    }

    // MARK: - Side preview

    private func updatePreview(_ item: ClipItemDO?) {
        guard let item, window.isVisible else {
            previewPanel?.orderOut(nil)
            return
        }

        let panel = ensurePreviewPanel()
        previewHosting?.rootView = PreviewCard(item: item)
        if let hosting = previewHosting {
            panel.setContentSize(hosting.fittingSize)
        }
        positionPreview(panel)
        panel.order(.above, relativeTo: window.windowNumber)
    }

    private func ensurePreviewPanel() -> NSPanel {
        if let previewPanel { return previewPanel }

        let hosting = NSHostingView(rootView: PreviewCard(item: ClipItemDO(preview: "")))
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.contentView = hosting

        previewHosting = hosting
        previewPanel = panel
        return panel
    }

    private func positionPreview(_ panel: NSPanel) {
        let main = window.frame
        let size = panel.frame.size
        let gap: CGFloat = 8
        let visible = (screenUnderCursor() ?? NSScreen.main)?.visibleFrame ?? main

        var x = main.maxX + gap
        if x + size.width > visible.maxX - 8 {
            x = main.minX - size.width - gap // flip to the left when it won't fit
        }
        let y = main.maxY - size.height
        panel.setFrameOrigin(NSPoint(x: x, y: clamp(y, min: visible.minY + 8, max: visible.maxY - size.height - 8)))
    }

    /// Sizes the window to the current results and re-anchors it under the icon.
    private func layoutWindow() {
        let height = PopupMetrics.totalHeight(for: oo.results.count)
        window.setContentSize(NSSize(width: PopupMetrics.width, height: height))
        positionWindow()
    }

    private func positionWindow() {
        let size = window.frame.size
        guard let screen = screenUnderCursor() ?? NSScreen.main else {
            window.center()
            return
        }
        let visible = screen.visibleFrame

        let origin: NSPoint
        switch AppSettings.shared.popupPosition {
        case .center:
            origin = centerOrigin(size: size, in: visible)
        case .cursor:
            origin = cursorOrigin(size: size, in: visible)
        case .menuBarIcon:
            if let anchor = validAnchorRect() {
                origin = anchorOrigin(anchor: anchor, size: size, in: visible)
            } else {
                // The status icon couldn't be located (e.g. hidden in the menu-bar
                // overflow), so fall back to the cursor rather than a bad corner.
                Log.app.error("Status icon anchor unavailable — positioning popup at cursor")
                origin = cursorOrigin(size: size, in: visible)
            }
        }

        window.setFrameOrigin(origin)
    }

    /// Returns the status-item anchor rect only when it is plausibly valid — non
    /// empty and intersecting a real screen. Guards against a zero/off-screen rect
    /// dropping the popup into a corner.
    private func validAnchorRect() -> NSRect? {
        guard let anchor = anchorRectProvider?(),
              anchor.width > 1, anchor.height > 1,
              NSScreen.screens.contains(where: { $0.frame.intersects(anchor) })
        else { return nil }
        return anchor
    }

    private func anchorOrigin(anchor: NSRect, size: NSSize, in visible: NSRect) -> NSPoint {
        var x = anchor.midX - size.width / 2
        var y = anchor.minY - size.height - 6
        x = clamp(x, min: visible.minX + 8, max: visible.maxX - size.width - 8)
        if y < visible.minY + 8 { y = anchor.maxY + 6 } // flip below → above if needed
        return NSPoint(x: x, y: y)
    }

    private func cursorOrigin(size: NSSize, in visible: NSRect) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        var x = mouse.x - size.width / 2
        var y = mouse.y - size.height - 6 // just below the pointer
        x = clamp(x, min: visible.minX + 8, max: visible.maxX - size.width - 8)
        if y < visible.minY + 8 { y = mouse.y + 6 } // flip above the pointer if needed
        y = min(y, visible.maxY - size.height - 8)
        return NSPoint(x: x, y: y)
    }

    private func centerOrigin(size: NSSize, in visible: NSRect) -> NSPoint {
        NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
    }

    private func screenUnderCursor() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
    }

    private func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        guard upper > lower else { return lower }
        return Swift.min(Swift.max(value, lower), upper)
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // ⌘1–9 — quick-paste the Nth item.
            if flags == .command, let digit = Int(event.charactersIgnoringModifiers ?? ""), digit >= 1, digit <= 9 {
                if let item = self.oo.item(atNumber: digit) { self.commit(item) }
                return nil
            }

            switch (event.keyCode, flags) {
            case (125, []): // ↓
                self.oo.moveSelection(by: 1)
                return nil
            case (126, []): // ↑
                self.oo.moveSelection(by: -1)
                return nil
            case (36, [.option, .shift]), (76, [.option, .shift]): // ⌥⇧↩ — paste plain
                if let item = self.oo.selectedItem { self.commit(item, plain: true) }
                return nil
            case (36, _), (76, _): // Return / Enter — paste
                if let item = self.oo.selectedItem { self.commit(item) }
                return nil
            case (53, _): // Esc
                self.hide()
                return nil
            case (35, .option): // ⌥P — pin / unpin
                self.oo.togglePinSelected()
                return nil
            case (51, [.shift, .option, .command]): // ⇧⌥⌘⌫ — clear all incl. pins
                self.oo.clearAll()
                return nil
            case (51, [.option, .command]): // ⌥⌘⌫ — clear unpinned
                self.oo.clearUnpinned()
                return nil
            case (51, .option): // ⌥⌫ — delete item
                self.oo.deleteSelected()
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    // MARK: - Commit / paste

    private func commit(_ item: ClipItemDO, plain: Bool = false) {
        hide()
        paster.stage(item: item, plain: plain)

        guard paster.ensureAccessibilityPermission() else {
            // Text is on the pasteboard; the user can paste it manually until the
            // permission is granted.
            Log.paste.error("Committed to pasteboard only — Accessibility not granted")
            return
        }

        reactivatePreviousApp()
        // Give the app a moment to become frontmost before sending ⌘V.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.paster.pasteIntoFrontmostApp()
        }
    }

    private func reactivatePreviousApp() {
        guard let previousApp else { return }
        if #available(macOS 14.0, *) {
            previousApp.activate()
        } else {
            previousApp.activate(options: [.activateIgnoringOtherApps])
        }
    }
}
