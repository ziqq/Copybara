// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import SwiftUI
import XCTest
@testable import Copybara

@MainActor
final class PopupActionTests: XCTestCase {
    private struct Popup {
        let controller: PopupController
        let window: PopupWindow
        let view: PopupView
        let store: HistoryStore
        let board: NSPasteboard
    }

    private func withPopup(_ captures: [ClipCapture] = [], snippets: [Snippet] = [],
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
            paster: Paster(pasteboard: board, accessibilityPermission: { false }),
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

    private func openActions(in popup: Popup) throws -> NSWindow {
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        popup.view.oo.showActions = true
        let deadline = Date().addingTimeInterval(2)
        var popover: NSWindow?
        while popover == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            popover = NSApp.windows.first { !existing.contains(ObjectIdentifier($0)) && $0.isVisible }
        }
        let window = try XCTUnwrap(popover)
        window.alphaValue = 0
        return window
    }
}
