// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import XCTest
@testable import Copybara

@MainActor
final class PopupPositionTests: XCTestCase {
    private func withPopup(at position: PopupPosition, savedTop: CGPoint? = nil, anchor: NSRect? = nil,
                           _ body: (PopupWindow, NSRect) throws -> Void) throws {
        let mouse = NSEvent.mouseLocation
        let screen = try XCTUnwrap(NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main)
        let defaults = UserDefaults.standard
        let originalArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        var arguments = originalArguments
        arguments["popupPosition"] = position.rawValue
        arguments["popupHasSavedTop"] = savedTop != nil
        arguments["popupTopX"] = savedTop?.x ?? 0
        arguments["popupTopY"] = savedTop?.y ?? 0
        arguments["useLiquidGlass"] = false
        // Override shared read-only preferences in this test process, without
        // writing the user's saved position or appearance to disk.
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        defer { defaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain) }

        let name = "popup-position-\(UUID())"
        let isolated = UserDefaults(suiteName: name)!
        defer { isolated.removePersistentDomain(forName: name) }
        let board = NSPasteboard(name: .init(name))
        defer { board.releaseGlobally() }
        let store = HistoryStore(stack: CoreDataStack(inMemory: true))
        store.insertTextSynchronously("sample")
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = PopupController(store: store,
            paster: Paster(pasteboard: board, accessibilityPermission: { false }),
            settings: AppSettings(defaults: isolated), snippets: SnippetStore(defaults: isolated))
        controller.anchorRectProvider = { anchor }
        let window = try XCTUnwrap(NSApp.windows.compactMap { $0 as? PopupWindow }
            .first { !existing.contains(ObjectIdentifier($0)) })
        window.alphaValue = 0
        window.hasShadow = false
        defer { controller.hide() }
        controller.show()
        try body(window, screen.visibleFrame)
    }

    func testCenterPositionCentersWindowAndUsesVibrantFallbackWhenGlassIsDisabled() throws {
        try withPopup(at: .center) { window, visible in
            XCTAssertEqual(window.frame.midX, visible.midX, accuracy: 1)
            XCTAssertEqual(window.frame.midY, visible.midY, accuracy: 1)
            let effect = try XCTUnwrap(window.contentView as? NSVisualEffectView)
            XCTAssertEqual(effect.material, .popover)
            XCTAssertEqual(effect.blendingMode, .behindWindow)
            XCTAssertEqual(effect.state, .active)
        }
    }

    func testRememberedPositionKeepsSavedTopEdge() throws {
        let mouse = NSEvent.mouseLocation
        let visible = try XCTUnwrap(NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main).visibleFrame
        let top = CGPoint(x: visible.midX, y: visible.maxY - 40)
        try withPopup(at: .remembered, savedTop: top) { window, screen in
            // The right edge is clamped if the saved left edge would overflow.
            let expectedX = min(top.x, screen.maxX - window.frame.width - 8)
            XCTAssertEqual(window.frame.minX, expectedX, accuracy: 1)
            XCTAssertEqual(window.frame.maxY, top.y, accuracy: 1)
        }
    }

    func testOffscreenSavedPositionIsClampedIntoVisibleFrame() throws {
        try withPopup(at: .remembered, savedTop: CGPoint(x: -1_000_000, y: 1_000_000)) { window, visible in
            XCTAssertEqual(window.frame.minX, visible.minX + 8, accuracy: 1)
            XCTAssertEqual(window.frame.maxY, visible.maxY - 8, accuracy: 1)
        }
    }

    func testMissingSavedPositionUsesSnappedUpperPlacement() throws {
        try withPopup(at: .remembered) { window, visible in
            XCTAssertEqual(window.frame.minX.truncatingRemainder(dividingBy: 16), 0, accuracy: 1)
            XCTAssertEqual(window.frame.minY.truncatingRemainder(dividingBy: 16), 0, accuracy: 1)
            XCTAssertGreaterThan(window.frame.midY, visible.midY)
        }
    }

    func testMenuBarAnchorPlacesPopupBelowIcon() throws {
        let mouse = NSEvent.mouseLocation
        let screen = try XCTUnwrap(NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main)
        let anchor = NSRect(x: screen.visibleFrame.midX - 10, y: screen.visibleFrame.maxY, width: 20, height: 20)
        try withPopup(at: .menuBarIcon, anchor: anchor) { window, _ in
            XCTAssertEqual(window.frame.midX, anchor.midX, accuracy: 1)
            XCTAssertEqual(window.frame.maxY, anchor.minY - 6, accuracy: 1)
        }
    }

    func testInvalidMenuBarAnchorsFallBackToCursorInsideVisibleFrame() throws {
        for anchor in [nil, NSRect.zero, NSRect(x: -1_000_000, y: -1_000_000, width: 20, height: 20)] {
            try withPopup(at: .menuBarIcon, anchor: anchor) { window, visible in
                XCTAssertTrue(visible.insetBy(dx: 7, dy: 7).contains(window.frame))
            }
        }
    }

    func testCursorPositionStaysInsideVisibleFrame() throws {
        try withPopup(at: .cursor) { window, visible in
            XCTAssertTrue(visible.insetBy(dx: 7, dy: 7).contains(window.frame))
        }
    }
}
