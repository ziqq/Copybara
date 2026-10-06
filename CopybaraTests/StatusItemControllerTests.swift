// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import XCTest
@testable import Copybara

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testDockOnlyHidesStatusItemAndRemovesPopupAnchor() {
        let controller = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)))
        controller.applyVisibility(.dock)
        XCTAssertFalse(controller.isVisible)
        XCTAssertNil(controller.statusButtonScreenRect())
        controller.applyVisibility(.both)
        XCTAssertTrue(controller.isVisible)
        controller.applyVisibility(.menuBar)
        XCTAssertTrue(controller.isVisible)
    }

    func testRightAndControlClicksOpenOnlyMenuAndDismissPopupFirst() {
        var actions: [String] = []
        let controller = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)),
                                              presentMenu: { _, _ in actions.append("menu") })
        controller.onPrimaryAction = { actions.append("popup") }
        controller.onOpenContextMenu = { actions.append("dismiss") }
        for event in [mouse(.rightMouseUp), mouse(.leftMouseUp, flags: .control)] {
            actions = []
            controller.handleClick(event: event)
            XCTAssertEqual(actions, ["dismiss", "menu"])
        }
        actions = []
        controller.handleClick(event: mouse(.leftMouseUp))
        XCTAssertEqual(actions, ["popup"])
        actions = []
        controller.handleClick(event: mouse(.leftMouseDown))
        XCTAssertTrue(actions.isEmpty)
        controller.handleClick(event: nil) // accessibility invocation
        XCTAssertEqual(actions, ["popup"])
    }

    func testMenuKeepsRequestedOrderWithoutClearOrIcons() {
        let controller = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)))
        let menu = controller.buildMenu()
        let titles = menu.items.filter { !$0.isSeparatorItem }.map(\.title)
        let updates = titles.firstIndex(of: L10n.string("Check for Updates…"))!
        XCTAssertEqual(Array(titles[updates...updates + 2]), [L10n.string("Check for Updates…"), L10n.string("Settings"), L10n.string("Clear All")])
        XCTAssertFalse(titles.contains(L10n.string("Clear")))
        XCTAssertTrue(menu.items.allSatisfy { $0.image == nil })
        let settings = menu.items.first { $0.keyEquivalent == "," }
        XCTAssertEqual(settings?.title, L10n.string("Settings"))
        XCTAssertFalse(settings?.title.contains("…") ?? true)
    }

    func testSettingsActionRunsAfterMenuTrackingReturns() async {
        let controller = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)))
        let opened = expectation(description: "settings callback")
        var called = false
        controller.onOpenSettings = { called = true; opened.fulfill() }
        let item = controller.buildMenu().items.first { $0.title == L10n.string("Settings") }!
        controller.perform(item.action!)
        XCTAssertFalse(called, "window creation must not re-enter menu tracking")
        await fulfillment(of: [opened], timeout: 2)
    }

    private func mouse(_ type: NSEvent.EventType, flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: flags, timestamp: 0,
                          windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
    }
}
