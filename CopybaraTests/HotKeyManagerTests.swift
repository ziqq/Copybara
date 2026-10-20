// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import KeyboardShortcuts
import XCTest
@testable import Copybara

@MainActor
final class HotKeyManagerTests: XCTestCase {
    private final class Registration {
        var events: [String] = []
        var handlers: [() -> Void] = []

        func manager(settings: AppSettings) -> HotKeyManager {
            HotKeyManager(settings: settings, resetShortcut: { self.events.append("reset") }, registerKeyDown: {
                self.events.append("register")
                self.handlers.append($0)
            }, disableShortcut: { self.events.append("disable") })
        }
    }

    private func withRegistration(migrated: Bool = false,
                                  _ body: (AppSettings, Registration) throws -> Void) rethrows {
        let name = "hotkey-migration-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        let standard = UserDefaults.standard
        let originalArguments = standard.volatileDomain(forName: UserDefaults.argumentDomain)
        var arguments = originalArguments
        // Even the log's shortcut-name lookup must not install the default chord.
        arguments["KeyboardShortcuts_togglePopup"] = false
        standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        defer {
            standard.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain)
            defaults.removePersistentDomain(forName: name)
        }
        let settings = AppSettings(defaults: defaults)
        settings.didMigrateHotkeyToV = migrated
        try body(settings, Registration())
    }

    func testFirstRegistrationMigratesBeforeBindingAndPersistsAcrossManagerInstances() {
        withRegistration { settings, registration in
            let first = registration.manager(settings: settings)
            var toggles = 0
            first.onToggle = { toggles += 1 }

            first.register()

            XCTAssertTrue(settings.didMigrateHotkeyToV)
            XCTAssertEqual(registration.events, ["reset", "register"])
            XCTAssertEqual(toggles, 0, "migration and registration must not themselves open the popup")
            first.unregister()
            let second = registration.manager(settings: settings)
            second.register()
            XCTAssertEqual(registration.events, ["reset", "register", "disable", "register"],
                           "a new manager must preserve the completed one-time migration")
        }
    }

    func testMigratedRegistrationPreservesOtherSettingsAndNeverResetsShortcut() {
        withRegistration(migrated: true) { settings, registration in
            settings.popupPosition = .cursor
            settings.ignoreAllCopies = true
            let manager = registration.manager(settings: settings)

            manager.register()
            manager.register()

            XCTAssertEqual(registration.events, ["register", "register"])
            XCTAssertTrue(settings.didMigrateHotkeyToV)
            XCTAssertEqual(settings.popupPosition, .cursor)
            XCTAssertTrue(settings.ignoreAllCopies)
        }
    }

    func testKeyDownUsesLatestCallbackAndHandlesAnUnsetCallback() throws {
        try withRegistration(migrated: true) { settings, registration in
            let manager = registration.manager(settings: settings)
            manager.register()
            let keyDown = try XCTUnwrap(registration.handlers.first)
            var first = 0, second = 0
            manager.onToggle = { first += 1 }
            keyDown()
            manager.onToggle = { second += 1 }
            keyDown()
            manager.onToggle = nil
            keyDown()

            XCTAssertEqual(first, 1)
            XCTAssertEqual(second, 1, "rebinding the callback must take effect without registering the key again")
            XCTAssertEqual(registration.events, ["register"])
        }
    }

    func testRegisteredCallbackDoesNotRetainReleasedManagerOrToggleLater() throws {
        try withRegistration(migrated: true) { settings, registration in
            var manager: HotKeyManager? = registration.manager(settings: settings)
            weak var released = manager
            var toggles = 0
            manager?.onToggle = { toggles += 1 }
            manager?.register()
            let keyDown = try XCTUnwrap(registration.handlers.first)
            keyDown()
            XCTAssertEqual(toggles, 1)

            manager = nil
            XCTAssertNil(released)
            keyDown()
            XCTAssertEqual(toggles, 1, "a stale key handler must not toggle a released popup owner")
        }
    }

    func testUnregisterDisablesShortcutWithoutResettingMigrationOrCallingToggle() {
        withRegistration(migrated: true) { settings, registration in
            let manager = registration.manager(settings: settings)
            var toggles = 0
            manager.onToggle = { toggles += 1 }
            manager.register()

            manager.unregister()

            XCTAssertEqual(registration.events, ["register", "disable"])
            XCTAssertTrue(settings.didMigrateHotkeyToV)
            XCTAssertEqual(toggles, 0)
        }
    }

    func testRegisterAfterMigrationPreservesDisabledShortcutAndPreferences() throws {
        let defaults = UserDefaults.standard
        let originalArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        let bundleID = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let originalPreferences = defaults.persistentDomain(forName: bundleID) as NSDictionary?
        var arguments = originalArguments
        arguments["didMigrateHotkeyToV"] = true
        // KeyboardShortcuts treats false as an explicitly disabled shortcut,
        // so this fixture never registers a real global key combination.
        arguments["KeyboardShortcuts_togglePopup"] = false
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        let manager = HotKeyManager()
        defer {
            manager.unregister()
            KeyboardShortcuts.removeAllHandlers()
            defaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain)
        }
        var toggles = 0
        manager.onToggle = { toggles += 1 }

        manager.register()
        XCTAssertNil(KeyboardShortcuts.getShortcut(for: .togglePopup),
                     "a returning user's disabled shortcut must not be reset to the default")
        manager.unregister()

        XCTAssertNil(KeyboardShortcuts.getShortcut(for: .togglePopup))
        XCTAssertEqual(toggles, 0, "registering or removing a shortcut must not open the popup")
        XCTAssertEqual(defaults.persistentDomain(forName: bundleID) as NSDictionary?, originalPreferences,
                       "starting with a migrated shortcut must not rewrite saved preferences")
    }
}
