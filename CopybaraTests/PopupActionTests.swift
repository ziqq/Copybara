// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import SwiftUI
import XCTest
@testable import Copybara

@MainActor
final class PopupActionTests: XCTestCase {
    private static var mouseEventNumber = 0

    private final class TargetApplication: NSRunningApplication, @unchecked Sendable {
        var hasExited = false
        var identityReads = 0
        var terminationReads = 0
        var onExitObserved: (() -> Void)?
        override var processIdentifier: pid_t { identityReads += 1; return 2_000_000 }
        override var isTerminated: Bool {
            terminationReads += 1
            if hasExited { onExitObserved?() }
            return hasExited
        }
        // The fixture never asks macOS to activate another application.
        override var isActive: Bool { true }
    }

    private struct Popup {
        let controller: PopupController
        let window: PopupWindow
        let view: PopupView
        let store: HistoryStore
        let board: NSPasteboard
    }

    private func withPopup(_ captures: [ClipCapture] = [], snippets: [Snippet] = [],
                           permission: Bool = false,
                           postEvent: @escaping (CGEvent, CGEventTapLocation) -> Void = { _, _ in },
                           _ body: (Popup) throws -> Void) throws {
        let name = "popup-actions-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        let board = NSPasteboard(name: .init(name))
        let store = HistoryStore(stack: CoreDataStack(inMemory: true))
        for capture in captures { store.insertSynchronously(capture) }
        let snippetStore = SnippetStore(defaults: defaults)
        snippetStore.save(snippets)
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = PopupController(store: store,
            paster: Paster(pasteboard: board, accessibilityPermission: { permission },
                           frontmostPID: { nil }, postEvent: postEvent),
            settings: AppSettings(defaults: defaults), snippets: snippetStore)
        controller.onAccessibilityRequired = {}
        defer {
            controller.hide()
            board.releaseGlobally()
            defaults.removePersistentDomain(forName: name)
        }
        let window = try XCTUnwrap(NSApp.windows.compactMap { $0 as? PopupWindow }
            .first { !existing.contains(ObjectIdentifier($0)) })
        window.alphaValue = 0
        window.hasShadow = false
        // Synthetic control clicks must not start native window dragging.
        window.isMovableByWindowBackground = false
        controller.show()
        var views = [try XCTUnwrap(window.contentView)]
        var hosting: NSHostingView<PopupView>?
        while let view = views.popLast() {
            if let match = view as? NSHostingView<PopupView> { hosting = match; break }
            views.append(contentsOf: view.subviews)
        }
        let view = try XCTUnwrap(hosting).rootView
        try body(Popup(controller: controller, window: window, view: view, store: store, board: board))
    }

    private func text(_ value: String) -> ClipCapture {
        ClipCapture(kind: .text, text: value, data: nil, contentHash: nil, appBundleID: nil)
    }

    func testPasteActionStagesSelectionAndReportsMissingPermission() throws {
        try withPopup([text("selected")]) { popup in
            var prompts = 0
            popup.controller.onAccessibilityRequired = { prompts += 1 }
            popup.view.onAction(.paste)
            XCTAssertEqual(popup.board.string(forType: .string), "selected")
            XCTAssertFalse(popup.controller.isVisible)
            XCTAssertEqual(prompts, 1)
        }
    }

    func testClickingFooterPasteStagesSelectedClip() throws {
        try withPopup([text("paste from footer")]) { popup in
            let committed = expectation(description: "footer paste reaches permission recovery")
            popup.controller.onAccessibilityRequired = { committed.fulfill() }
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            let content = try XCTUnwrap(popup.window.contentView)
            content.layoutSubtreeIfNeeded()
            let footerButtons = controlClickPoints(in: content).filter {
                $0.y < PopupMetrics.footerHeight && $0.x > PopupMetrics.width / 2
            }
            let paste = try XCTUnwrap(footerButtons.min { $0.x < $1.x })
            try click(paste, in: popup.window)
            wait(for: [committed], timeout: 2)
            XCTAssertEqual(popup.board.string(forType: .string), "paste from footer")
            XCTAssertFalse(popup.controller.isVisible)
        }
    }

    func testClickingTypeFilterRestoresAllResults() throws {
        let image = ClipCapture(kind: .image, text: "image", data: nil, contentHash: "image", appBundleID: nil)
        try withPopup([text("note"), image]) { popup in
            popup.view.oo.scope = .image
            let deadline = Date().addingTimeInterval(2)
            while abs(popup.window.frame.height - PopupMetrics.totalHeight(for: 1)) > 1, Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            }
            XCTAssertEqual(popup.view.oo.results.map(\.kind), [.image])
            let content = try XCTUnwrap(popup.window.contentView)
            let y = content.bounds.height - PopupMetrics.searchHeight / 2
            try click(NSPoint(x: PopupMetrics.width - 35, y: y), in: popup.window)
            XCTAssertEqual(popup.view.oo.scope, .all)
            XCTAssertEqual(Set(popup.view.oo.results.map(\.kind)), [.text, .image])
            XCTAssertTrue(popup.controller.isVisible)
            XCTAssertNil(popup.board.string(forType: .string))
        }
    }

    func testClickingActionsThenPasteRunsMenuActionAndClosesPopup() throws {
        let attributed = NSAttributedString(string: "paste from actions", attributes: [.foregroundColor: NSColor.red])
        let data = try XCTUnwrap(attributed.rtf(from: NSRange(location: 0, length: attributed.length), documentAttributes: [:]))
        let capture = ClipCapture(kind: .rtf, text: attributed.string, data: data, contentHash: data.sha256Hex, appBundleID: nil)
        try withPopup([capture]) { popup in
            let committed = expectation(description: "action row committed")
            popup.controller.onAccessibilityRequired = { committed.fulfill() }
            let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
            try click(NSPoint(x: PopupMetrics.width - 70, y: PopupMetrics.footerHeight / 2), in: popup.window)
            let menu = try waitForPopover(excluding: existing)
            defer { popup.view.oo.showActions = false; menu.orderOut(nil) }
            XCTAssertTrue(popup.view.oo.showActions)
            let content = try XCTUnwrap(menu.contentView)
            let firstAction = try XCTUnwrap(controlClickPoints(in: content).max { $0.y < $1.y })
            try click(firstAction, in: menu)
            wait(for: [committed], timeout: 2)
            XCTAssertEqual(popup.board.string(forType: .string), "paste from actions")
            XCTAssertEqual(popup.board.data(forType: .rtf), data)
            XCTAssertFalse(popup.view.oo.showActions)
            XCTAssertFalse(popup.controller.isVisible)
        }
    }

    func testRowContextMenuCopiesClickedRowInsteadOfKeyboardSelection() throws {
        try withPopup([text("first"), text("second")]) { popup in
            let menu = try rowMenu(at: 1, in: popup)
            let index = try XCTUnwrap(menu.items.firstIndex { $0.title == L10n.string("Copy") })
            XCTAssertEqual(popup.view.oo.selectedItem?.preview, "second")
            menu.performActionForItem(at: index)
            XCTAssertEqual(popup.board.string(forType: .string), "first")
            XCTAssertFalse(popup.controller.isVisible)
        }
    }

    func testRowContextMenuPinAndUnpinKeepOtherRowsAndPasteboardIntact() throws {
        try withPopup([text("first"), text("second")]) { popup in
            let targetID = try XCTUnwrap(popup.view.oo.results.first { $0.preview == "first" }?.id)
            let menu = try rowMenu(at: 1, in: popup)
            let pin = try XCTUnwrap(menu.items.firstIndex { $0.title == L10n.string("Pin") })
            menu.performActionForItem(at: pin)
            XCTAssertEqual(popup.store.recentItems().first?.id, targetID)
            XCTAssertEqual(popup.store.recentItems().first?.isPinned, true)
            let unpinMenu = try rowMenu(at: 0, in: popup)
            let unpin = try XCTUnwrap(unpinMenu.items.firstIndex { $0.title == L10n.string("Unpin") })
            unpinMenu.performActionForItem(at: unpin)
            XCTAssertEqual(popup.store.count(), 2)
            XCTAssertTrue(popup.store.recentItems().allSatisfy { !$0.isPinned })
            XCTAssertNil(popup.board.string(forType: .string))
            XCTAssertTrue(popup.controller.isVisible)
        }
    }

    func testRowContextMenuDeletePreservesSelectedRow() throws {
        try withPopup([text("first"), text("second")]) { popup in
            let selectedID = popup.view.oo.selectedItem?.id
            let menu = try rowMenu(at: 1, in: popup)
            let delete = try XCTUnwrap(menu.items.firstIndex { $0.title == L10n.string("Delete") })
            menu.performActionForItem(at: delete)
            XCTAssertEqual(popup.store.recentItems().map(\.preview), ["second"])
            XCTAssertEqual(popup.view.oo.selectedItem?.id, selectedID)
            XCTAssertNil(popup.board.string(forType: .string))
            XCTAssertTrue(popup.controller.isVisible)
        }
    }

    func testRowContextMenuRichAndPlainPasteUseClickedPayload() throws {
        let attributed = NSAttributedString(string: "rich clicked row", attributes: [.foregroundColor: NSColor.red])
        let data = try XCTUnwrap(attributed.rtf(from: NSRange(location: 0, length: attributed.length), documentAttributes: [:]))
        let capture = ClipCapture(kind: .rtf, text: attributed.string, data: data, contentHash: data.sha256Hex, appBundleID: nil)
        for (title, plain) in [("Paste", false), ("Paste as Plain Text", true)] {
            try withPopup([capture, text("keyboard selection")]) { popup in
                let committed = expectation(description: "context menu paste committed")
                popup.controller.onAccessibilityRequired = { committed.fulfill() }
                let menu = try rowMenu(at: 1, in: popup)
                let index = try XCTUnwrap(menu.items.firstIndex { $0.title == L10n.string(title) })
                menu.performActionForItem(at: index)
                wait(for: [committed], timeout: 2)
                XCTAssertEqual(popup.board.string(forType: .string), attributed.string)
                XCTAssertEqual(popup.board.data(forType: .rtf), plain ? nil : data)
                XCTAssertFalse(popup.controller.isVisible)
            }
        }
    }

    func testSnippetContextMenuOmitsPinAndDeletePreservesHistory() throws {
        try withPopup([text("history")], snippets: [Snippet(title: "Signature", content: "template")]) { popup in
            let menu = try rowMenu(at: 0, in: popup)
            XCTAssertNil(menu.item(withTitle: L10n.string("Pin")))
            XCTAssertNil(menu.item(withTitle: L10n.string("Unpin")))
            let delete = try XCTUnwrap(menu.items.firstIndex { $0.title == L10n.string("Delete") })
            menu.performActionForItem(at: delete)
            XCTAssertEqual(popup.view.oo.results.map(\.preview), ["history"])
            XCTAssertEqual(popup.store.recentItems().map(\.preview), ["history"])
            XCTAssertTrue(popup.controller.isVisible)
        }
    }

    func testCommitCallbackStagesClickedItemInsteadOfCurrentSelection() throws {
        try withPopup([text("first"), text("second")]) { popup in
            XCTAssertEqual(popup.view.oo.selectedItem?.preview, "second")
            let clicked = try XCTUnwrap(popup.view.oo.results.first { $0.preview == "first" })
            popup.view.onCommit(clicked)
            XCTAssertEqual(popup.board.string(forType: .string), "first")
            XCTAssertFalse(popup.controller.isVisible)
        }
    }

    func testPlainPasteActionLoadsRichPayloadButStripsFormatting() throws {
        let attributed = NSAttributedString(string: "rich text", attributes: [.foregroundColor: NSColor.red])
        let data = try XCTUnwrap(attributed.rtf(from: NSRange(location: 0, length: attributed.length), documentAttributes: [:]))
        let capture = ClipCapture(kind: .rtf, text: "rich text", data: data, contentHash: data.sha256Hex, appBundleID: nil)
        try withPopup([capture]) { popup in
            XCTAssertNil(popup.view.oo.selectedItem?.data)
            popup.view.onAction(.pastePlain)
            XCTAssertEqual(popup.board.string(forType: .string), "rich text")
            XCTAssertNil(popup.board.data(forType: .rtf))
        }
    }

    func testCopyActionPreservesRichPayloadWithoutRequestingPermission() throws {
        let capture = ClipCapture(kind: .rtf, text: "rich", data: Data([1, 2]), contentHash: "rich", appBundleID: nil)
        try withPopup([capture]) { popup in
            var prompts = 0
            popup.controller.onAccessibilityRequired = { prompts += 1 }
            popup.view.onAction(.copy)
            XCTAssertEqual(popup.board.data(forType: .rtf), capture.data)
            XCTAssertEqual(popup.board.string(forType: .string), "rich")
            XCTAssertFalse(popup.controller.isVisible)
            XCTAssertEqual(prompts, 0)
        }
    }

    func testTransformedPasteActionsApplyToSelectedText() throws {
        for (transform, expected) in [(TextTransform.trimmed, "HeLLo"), (.lowercased, "  hello\n"), (.uppercased, "  HELLO\n")] {
            try withPopup([text("  HeLLo\n")]) { popup in
                popup.view.onAction(.pasteTransformed(transform))
                XCTAssertEqual(popup.board.string(forType: .string), expected)
                XCTAssertFalse(popup.controller.isVisible)
            }
        }
    }

    func testSnippetCopyUsesContentInsteadOfDisplayedTitle() throws {
        try withPopup(snippets: [Snippet(title: "Signature", content: "Best regards")]) { popup in
            popup.view.onAction(.copy)
            XCTAssertEqual(popup.board.string(forType: .string), "Best regards")
        }
    }

    func testPinDeleteAndClearActionsUpdateBothListAndStore() throws {
        try withPopup([text("first"), text("second")]) { popup in
            let selected = try XCTUnwrap(popup.view.oo.selectedItem)
            popup.view.onAction(.pin)
            XCTAssertEqual(popup.store.recentItems().first?.id, selected.id)
            XCTAssertEqual(popup.store.recentItems().first?.isPinned, true)
            popup.view.onAction(.delete)
            XCTAssertEqual(popup.view.oo.results.map(\.preview), ["first"])
            XCTAssertEqual(popup.store.recentItems().map(\.preview), ["first"])
            popup.view.onAction(.pin)
            popup.view.onAction(.clearAll)
            XCTAssertTrue(popup.view.oo.results.isEmpty)
            XCTAssertEqual(popup.store.count(), 0)
            XCTAssertTrue(popup.controller.isVisible)
        }
    }

    func testActionsWithNoSelectionLeavePopupAndPasteboardAlone() throws {
        try withPopup { popup in
            popup.board.setString("unchanged", forType: .string)
            for action in [PopupAction.paste, .pastePlain, .pasteTransformed(.trimmed), .copy, .pin, .delete] {
                popup.view.onAction(action)
                XCTAssertTrue(popup.controller.isVisible)
                XCTAssertEqual(popup.board.string(forType: .string), "unchanged")
            }
        }
    }

    func testHoverPreviewLoadsFilePayloadAndDismissesWithPopup() throws {
        let paths = ["/tmp/first.txt", "/tmp/second.txt"]
        let data = try XCTUnwrap(FilePayload.archive(paths))
        let capture = ClipCapture(kind: .file, text: "first.txt, second.txt", data: data, contentHash: "files", appBundleID: nil)
        try withPopup([capture]) { popup in
            let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
            popup.view.onHoverPreview(try XCTUnwrap(popup.view.oo.selectedItem))
            let panel = try XCTUnwrap(NSApp.windows.compactMap { $0 as? NSPanel }
                .first { !existing.contains(ObjectIdentifier($0)) })
            panel.alphaValue = 0
            defer { panel.orderOut(nil) }
            let hosting = try XCTUnwrap(panel.contentView as? NSHostingView<PreviewCard>)
            XCTAssertEqual(hosting.rootView.item.data.flatMap(FilePayload.paths(from:)), paths)
            let shown = expectation(description: "file preview displayed")
            DispatchQueue.main.async { shown.fulfill() }
            wait(for: [shown], timeout: 2)
            XCTAssertTrue(panel.isVisible)
            XCTAssertGreaterThan(panel.frame.height, 0)
            popup.controller.hide()
            XCTAssertFalse(panel.isVisible)
        }
    }

    func testActionsPopoverAppearsAndClosesWhenCopyHidesPopup() throws {
        try withPopup([text("selected")]) { popup in
            let window = try openActions(in: popup)
            defer { popup.view.oo.showActions = false; window.orderOut(nil) }
            XCTAssertGreaterThan(window.frame.height, 100)
            popup.view.onAction(.copy)
            let deadline = Date().addingTimeInterval(2)
            while window.isVisible, Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            }
            XCTAssertFalse(popup.controller.isVisible)
            XCTAssertFalse(window.isVisible)
            XCTAssertEqual(popup.board.string(forType: .string), "selected")
        }
    }

    func testActionsMenuAdaptsVisibleRowsToTextImagesAndSnippets() throws {
        var textHeight: CGFloat = 0, imageHeight: CGFloat = 0, snippetHeight: CGFloat = 0
        try withPopup([text("text")]) { popup in
            let menu = try openActions(in: popup)
            defer { popup.view.oo.showActions = false; menu.orderOut(nil) }
            textHeight = menu.frame.height
        }
        let image = ClipCapture(kind: .image, text: "Image", data: nil, contentHash: "image", appBundleID: nil)
        try withPopup([image]) { popup in
            let menu = try openActions(in: popup)
            defer { popup.view.oo.showActions = false; menu.orderOut(nil) }
            imageHeight = menu.frame.height
        }
        try withPopup(snippets: [Snippet(title: "Snippet", content: "content")]) { popup in
            let menu = try openActions(in: popup)
            defer { popup.view.oo.showActions = false; menu.orderOut(nil) }
            snippetHeight = menu.frame.height
        }
        XCTAssertGreaterThan(textHeight, snippetHeight, "snippets must omit the Pin row")
        XCTAssertGreaterThan(snippetHeight, imageHeight, "text-like snippets must include the text transformations")
    }

    func testReopeningPopupCancelsPendingPasteIntoPreviousApplication() throws {
        var posted = 0
        try withPopup([text("staged but cancelled")], permission: true, postEvent: { _, _ in posted += 1 }) { popup in
            let target = TargetApplication()
            try remember(target)
            popup.view.onAction(.paste)
            XCTAssertEqual(popup.board.string(forType: .string), "staged but cancelled")
            XCTAssertFalse(popup.controller.isVisible)

            popup.controller.show()
            let readsBeforeRetry = target.terminationReads
            waitForFocusRetries()
            XCTAssertEqual(target.terminationReads, readsBeforeRetry,
                           "a cancelled generation must not continue checking the old destination")
            XCTAssertTrue(popup.controller.isVisible)
            XCTAssertEqual(posted, 0)
            XCTAssertEqual(popup.board.string(forType: .string), "staged but cancelled")
        }
    }

    func testTerminatedDestinationKeepsStagedTextWithoutPastingOrPrompting() throws {
        var posted = 0
        try withPopup([text("manual paste")], permission: true, postEvent: { _, _ in posted += 1 }) { popup in
            let target = TargetApplication()
            target.hasExited = true
            try remember(target)
            var prompts = 0
            popup.controller.onAccessibilityRequired = { prompts += 1 }
            popup.view.onAction(.paste)
            XCTAssertFalse(popup.controller.isVisible)
            XCTAssertEqual(popup.board.string(forType: .string), "manual paste")
            XCTAssertEqual(posted, 0)
            XCTAssertEqual(prompts, 0)
        }
    }

    func testDestinationExitingDuringFocusWaitStopsFurtherRetries() throws {
        var posted = 0
        try withPopup([text("manual paste")], permission: true, postEvent: { _, _ in posted += 1 }) { popup in
            let target = TargetApplication()
            try remember(target)
            popup.view.onAction(.paste)
            XCTAssertGreaterThanOrEqual(target.terminationReads, 2,
                                        "the live destination must enter the focus-wait path")
            let exitObserved = expectation(description: "focus retry observes destination exit")
            target.onExitObserved = { exitObserved.fulfill() }
            target.hasExited = true
            wait(for: [exitObserved], timeout: 2)
            target.onExitObserved = nil
            let readsAfterExit = target.terminationReads
            waitForFocusRetries()
            XCTAssertEqual(target.terminationReads, readsAfterExit)
            XCTAssertEqual(posted, 0)
            XCTAssertEqual(popup.board.string(forType: .string), "manual paste")
            XCTAssertFalse(popup.controller.isVisible)
        }
    }

    func testFocusTimeoutLeavesContentForManualPasteAndStopsRetrying() throws {
        var posted = 0
        try withPopup([text("focus never returned")], permission: true, postEvent: { _, _ in posted += 1 }) { popup in
            defer { NSApp.unhideWithoutActivation() }
            let target = TargetApplication()
            try remember(target)
            var prompts = 0
            popup.controller.onAccessibilityRequired = { prompts += 1 }
            popup.view.onAction(.paste)

            // Allow the complete focus-recovery budget, including the fallback
            // that hides Copybara, rather than cancelling after the first retry.
            let elapsed = expectation(description: "focus recovery budget elapsed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { elapsed.fulfill() }
            wait(for: [elapsed], timeout: 4)
            let readsAfterTimeout = target.terminationReads
            XCTAssertGreaterThan(readsAfterTimeout, 20, "the destination must be retried through the fallback")
            waitForFocusRetries()

            XCTAssertEqual(target.terminationReads, readsAfterTimeout, "focus retries must stop after the timeout")
            XCTAssertTrue(NSApp.isHidden, "failed activation must let the destination regain focus")
            XCTAssertFalse(popup.controller.isVisible)
            XCTAssertEqual(popup.board.string(forType: .string), "focus never returned")
            XCTAssertEqual(posted, 0, "a different foreground application must never receive the paste")
            XCTAssertEqual(prompts, 0, "a focus failure must not be reported as missing permission")
        }
    }

    func testHidingPopupBeforeDeferredPreviewLayoutDoesNotShowOrphanPanel() throws {
        try withPopup([text("preview cancelled")]) { popup in
            let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
            popup.view.onHoverPreview(try XCTUnwrap(popup.view.oo.selectedItem))
            let panel = try XCTUnwrap(NSApp.windows.compactMap { $0 as? NSPanel }
                .first { !existing.contains(ObjectIdentifier($0)) })
            panel.alphaValue = 0
            defer { panel.orderOut(nil) }
            popup.controller.hide()
            let laidOut = expectation(description: "deferred preview layout completed")
            DispatchQueue.main.async { laidOut.fulfill() }
            wait(for: [laidOut], timeout: 2)
            XCTAssertFalse(panel.isVisible, "a queued preview must not reopen after its popup was dismissed")
            XCTAssertFalse(popup.controller.isVisible)
            XCTAssertNil(popup.board.string(forType: .string))
        }
    }

    func testPreviewFlipsLeftWhenPopupIsAtRightScreenEdge() throws {
        try withPopup([text("edge preview")]) { popup in
            let mouse = NSEvent.mouseLocation
            let screen = try XCTUnwrap(NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main)
            let visible = screen.visibleFrame
            let defaults = UserDefaults.standard
            let originalArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
            var arguments = originalArguments
            arguments["popupPosition"] = PopupPosition.menuBarIcon.rawValue
            defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            defer { defaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain) }
            // Use the normal anchor calculation so deferred layouts keep the
            // same position, without writing the user's saved window position.
            popup.controller.anchorRectProvider = {
                NSRect(x: visible.maxX - 20, y: visible.maxY, width: 20, height: 20)
            }
            popup.controller.show()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
            popup.view.onHoverPreview(try XCTUnwrap(popup.view.oo.selectedItem))
            let panel = try XCTUnwrap(NSApp.windows.compactMap { $0 as? NSPanel }
                .first { !existing.contains(ObjectIdentifier($0)) })
            panel.alphaValue = 0
            defer { panel.orderOut(nil) }
            let laidOut = expectation(description: "preview placed beside popup")
            DispatchQueue.main.async { laidOut.fulfill() }
            wait(for: [laidOut], timeout: 2)
            XCTAssertTrue(panel.isVisible)
            XCTAssertEqual(panel.frame.maxX, popup.window.frame.minX - 8, accuracy: 1)
            XCTAssertTrue(visible.contains(panel.frame), "the preview must remain inside the visible screen")
            XCTAssertNil(popup.board.string(forType: .string))
        }
    }

    private func waitForFocusRetries() {
        let elapsed = expectation(description: "several focus-retry intervals elapse")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { elapsed.fulfill() }
        wait(for: [elapsed], timeout: 2)
    }

    private func click(_ point: NSPoint, in window: NSWindow) throws {
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        window.contentView?.layoutSubtreeIfNeeded()
        Self.mouseEventNumber += 2
        let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: Self.mouseEventNumber - 1, clickCount: 1, pressure: 1))
        let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime + 0.01, windowNumber: window.windowNumber,
            context: nil, eventNumber: Self.mouseEventNumber, clickCount: 1, pressure: 0))
        NSApp.sendEvent(down)
        NSApp.sendEvent(up)
    }

    private func rowPoint(at index: Int, in popup: Popup) throws -> NSPoint {
        let content = try XCTUnwrap(popup.window.contentView)
        let height = PopupMetrics.totalHeight(for: popup.view.oo.results.count)
        let deadline = Date().addingTimeInterval(2)
        repeat {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            content.layoutSubtreeIfNeeded()
        } while abs(content.bounds.height - height) > 1 && Date() < deadline
        return NSPoint(x: 180, y: content.bounds.height - PopupMetrics.searchHeight - 6 - PopupMetrics.rowHeight * (CGFloat(index) + 0.5))
    }

    private func controlClickPoints(in content: NSView) -> [NSPoint] {
        var views = content.subviews
        var points: [NSPoint] = []
        while let view = views.popLast() {
            if (16...60).contains(view.bounds.height), view.bounds.width > 40 {
                // The left quarter lies on a plain button's label, rather
                // than the noninteractive gap before its shortcut keycap.
                let point = NSPoint(x: view.bounds.minX + view.bounds.width / 4, y: view.bounds.midY)
                points.append(view.convert(point, to: nil))
            }
            views.append(contentsOf: view.subviews)
        }
        return points
    }

    private func rowMenu(at index: Int, in popup: Popup) throws -> NSMenu {
        let point = try rowPoint(at: index, in: popup)
        let content = try XCTUnwrap(popup.window.contentView)
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: popup.window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        var hit = content.hitTest(content.convert(point, from: nil))
        var contextMenu: NSMenu?
        while let view = hit, contextMenu == nil {
            contextMenu = view.menu(for: event)
            hit = view.superview
        }
        let menu = try XCTUnwrap(contextMenu)
        menu.update()
        return menu
    }

    private func remember(_ target: TargetApplication) throws {
        let readsBeforeNotification = target.identityReads
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification,
            object: nil, userInfo: [NSWorkspace.applicationUserInfoKey: target])
        let deadline = Date().addingTimeInterval(2)
        while target.identityReads == readsBeforeNotification, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        _ = try XCTUnwrap(target.identityReads > readsBeforeNotification ? target : nil,
                          "the workspace notification must reach the popup controller before a paste")
    }

    private func openActions(in popup: Popup) throws -> NSWindow {
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        popup.view.oo.showActions = true
        return try waitForPopover(excluding: existing)
    }

    private func waitForPopover(excluding existing: Set<ObjectIdentifier>) throws -> NSWindow {
        let deadline = Date().addingTimeInterval(2)
        var popover: NSWindow?
        while popover == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            popover = NSApp.windows.first {
                !existing.contains(ObjectIdentifier($0)) && $0.isVisible && (240...300).contains($0.frame.width)
            }
        }
        let window = try XCTUnwrap(popover)
        window.alphaValue = 0
        return window
    }
}
