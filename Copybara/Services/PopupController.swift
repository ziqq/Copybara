import AppKit
import SwiftUI

/// Coordinates the search popup: owns the panel and its SwiftUI content, shows
/// and hides it, routes keyboard navigation, and performs paste-on-commit.
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

    /// Supplies the on-screen rect to anchor the popup under (the status button).
    var anchorRectProvider: (() -> NSRect?)?

    init(store: HistoryStore, paster: Paster) {
        self.oo = PopupOO(store: store)
        self.paster = paster
        self.window = PopupWindow()

        let root = PopupView(oo: oo) { [weak self] item in
            self?.commit(item)
        }
        window.contentView = NSHostingView(rootView: root)
    }

    var isVisible: Bool { window.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    // MARK: - Show / hide

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        oo.reset()
        positionWindow()
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
        window.orderOut(nil)
    }

    private func positionWindow() {
        let size = window.frame.size
        guard let anchor = anchorRectProvider?(),
              let screen = NSScreen.main else {
            window.center()
            return
        }

        var x = anchor.midX - size.width / 2
        var y = anchor.minY - size.height - 6

        let visible = screen.visibleFrame
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        if y < visible.minY + 8 { y = anchor.maxY + 6 } // flip below → above if needed

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 125: // ↓
                self.oo.moveSelection(by: 1)
                return nil
            case 126: // ↑
                self.oo.moveSelection(by: -1)
                return nil
            case 36, 76: // Return / Enter
                if let item = self.oo.selectedItem { self.commit(item) }
                return nil
            case 53: // Esc
                self.hide()
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

    private func commit(_ item: ClipItemDO) {
        // For text clips the preview carries the full text.
        let text = item.preview
        hide()
        paster.stage(text: text)

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
