// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import XCTest
@testable import Copybara

@MainActor
final class StatusItemControllerTests: XCTestCase {
    private final class CancelTerminationDelegate: NSObject, NSApplicationDelegate {
        var requests = 0
        func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
            requests += 1
            return .terminateCancel
        }
    }

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

    func testMenuContainsAboutFirstAndBothClearActionsInOrder() throws {
        let store = HistoryStore(stack: CoreDataStack(inMemory: true))
        let controller = StatusItemController(store: store)
        let menu = controller.buildMenu()
        XCTAssertEqual(menu.items.first?.title, L10n.string("About Copybara"))
        let clear = try XCTUnwrap(menu.items.firstIndex { $0.title == L10n.string("Clear All") })
        let favorites = menu.items[clear + 1]
        XCTAssertEqual(favorites.title, L10n.string("Clear All Except Favorites"))
        XCTAssertEqual(menu.items[clear].keyEquivalentModifierMask, [.shift, .option, .command])
        XCTAssertEqual(favorites.keyEquivalentModifierMask, [.option, .command])
        XCTAssertFalse(menu.items[clear].isEnabled)
        XCTAssertFalse(favorites.isEnabled)
        store.insertTextSynchronously("one")
        XCTAssertTrue(controller.buildMenu().items[clear].isEnabled)
        XCTAssertTrue(controller.buildMenu().items[clear + 1].isEnabled)
    }

    func testSettingsSubmenuKeepsCopyAndPositionOrderWithoutIcons() throws {
        let controller = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)))
        let settings = try XCTUnwrap(controller.buildMenu().items.first { $0.title == L10n.string("Settings") }?.submenu)
        XCTAssertEqual(settings.items.prefix(2).map(\.title),
                       [L10n.string("Ignore Next Copy"), L10n.string("Ignore All Copies")])
        let positions = try XCTUnwrap(settings.items.first { $0.submenu != nil }?.submenu)
        XCTAssertEqual(positions.items.map(\.representedObject) as? [String],
                       [PopupPosition.remembered, .menuBarIcon, .center, .cursor].map(\.rawValue))
        XCTAssertEqual(positions.items.filter { $0.state == .on }.count, 1)
        XCTAssertEqual(positions.items.first { $0.state == .on }?.representedObject as? String,
                       AppSettings.shared.popupPosition.rawValue)
        XCTAssertTrue(settings.items.allSatisfy { $0.image == nil })
        XCTAssertTrue(positions.items.allSatisfy { $0.image == nil })
    }

    func testClearMenuActionsDeleteOnlyTheirIntendedHistory() throws {
        let store = HistoryStore(stack: CoreDataStack(inMemory: true))
        store.insertTextSynchronously("favorite")
        store.togglePin(id: try XCTUnwrap(store.recentItems().first).id)
        store.insertTextSynchronously("ordinary")
        let controller = StatusItemController(store: store)
        let menu = controller.buildMenu()
        let keepFavorites = try XCTUnwrap(menu.items.first { $0.title == L10n.string("Clear All Except Favorites") })
        controller.perform(try XCTUnwrap(keepFavorites.action))
        XCTAssertEqual(store.recentItems().map(\.preview), ["favorite"])
        XCTAssertEqual(store.recentItems().first?.isPinned, true)
        let clear = try XCTUnwrap(menu.items.first { $0.title == L10n.string("Clear All") })
        controller.perform(try XCTUnwrap(clear.action))
        XCTAssertEqual(store.count(), 0)
    }

    func testMenuRoutesUpdateAndIgnoreNextActions() throws {
        let controller = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)))
        var actions: [String] = []
        controller.onCheckForUpdates = { actions.append("updates") }
        controller.onIgnoreNext = { actions.append("ignore") }
        let menu = controller.buildMenu()
        let updates = try XCTUnwrap(menu.items.first { $0.title == L10n.string("Check for Updates…") })
        let settings = try XCTUnwrap(menu.items.first { $0.title == L10n.string("Settings") }?.submenu)
        let ignore = try XCTUnwrap(settings.items.first { $0.title == L10n.string("Ignore Next Copy") })
        controller.perform(try XCTUnwrap(updates.action))
        controller.perform(try XCTUnwrap(ignore.action))
        XCTAssertEqual(actions, ["updates", "ignore"])
    }

    func testOptionShiftClickSkipsOnlyNextCopy() {
        let controller = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)))
        var actions: [String] = []
        controller.onIgnoreNext = { actions.append("ignore") }
        controller.onPrimaryAction = { actions.append("popup") }
        controller.handleClick(event: mouse(.leftMouseUp, flags: [.option, .shift]))
        XCTAssertEqual(actions, ["ignore"])
    }

    func testStatusButtonActionRoutesToPrimaryPopupCallback() throws {
        var button: NSStatusBarButton?
        let controller = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)),
                                              presentMenu: { _, sender in button = sender })
        controller.handleClick(event: mouse(.rightMouseUp))
        let sender = try XCTUnwrap(button)
        XCTAssertTrue(sender.target === controller)
        XCTAssertNotNil(sender.action)
        var opened = 0
        controller.onPrimaryAction = { opened += 1 }

        // The status action reads NSApp.currentEvent. Fetch the fixture from
        // this application's queue, as the native event loop does for a click.
        let click = mouse(.leftMouseUp)
        NSApp.postEvent(click, atStart: true)
        let fetched = try XCTUnwrap(NSApp.nextEvent(matching: .leftMouseUp,
            until: Date().addingTimeInterval(1), inMode: .default, dequeue: true))
        XCTAssertEqual(fetched.modifierFlags.intersection(.deviceIndependentFlagsMask), [])
        XCTAssertEqual(NSApp.currentEvent?.type, .leftMouseUp)
        sender.performClick(nil)

        XCTAssertEqual(opened, 1, "the native status button must route its configured action to the popup")
    }

    func testQuitMenuRequestsTerminationAndHonorsDelegateCancellation() throws {
        let controller = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)))
        let item = try XCTUnwrap(controller.buildMenu().items.first { $0.title == L10n.string("Quit Copybara") })
        let originalDelegate = NSApp.delegate
        let delegate = CancelTerminationDelegate()
        NSApp.delegate = delegate
        defer { NSApp.delegate = originalDelegate }

        controller.perform(try XCTUnwrap(item.action))

        XCTAssertEqual(delegate.requests, 1, "Quit must pass through the application's termination policy")
    }

    func testShowMenuActionIsDeferredUntilTrackingReturns() async throws {
        let controller = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)))
        let opened = expectation(description: "popup callback")
        var called = false
        controller.onPrimaryAction = { called = true; opened.fulfill() }
        let item = try XCTUnwrap(controller.buildMenu().items.first { $0.title == L10n.string("Show Copybara") })
        controller.perform(try XCTUnwrap(item.action))
        XCTAssertFalse(called)
        await fulfillment(of: [opened], timeout: 2)
    }

    func testAboutMenuActionOpensNativePanelAfterTrackingReturns() async throws {
        let controller = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)))
        let existing = Set(NSApp.windows.filter(\.isVisible).map(ObjectIdentifier.init))
        defer {
            for window in NSApp.windows where window.isVisible && !existing.contains(ObjectIdentifier(window)) {
                window.close()
            }
        }
        let about = try XCTUnwrap(controller.buildMenu().items.first { $0.title == L10n.string("About Copybara") })
        controller.perform(try XCTUnwrap(about.action))
        XCTAssertFalse(NSApp.windows.contains { !existing.contains(ObjectIdentifier($0)) && $0.isVisible })
        let presented = expectation(description: "native About panel opened")
        DispatchQueue.main.async { presented.fulfill() }
        await fulfillment(of: [presented], timeout: 2)
        let panel = try XCTUnwrap(NSApp.windows.first { !existing.contains(ObjectIdentifier($0)) && $0.isVisible })
        panel.alphaValue = 0
        XCTAssertNotNil(panel.contentView)
        XCTAssertGreaterThan(panel.frame.width, 0)
    }

    func testInvalidPopupPositionMenuPayloadDoesNotChangePreference() throws {
        let controller = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)))
        let settings = try XCTUnwrap(controller.buildMenu().items.first { $0.title == L10n.string("Settings") }?.submenu)
        let positions = try XCTUnwrap(settings.items.first { $0.submenu != nil }?.submenu)
        let action = try XCTUnwrap(positions.items.first?.action)
        let original = AppSettings.shared.popupPosition
        let sender = NSMenuItem(title: "invalid", action: action, keyEquivalent: "")
        for value: Any? in [nil, NSNumber(value: 42), "unknown-position"] {
            sender.representedObject = value
            controller.perform(action, with: sender)
            XCTAssertEqual(AppSettings.shared.popupPosition, original)
        }
    }

    private func mouse(_ type: NSEvent.EventType, flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: flags, timestamp: 0,
                          windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
    }
}
