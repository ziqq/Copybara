// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import Combine
import SwiftUI

/// Coordinates the search popup: owns the panel and its SwiftUI content, shows
/// and hides it, routes keyboard navigation, sizes the window to the results,
/// and performs paste-on-commit.
///
/// The panel takes keyboard focus without activating Copybara. The controller
/// remembers the destination app and restores it when another Copybara window
/// (such as Settings) was active before the popup opened.
@MainActor
final class PopupController {
    private let oo: PopupOO
    private let paster: Paster
    private let window: PopupWindow

    /// The app to paste into. Held strongly: `frontmostApplication` hands back a
    /// fresh instance nobody else retains, so a weak reference is nil at once.
    private var previousApp: NSRunningApplication?
    private var pasteGeneration = 0
    private var cancellables = Set<AnyCancellable>()

    private var previewPanel: NSPanel?
    private var previewHosting: NSHostingView<PreviewCard>?
    private var didPromptAccessibility = false
    private var moveObserver: NSObjectProtocol?
    private var lastProgrammaticOrigin: NSPoint?

    /// Supplies the on-screen rect to anchor the popup under (the status button).
    var anchorRectProvider: (() -> NSRect?)?
    /// Shows permission recovery when a paste cannot send keyboard events.
    var onAccessibilityRequired: (() -> Void)?

    init(store: HistoryStore, paster: Paster, settings: AppSettings = .shared, snippets: SnippetStore = .shared) {
        self.oo = PopupOO(store: store, settings: settings, snippets: snippets)
        self.paster = paster
        self.window = PopupWindow()

        rememberTarget(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                self?.rememberTarget(note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
            }
            .store(in: &cancellables)

        window.onKeyDown = { [weak self] event in
            self?.handleKeyEvent(event) ?? false
        }
        configureAppearance()

        // Keep the window sized to the current number of results. Deferred to the
        // next runloop tick so the resize never runs inside a SwiftUI layout pass
        // (which triggers "-layoutSubtreeIfNeeded ... already being laid out").
        oo.$results
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.layoutWindow() }
            }
            .store(in: &cancellables)

        // Remember where the user drags the popup (snapped to a grid).
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: window, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.savePopupPosition() }
        }
    }

    /// Rebuilds the popup's content view for the current appearance setting:
    /// plain hosting (the view draws its own Liquid Glass) vs. a vibrant
    /// `NSVisualEffectView` container. Called on init and each show, so toggling
    /// the setting applies the next time the popup opens.
    private func configureAppearance() {
        let glass = LiquidGlass.isEnabled
        let root = PopupView(
            oo: oo,
            useGlass: glass,
            onCommit: { [weak self] item in self?.commit(item) },
            onHoverPreview: { [weak self] item in self?.updatePreview(item) },
            onAction: { [weak self] action in self?.perform(action) }
        )
        let hosting = NSHostingView(rootView: root)
        window.contentView = glass ? makeGlassContentView(hosting: hosting) : makeContentView(hosting: hosting)
        window.invalidateShadow()
    }

    /// Clips the hosting view to the popup's rounded shape so no square window
    /// corners (background or shadow) show around the Liquid Glass surface.
    private func makeGlassContentView(hosting: NSHostingView<PopupView>) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.layer?.cornerRadius = PopupMetrics.cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true

        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
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

    var isVisible: Bool { window.isVisible && !NSApp.isHidden }

    func toggle() {
        isVisible ? hide() : show()
    }

    // MARK: - Show / hide

    func show() {
        pasteGeneration += 1
        // Re-opening while Copybara is already frontmost (e.g. from Settings) must
        // keep the real target rather than pasting into Copybara itself.
        rememberTarget(NSWorkspace.shared.frontmostApplication)
        configureAppearance()
        oo.reset()
        layoutWindow()

        // A failed focus handoff can hide the app. Restore it without stealing
        // activation from the destination before presenting the next popup.
        NSApp.unhideWithoutActivation()
        // A nonactivating panel accepts search input while keeping the target
        // app active, avoiding an activation race when an item is pasted.
        window.makeKeyAndOrderFront(nil)
        window.makeKey()
    }

    func hide() {
        updatePreview(nil)
        window.orderOut(nil)
    }

    private func rememberTarget(_ app: NSRunningApplication?) {
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        previousApp = app
    }

    // MARK: - Side preview

    /// Keeps the preview in sync with the selection while it is on screen.
    private func refreshPreviewIfVisible() {
        if previewPanel?.isVisible == true {
            updatePreview(oo.selectedItem)
        }
    }

    private func updatePreview(_ item: ClipItemDO?) {
        guard let item, window.isVisible else {
            previewPanel?.orderOut(nil)
            return
        }

        let panel = ensurePreviewPanel()
        previewHosting?.rootView = PreviewCard(item: oo.withPayload(item))
        // Defer sizing/positioning so fittingSize isn't forced during a layout pass.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window.isVisible, let hosting = self.previewHosting else { return }
            panel.setContentSize(hosting.fittingSize)
            self.positionPreview(panel)
            panel.order(.above, relativeTo: self.window.windowNumber)
        }
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
        window.invalidateShadow() // the shadow follows the rounded shape at the new size
        positionWindow()
    }

    private func positionWindow() {
        let size = window.frame.size
        guard let screen = screenUnderCursor() ?? NSScreen.main else {
            window.center()
            lastProgrammaticOrigin = window.frame.origin
            return
        }
        let visible = screen.visibleFrame

        let origin: NSPoint
        switch AppSettings.shared.popupPosition {
        case .remembered:
            if let top = AppSettings.shared.popupSavedTop {
                // Keep the saved top edge fixed as the list grows downward.
                origin = clampOrigin(NSPoint(x: top.x, y: top.y - size.height), size: size, in: visible)
            } else {
                origin = raycastOrigin(size: size, in: visible)
            }
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
        lastProgrammaticOrigin = origin
    }

    /// Raycast-style default: horizontally centered, in the upper third.
    private func raycastOrigin(size: NSSize, in visible: NSRect) -> NSPoint {
        let x = visible.midX - size.width / 2
        let y = visible.maxY - size.height - visible.height * 0.16
        return snapToGrid(NSPoint(x: x, y: y))
    }

    private func clampOrigin(_ point: NSPoint, size: NSSize, in visible: NSRect) -> NSPoint {
        NSPoint(
            x: clamp(point.x, min: visible.minX + 8, max: visible.maxX - size.width - 8),
            y: clamp(point.y, min: visible.minY + 8, max: visible.maxY - size.height - 8)
        )
    }

    private func snapToGrid(_ point: NSPoint, grid: CGFloat = 16) -> NSPoint {
        NSPoint(x: (point.x / grid).rounded() * grid, y: (point.y / grid).rounded() * grid)
    }

    /// Persists the popup's top-left (snapped to a grid) when the user drags it,
    /// and switches to "remembered" positioning so it reopens where they left it.
    private func savePopupPosition() {
        guard window.isVisible else { return }
        // Ignore our own programmatic positioning; only persist real user drags.
        if let last = lastProgrammaticOrigin, last == window.frame.origin { return }
        let snappedTop = snapToGrid(NSPoint(x: window.frame.minX, y: window.frame.maxY))
        AppSettings.shared.popupSavedTop = snappedTop
        if AppSettings.shared.popupPosition != .remembered {
            AppSettings.shared.popupPosition = .remembered
        }
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

    /// Handle keys at the panel's dispatch boundary, including events sent
    /// directly to a nonactivating panel rather than through NSApplication.
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard window.isVisible, event.window === window else { return false }
        // Only the "real" modifiers — arrow keys carry .function/.numericPad,
        // which would otherwise break exact `[]` / `.command` matches below.
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])

        // ⌘1–9 — quick-paste the Nth item.
        if flags == .command, let digit = Int(event.charactersIgnoringModifiers ?? ""), digit >= 1, digit <= 9 {
            if let item = oo.item(atNumber: digit) { commit(item) }
            return true
        }

        switch (event.keyCode, flags) {
        case (125, []): // ↓
            oo.moveSelection(by: 1)
            refreshPreviewIfVisible()
            return true
        case (126, []): // ↑
            oo.moveSelection(by: -1)
            refreshPreviewIfVisible()
            return true
        case (125, .command): // ⌘↓ — jump to last
            oo.selectLast()
            refreshPreviewIfVisible()
            return true
        case (126, .command): // ⌘↑ — jump to first
            oo.selectFirst()
            refreshPreviewIfVisible()
            return true
        case (124, []): // → — show preview for the selected item
            updatePreview(oo.selectedItem)
            return true
        case (123, []): // ← — hide preview
            updatePreview(nil)
            return true
        case (36, [.option, .shift]), (76, [.option, .shift]): // ⌥⇧↩ — paste plain
            if let item = oo.selectedItem { commit(item, plain: true) }
            return true
        case (36, _), (76, _): // Return / Enter — paste
            if let item = oo.selectedItem { commit(item) }
            return true
        case (40, .command): // ⌘K — toggle the actions menu
            oo.showActions.toggle()
            return true
        case (37, .command): // ⌘L — cycle the content-type filter
            oo.cycleScope()
            return true
        case (8, .command): // ⌘C — copy the selected item without pasting
            perform(.copy)
            return true
        case (53, _): // Esc — close the actions menu first, else hide the popup
            if oo.showActions {
                oo.showActions = false
            } else {
                hide()
            }
            return true
        case (35, .option): // ⌥P — pin / unpin
            oo.togglePinSelected()
            return true
        case (51, [.shift, .option, .command]): // ⇧⌥⌘⌫ — clear all incl. pins
            oo.clearAll()
            return true
        case (51, [.option, .command]): // ⌥⌘⌫ — clear unpinned
            oo.clearUnpinned()
            return true
        case (51, .option): // ⌥⌫ — delete item
            oo.deleteSelected()
            return true
        default:
            return false
        }
    }

    // MARK: - Commit / paste

    /// Runs an action from the ⌘K menu against the current selection.
    private func perform(_ action: PopupAction) {
        switch action {
        case .paste:
            if let item = oo.selectedItem { commit(item) }
        case .pastePlain:
            if let item = oo.selectedItem { commit(item, plain: true) }
        case .pasteTransformed(let transform):
            guard let item = oo.selectedItem else { return }
            hide()
            paster.stage(text: transform.apply(expanded(item.textToPaste)))
            finishPaste()
        case .copy:
            guard let item = oo.selectedItem else { return }
            hide()
            stage(item)
        case .pin:
            oo.togglePinSelected()
        case .delete:
            oo.deleteSelected()
        case .clearAll:
            oo.clearAll()
        }
    }

    private func commit(_ item: ClipItemDO, plain: Bool = false) {
        hide()
        stage(item, plain: plain)
        finishPaste()
    }

    /// Stages an item to the pasteboard, expanding snippet placeholders.
    private func stage(_ item: ClipItemDO, plain: Bool = false) {
        if item.kind == .snippet {
            paster.stage(text: expanded(item.textToPaste))
        } else {
            paster.stage(item: oo.withPayload(item), plain: plain)
        }
    }

    /// Expands `${…}` placeholders against the current clipboard.
    private func expanded(_ text: String) -> String {
        SnippetExpander.expand(text, clipboard: NSPasteboard.general.string(forType: .string) ?? "")
    }

    /// Shared paste tail: requires Accessibility, then re-activates the previous
    /// app and synthesizes ⌘V. The content is already on the pasteboard.
    private func finishPaste() {
        guard paster.hasAccessibilityPermission else {
            // Content is on the pasteboard; tell the user how to enable automatic
            // paste instead of silently doing nothing.
            Log.paste.error("Committed to pasteboard only — Accessibility not granted")
            handleMissingAccessibility()
            return
        }
        guard let target = previousApp, !target.isTerminated else {
            Log.paste.error("Committed to pasteboard only — no target app")
            return
        }
        reactivate(target)
        pasteWhenTargetIsFrontmost(target, generation: pasteGeneration)
    }

    /// Content is already on the pasteboard. Reopen the permission guide so a
    /// suppressed system prompt cannot leave the user without a recovery path.
    private func handleMissingAccessibility() {
        if let onAccessibilityRequired {
            onAccessibilityRequired()
            return
        }
        guard !didPromptAccessibility else { return }
        didPromptAccessibility = true
        paster.ensureAccessibilityPermission()
    }

    private func reactivate(_ target: NSRunningApplication) {
        guard !target.isActive else { return }
        if #available(macOS 14.0, *) {
            // Cooperative activation: the active app must hand focus over, or
            // the target's `activate()` request is ignored.
            NSApp.yieldActivation(to: target)
            target.activate()
        } else {
            target.activate(options: [.activateIgnoringOtherApps])
        }
    }

    /// Waits (briefly) for the previously-frontmost app to actually regain focus
    /// before synthesizing ⌘V, so paste lands in the right app even when it is
    /// slow to activate. Leaves the content on the clipboard if focus is lost.
    private func pasteWhenTargetIsFrontmost(_ target: NSRunningApplication, generation: Int, attempt: Int = 0) {
        guard generation == pasteGeneration, !window.isVisible, !target.isTerminated else { return }
        let maxAttempts = 40 // ~1s at 25ms steps
        let targetPID = target.processIdentifier
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let ready = frontPID == targetPID

        if !ready && attempt == maxAttempts / 2 {
            // Activation was refused; stepping aside hands focus back to the
            // previous app the way ⌘H would.
            NSApp.hide(nil)
        }

        if ready {
            // Becoming frontmost precedes the target's window turning key, so give
            // it a moment; otherwise ⌘V lands before there is a focused field.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self, generation == self.pasteGeneration, !self.window.isVisible else { return }
                self.paster.pasteIntoFrontmostApp(expectedPID: targetPID)
            }
        } else if attempt >= maxAttempts {
            Log.paste.error("Committed to pasteboard only — target app did not regain focus")
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { [weak self] in
                self?.pasteWhenTargetIsFrontmost(target, generation: generation, attempt: attempt + 1)
            }
        }
    }
}
