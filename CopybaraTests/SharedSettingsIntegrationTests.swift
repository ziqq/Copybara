// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import CoreData
import XCTest
@testable import Copybara

@MainActor
final class SharedSettingsIntegrationTests: XCTestCase {
    func testTestHostUsesBuildDirectoryForApplicationData() throws {
        try IsolatedTestHost.require()
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).standardizedFileURL
        let storeDirectory = NSPersistentContainer.defaultDirectoryURL().standardizedFileURL
        XCTAssertTrue(storeDirectory.path.hasPrefix(home.path + "/"))
    }

    func testIgnoreAllMenuAndOptionClickUpdatePreferencesIconAndCheckmark() throws {
        try IsolatedTestHost.require()
        let settings = AppSettings.shared
        let original = settings.ignoreAllCopies
        defer { settings.ignoreAllCopies = original }
        settings.ignoreAllCopies = false
        var button: NSStatusBarButton?
        let controller = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)),
                                              presentMenu: { _, sender in button = sender })
        controller.handleClick(event: mouse(.rightMouseUp))
        let sender = try XCTUnwrap(button)
        XCTAssertFalse(sender.appearsDisabled)
        let ignore = try ignoreItem(in: controller)
        controller.perform(try XCTUnwrap(ignore.action))

        XCTAssertTrue(settings.ignoreAllCopies)
        XCTAssertTrue(sender.appearsDisabled)
        XCTAssertEqual(sender.toolTip, L10n.string("Copybara — ignoring copies"))
        XCTAssertEqual(try ignoreItem(in: controller).state, .on)

        controller.handleClick(event: mouse(.leftMouseUp, flags: .option))

        XCTAssertFalse(settings.ignoreAllCopies)
        XCTAssertFalse(sender.appearsDisabled)
        XCTAssertEqual(sender.toolTip, "Copybara")
        XCTAssertEqual(try ignoreItem(in: controller).state, .off)
    }

    func testPositionMenuPersistsEachChoiceAndMovesItsOnlyCheckmark() throws {
        try IsolatedTestHost.require()
        let original = AppSettings.shared.popupPosition
        defer { AppSettings.shared.popupPosition = original }
        let controller = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)))
        for position in PopupPosition.allCases {
            let menu = try positions(in: controller)
            let item = try XCTUnwrap(menu.items.first { ($0.representedObject as? String) == position.rawValue })
            controller.perform(try XCTUnwrap(item.action), with: item)
            XCTAssertEqual(AppSettings.shared.popupPosition, position)
            let checked = try positions(in: controller).items.filter { $0.state == .on }
            XCTAssertEqual(checked.count, 1)
            XCTAssertEqual(checked.first?.representedObject as? String, position.rawValue)
        }
    }

    private func ignoreItem(in controller: StatusItemController) throws -> NSMenuItem {
        let settings = try XCTUnwrap(controller.buildMenu().items.first { $0.title == L10n.string("Settings") }?.submenu)
        return try XCTUnwrap(settings.items.first { $0.title == L10n.string("Ignore All Copies") })
    }

    private func positions(in controller: StatusItemController) throws -> NSMenu {
        let settings = try XCTUnwrap(controller.buildMenu().items.first { $0.title == L10n.string("Settings") }?.submenu)
        return try XCTUnwrap(settings.items.first { $0.submenu != nil }?.submenu)
    }

    private func mouse(_ type: NSEvent.EventType, flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: flags, timestamp: 0,
                          windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
    }
}
