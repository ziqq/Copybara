// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import KeyboardShortcuts
import XCTest
@testable import Copybara

@MainActor
final class HotKeyManagerTests: XCTestCase {
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
