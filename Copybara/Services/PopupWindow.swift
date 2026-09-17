import AppKit

/// A borderless, non-activating key panel that hosts the search popup.
///
/// It must be able to *become key* even though it is a panel, so the embedded
/// search field can receive keystrokes without the whole app taking focus.
/// TODO(M1): host `PopupView`, position under the status item, and forward
/// keyboard navigation.
final class PopupWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = true
        isMovableByWindowBackground = false
        backgroundColor = .clear
        hasShadow = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
