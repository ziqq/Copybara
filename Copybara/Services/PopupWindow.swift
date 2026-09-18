import AppKit

/// A borderless, non-activating key panel that hosts the search popup.
///
/// It must be able to *become key* even though it is a panel, so the embedded
/// search field can receive keystrokes without the whole app taking focus. The
/// window is transparent; the rounded, vibrant background is provided by the
/// content view (`NSVisualEffectView`) installed by `PopupController`.
final class PopupWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: PopupMetrics.width, height: 480),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        level = .floating
        hidesOnDeactivate = true
        isMovable = true
        isMovableByWindowBackground = true // drag anywhere non-interactive to reposition
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
