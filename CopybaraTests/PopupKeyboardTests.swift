// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import SwiftUI
import XCTest
@testable import Copybara

@MainActor
final class PopupKeyboardTests: XCTestCase {
    private final class SearchResponder: NSView {
        var received: [NSEvent] = []
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) { received.append(event) }
    }

    private func withPopup(_ body: (PopupController, PopupWindow, NSPasteboard, SearchResponder) throws -> Void) throws {
        let defaults = UserDefaults(suiteName: "popup-keys-\(UUID())")!
        let board = NSPasteboard(name: .init("popup-keys-\(UUID())"))
        let store = HistoryStore(stack: CoreDataStack(inMemory: true))
        for text in ["first", "second", "third"] { store.insertTextSynchronously(text) }
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = PopupController(store: store,
                                         paster: Paster(pasteboard: board, accessibilityPermission: { false }),
                                         settings: AppSettings(defaults: defaults),
                                         snippets: SnippetStore(defaults: defaults))
        controller.onAccessibilityRequired = {}
        let window = try XCTUnwrap(NSApp.windows.compactMap { $0 as? PopupWindow }
            .first { !existing.contains(ObjectIdentifier($0)) })
        // No diagnostic windows or clipboard history appear on the desktop.
        window.alphaValue = 0
        window.hasShadow = false
        defer { controller.hide(); board.releaseGlobally() }
        controller.show()
        let responder = SearchResponder()
        window.contentView = responder
        XCTAssertTrue(window.makeFirstResponder(responder))
        try body(controller, window, board, responder)
    }

    private func key(_ code: UInt16, window: NSWindow, flags: NSEvent.ModifierFlags = [],
                     characters: String = "", repeatKey: Bool = false) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                                      timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                      characters: characters, charactersIgnoringModifiers: characters,
                                      isARepeat: repeatKey, keyCode: code))
    }

    func testPanelDispatchConsumesArrowsBeforeSearchAndCommitsSelection() throws {
        try withPopup { _, window, board, search in
            let arrowFlags: NSEvent.ModifierFlags = [.function, .numericPad]
            window.sendEvent(try key(125, window: window, flags: arrowFlags))
            window.sendEvent(try key(125, window: window, flags: arrowFlags, repeatKey: true))
            window.sendEvent(try key(126, window: window, flags: arrowFlags))
            XCTAssertTrue(search.received.isEmpty, "arrows must navigate history rather than the focused search field")
            window.sendEvent(try key(36, window: window, characters: "\r"))
            XCTAssertEqual(board.string(forType: .string), "second")
        }
    }

    func testCommandArrowsAndCopyAreHandledAsPanelKeyEquivalents() throws {
        try withPopup { _, window, board, search in
            XCTAssertTrue(window.performKeyEquivalent(with: try key(125, window: window,
                                                                    flags: [.command, .function, .numericPad])))
            XCTAssertTrue(window.performKeyEquivalent(with: try key(8, window: window, flags: .command, characters: "c")))
            XCTAssertEqual(board.string(forType: .string), "first")
            XCTAssertTrue(search.received.isEmpty)
        }
        try withPopup { _, window, board, _ in
            window.sendEvent(try key(125, window: window))
            XCTAssertTrue(window.performKeyEquivalent(with: try key(126, window: window,
                                                                    flags: [.command, .function, .numericPad])))
            window.sendEvent(try key(36, window: window, characters: "\r"))
            XCTAssertEqual(board.string(forType: .string), "third")
        }
    }

    func testOrdinaryTypingAndModifiedArrowsStillReachSearch() throws {
        try withPopup { _, window, _, search in
            window.sendEvent(try key(0, window: window, characters: "a"))
            window.sendEvent(try key(126, window: window, flags: [.shift, .function, .numericPad]))
            XCTAssertEqual(search.received.map(\.keyCode), [0, 126])
        }
    }

    func testEscapeClosesPanelWithoutReachingSearch() throws {
        try withPopup { controller, window, _, search in
            window.sendEvent(try key(53, window: window, characters: "\u{1B}"))
            XCTAssertFalse(controller.isVisible)
            XCTAssertTrue(search.received.isEmpty)
        }
    }

    func testCommandNumberPastesRequestedRowAndIgnoresMissingRow() throws {
        try withPopup { controller, window, board, search in
            XCTAssertTrue(window.performKeyEquivalent(with: try key(25, window: window, flags: .command, characters: "9")))
            XCTAssertTrue(controller.isVisible)
            XCTAssertNil(board.string(forType: .string))
            XCTAssertTrue(window.performKeyEquivalent(with: try key(19, window: window, flags: .command, characters: "2")))
            XCTAssertEqual(board.string(forType: .string), "second")
            XCTAssertFalse(controller.isVisible)
            XCTAssertTrue(search.received.isEmpty)
        }
    }

    func testEscapeDismissesActionsBeforeClosingPopup() throws {
        try withPopup { controller, window, _, search in
            XCTAssertTrue(window.performKeyEquivalent(with: try key(40, window: window, flags: .command, characters: "k")))
            window.sendEvent(try key(53, window: window))
            XCTAssertTrue(controller.isVisible)
            window.sendEvent(try key(53, window: window))
            XCTAssertFalse(controller.isVisible)
            XCTAssertTrue(search.received.isEmpty)
        }
    }

    func testDeleteShortcutRemovesSelectedRowBeforePaste() throws {
        try withPopup { _, window, board, search in
            window.sendEvent(try key(51, window: window, flags: .option))
            window.sendEvent(try key(36, window: window))
            XCTAssertEqual(board.string(forType: .string), "second")
            XCTAssertTrue(search.received.isEmpty)
        }
    }

    func testClearUnpinnedShortcutKeepsFavorite() throws {
        try withPopup { _, window, board, search in
            window.sendEvent(try key(35, window: window, flags: .option, characters: "p"))
            window.sendEvent(try key(125, window: window))
            window.sendEvent(try key(51, window: window, flags: [.option, .command]))
            window.sendEvent(try key(36, window: window))
            XCTAssertEqual(board.string(forType: .string), "third")
            XCTAssertTrue(search.received.isEmpty)
        }
    }

    func testClearAllShortcutAlsoRemovesFavorite() throws {
        try withPopup { controller, window, board, search in
            window.sendEvent(try key(35, window: window, flags: .option, characters: "p"))
            window.sendEvent(try key(51, window: window, flags: [.shift, .option, .command]))
            window.sendEvent(try key(36, window: window))
            XCTAssertNil(board.string(forType: .string))
            XCTAssertTrue(controller.isVisible, "Return on an empty list must not commit anything")
            XCTAssertTrue(search.received.isEmpty)
        }
    }

    func testScopeShortcutPreventsPastingHiddenTextRows() throws {
        try withPopup { controller, window, board, search in
            for _ in 0..<2 {
                XCTAssertTrue(window.performKeyEquivalent(with: try key(37, window: window, flags: .command, characters: "l")))
            }
            window.sendEvent(try key(36, window: window))
            XCTAssertNil(board.string(forType: .string))
            XCTAssertTrue(controller.isVisible)
            XCTAssertTrue(search.received.isEmpty)
        }
    }

    func testPlainPasteShortcutAcceptsBothReturnAndKeypadEnter() throws {
        for code: UInt16 in [36, 76] {
            try withPopup { controller, window, board, search in
                window.sendEvent(try key(code, window: window, flags: [.option, .shift], characters: "\r"))
                XCTAssertEqual(board.string(forType: .string), "third")
                XCTAssertNil(board.data(forType: .rtf))
                XCTAssertFalse(controller.isVisible)
                XCTAssertTrue(search.received.isEmpty)
            }
        }
    }

    func testArrowPreviewTracksSelectionAndHidesOnLeftArrow() throws {
        try withPopup { _, window, _, search in
            let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
            window.sendEvent(try key(124, window: window))
            let panel = try XCTUnwrap(NSApp.windows.compactMap { $0 as? NSPanel }
                .first { !existing.contains(ObjectIdentifier($0)) })
            panel.alphaValue = 0
            defer { panel.orderOut(nil) }
            let hosting = try XCTUnwrap(panel.contentView as? NSHostingView<PreviewCard>)
            XCTAssertEqual(hosting.rootView.item.preview, "third")
            let shown = expectation(description: "preview ordered after layout")
            DispatchQueue.main.async { shown.fulfill() }
            wait(for: [shown], timeout: 2)
            XCTAssertTrue(panel.isVisible)

            window.sendEvent(try key(125, window: window))
            XCTAssertEqual(hosting.rootView.item.preview, "second")
            window.sendEvent(try key(123, window: window))
            XCTAssertFalse(panel.isVisible)
            XCTAssertTrue(search.received.isEmpty)
        }
    }
}
