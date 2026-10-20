// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import XCTest
@testable import Copybara

@MainActor
final class SharedPopupPositionIntegrationTests: XCTestCase {
    func testMovingVisiblePopupSavesPositionAndReopensThereWithoutRecordingHiddenMoves() throws {
        try IsolatedTestHost.require()
        let settings = AppSettings.shared
        let originalPosition = settings.popupPosition
        let originalTop = settings.popupSavedTop
        let originalGlass = settings.useLiquidGlass
        defer {
            settings.popupPosition = originalPosition
            settings.popupSavedTop = originalTop
            settings.useLiquidGlass = originalGlass
        }
        settings.popupPosition = .center
        settings.popupSavedTop = nil
        settings.useLiquidGlass = false
        let name = "popup-drag-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let board = NSPasteboard(name: .init(name))
        defer { board.releaseGlobally() }
        let store = HistoryStore(stack: CoreDataStack(inMemory: true))
        store.insertTextSynchronously("move this popup")
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = PopupController(store: store,
            paster: Paster(pasteboard: board, accessibilityPermission: { false }),
            settings: settings, snippets: SnippetStore(defaults: defaults))
        let window = try XCTUnwrap(NSApp.windows.compactMap { $0 as? PopupWindow }
            .first { !existing.contains(ObjectIdentifier($0)) })
        window.alphaValue = 0
        window.hasShadow = false
        defer { controller.hide() }
        controller.show()
        drainEvents()
        XCTAssertNil(settings.popupSavedTop, "layout alone must not overwrite the saved location")
        XCTAssertEqual(settings.popupPosition, .center)

        // AppKit delivers the same didMove notification for this public API as
        // for a window drag; no global pointer events or private state are used.
        window.setFrameOrigin(NSPoint(x: window.frame.minX + 17, y: window.frame.minY - 19))
        drainEvents()
        let saved = try XCTUnwrap(settings.popupSavedTop)
        XCTAssertEqual(settings.popupPosition, .remembered)
        XCTAssertEqual(saved.x.truncatingRemainder(dividingBy: 16), 0, accuracy: 0.01)
        XCTAssertEqual(saved.y.truncatingRemainder(dividingBy: 16), 0, accuracy: 0.01)
        XCTAssertEqual(saved.x, window.frame.minX, accuracy: 8)
        XCTAssertEqual(saved.y, window.frame.maxY, accuracy: 8)

        controller.hide()
        controller.show()
        drainEvents()
        XCTAssertEqual(window.frame.minX, saved.x, accuracy: 1)
        XCTAssertEqual(window.frame.maxY, saved.y, accuracy: 1)
        window.setFrameOrigin(NSPoint(x: window.frame.minX - 32, y: window.frame.minY + 16))
        drainEvents()
        let updated = try XCTUnwrap(settings.popupSavedTop)
        XCTAssertNotEqual(updated, saved)
        XCTAssertEqual(settings.popupPosition, .remembered)

        controller.hide()
        window.setFrameOrigin(NSPoint(x: window.frame.minX + 80, y: window.frame.minY))
        drainEvents()
        XCTAssertEqual(settings.popupSavedTop, updated, "moving a hidden popup must not replace the user's drag position")
    }

    private func drainEvents() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }
}
