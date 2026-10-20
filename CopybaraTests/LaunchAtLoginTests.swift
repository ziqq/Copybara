// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import XCTest
@testable import Copybara

@MainActor
final class LaunchAtLoginTests: XCTestCase {
    private final class LoginItem {
        var enabled: Bool
        var rejectsChanges = false
        var requests: [Bool] = []

        init(enabled: Bool = false) { self.enabled = enabled }

        func setEnabled(_ value: Bool) {
            LaunchAtLoginManager.setEnabled(value, register: { try self.apply(true) },
                                           unregister: { try self.apply(false) })
        }

        private func apply(_ value: Bool) throws {
            requests.append(value)
            if rejectsChanges {
                throw NSError(domain: "CopybaraTests.LoginItem", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Synthetic registration failure"])
            }
            enabled = value
        }
    }

    func testRegistrationAndUnregistrationCallOnlyTheRequestedOperation() {
        let item = LoginItem()

        item.setEnabled(true)
        XCTAssertTrue(item.enabled)
        XCTAssertEqual(item.requests, [true])

        item.setEnabled(false)
        XCTAssertFalse(item.enabled)
        XCTAssertEqual(item.requests, [true, false])
    }

    func testFailedRegistrationAndUnregistrationLeaveSystemStateIntactAndAllowRetry() {
        for initial in [false, true] {
            let item = LoginItem(enabled: initial)
            item.rejectsChanges = true

            item.setEnabled(!initial)

            XCTAssertEqual(item.enabled, initial)
            XCTAssertEqual(item.requests, [!initial], "failure must not call the opposite operation")
            item.rejectsChanges = false
            item.setEnabled(!initial)
            XCTAssertEqual(item.enabled, !initial)
            XCTAssertEqual(item.requests, [!initial, !initial])
        }
    }

    func testSettingsToggleUsesSystemStateAndDoesNotRegisterAgainWhenUnchanged() {
        for initial in [false, true] {
            withSettings(enabled: initial) { settings, item in
                XCTAssertEqual(settings.launchAtLogin, initial)
                XCTAssertTrue(item.requests.isEmpty, "reading the system state must not change registration")

                settings.launchAtLogin = !initial

                XCTAssertEqual(item.enabled, !initial)
                XCTAssertEqual(settings.launchAtLogin, !initial)
                XCTAssertEqual(item.requests, [!initial])
                settings.launchAtLogin = !initial
                settings.refreshExternalState()
                XCTAssertEqual(item.requests, [!initial], "refreshing an unchanged toggle must not register twice")
            }
        }
    }

    func testSettingsReflectExternalSystemChangesWithoutWritingThemBack() {
        withSettings { settings, item in
            item.enabled = true
            settings.refreshExternalState()
            XCTAssertTrue(settings.launchAtLogin)
            item.enabled = false
            settings.refreshExternalState()
            XCTAssertFalse(settings.launchAtLogin)
            XCTAssertTrue(item.requests.isEmpty, "an external change must only update the displayed state")
        }
    }

    func testSettingsRevertRejectedChangesAfterTheCurrentUIUpdateWithoutRetrying() {
        for initial in [false, true] {
            withSettings(enabled: initial) { settings, item in
                item.rejectsChanges = true

                settings.launchAtLogin = !initial

                XCTAssertEqual(settings.launchAtLogin, !initial, "rollback must wait until the current update finishes")
                XCTAssertEqual(item.enabled, initial)
                drainMainQueue()
                XCTAssertEqual(settings.launchAtLogin, initial)
                XCTAssertEqual(item.requests, [!initial], "rolling back must not try the rejected operation again")
                item.rejectsChanges = false
                settings.launchAtLogin = !initial
                XCTAssertEqual(settings.launchAtLogin, !initial)
                XCTAssertEqual(item.enabled, !initial)
                drainMainQueue()
                XCTAssertEqual(item.requests, [!initial, !initial])
            }
        }
    }

    func testMenuDefersRegistrationAndRebuildsItsCheckmarkFromSystemState() throws {
        let item = LoginItem()
        let controller = makeMenu(item)
        for expected in [true, false] {
            let toggle = try startupItem(controller)
            XCTAssertEqual(toggle.state, expected ? .off : .on)
            XCTAssertTrue(toggle.isEnabled)
            let previous = item.requests

            controller.perform(try XCTUnwrap(toggle.action))

            XCTAssertEqual(item.requests, previous, "registration must wait until native menu tracking ends")
            drainMainQueue()
            XCTAssertEqual(item.requests, previous + [expected])
            XCTAssertEqual(item.enabled, expected)
            XCTAssertEqual(try startupItem(controller).state, expected ? .on : .off)
        }
    }

    func testMenuRejectedChangeKeepsActualCheckmarkAndCanBeRetried() throws {
        for initial in [false, true] {
            let item = LoginItem(enabled: initial)
            let controller = makeMenu(item)
            item.rejectsChanges = true
            let toggle = try startupItem(controller)
            controller.perform(try XCTUnwrap(toggle.action))
            drainMainQueue()

            XCTAssertEqual(item.enabled, initial)
            XCTAssertEqual(try startupItem(controller).state, initial ? .on : .off)
            XCTAssertEqual(item.requests, [!initial])
            item.rejectsChanges = false
            controller.perform(try XCTUnwrap(toggle.action))
            drainMainQueue()
            XCTAssertEqual(item.enabled, !initial)
            XCTAssertEqual(try startupItem(controller).state, initial ? .off : .on)
            XCTAssertEqual(item.requests, [!initial, !initial])
        }
    }

    func testMenuReadsLatestSystemStateAfterTrackingBeforeDecidingWhatToToggle() throws {
        let item = LoginItem()
        let controller = makeMenu(item)
        let toggle = try startupItem(controller)
        XCTAssertEqual(toggle.state, .off)

        controller.perform(try XCTUnwrap(toggle.action))
        // System Settings can change the state while the menu is closing.
        item.enabled = true
        drainMainQueue()

        XCTAssertEqual(item.requests, [false], "the queued action must not use a stale menu checkmark")
        XCTAssertFalse(item.enabled)
        XCTAssertEqual(try startupItem(controller).state, .off)
    }

    func testQueuedMenuChangeFinishesWithoutRetainingItsClosedController() throws {
        let item = LoginItem()
        weak var released: StatusItemController?
        try autoreleasepool {
            let controller = makeMenu(item)
            released = controller
            let toggle = try startupItem(controller)
            controller.perform(try XCTUnwrap(toggle.action))
        }

        XCTAssertNil(released, "closing the menu must release its status item before registration runs")
        XCTAssertTrue(item.requests.isEmpty)
        drainMainQueue()
        XCTAssertEqual(item.requests, [true])
        XCTAssertTrue(item.enabled, "the user's queued action must still finish")
    }

    func testMenuAndSettingsStayInSyncThroughTheSameSystemRegistration() throws {
        try withSettings { settings, item in
            let controller = makeMenu(item)
            settings.launchAtLogin = true
            XCTAssertEqual(try startupItem(controller).state, .on)

            let toggle = try startupItem(controller)
            controller.perform(try XCTUnwrap(toggle.action))
            drainMainQueue()
            settings.refreshExternalState()

            XCTAssertFalse(settings.launchAtLogin)
            XCTAssertEqual(try startupItem(controller).state, .off)
            XCTAssertEqual(item.requests, [true, false], "synchronization must not duplicate system writes")
        }
    }

    private func withSettings(enabled: Bool = false, _ body: (SettingsOO, LoginItem) throws -> Void) rethrows {
        let name = "launch-at-login-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let item = LoginItem(enabled: enabled)
        let settings = SettingsOO(settings: AppSettings(defaults: defaults), snippetStore: SnippetStore(defaults: defaults),
                                  isLaunchAtLoginEnabled: { item.enabled }, setLaunchAtLogin: item.setEnabled)
        try body(settings, item)
    }

    private func makeMenu(_ item: LoginItem) -> StatusItemController {
        StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)),
                             isLaunchAtLoginEnabled: { item.enabled }, setLaunchAtLogin: item.setEnabled)
    }

    private func startupItem(_ controller: StatusItemController) throws -> NSMenuItem {
        let settings = try XCTUnwrap(controller.buildMenu().items.first { $0.title == L10n.string("Settings") }?.submenu)
        return try XCTUnwrap(settings.items.first { $0.title == L10n.string("Launch at login") })
    }

    private func drainMainQueue() {
        let drained = expectation(description: "deferred registration or toggle rollback completed")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)
    }
}
