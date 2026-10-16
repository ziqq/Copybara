// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import XCTest
@testable import Copybara

final class AppSettingsTests: XCTestCase {
    private func makeSettings() -> AppSettings {
        let suite = UserDefaults(suiteName: "copybara-test-\(UUID().uuidString)")!
        return AppSettings(defaults: suite)
    }

    func testDefaults() {
        let settings = makeSettings()
        XCTAssertEqual(settings.historySize, 200)
        XCTAssertEqual(settings.historyRetentionDays, 0)
        XCTAssertEqual(settings.iconVisibility, .menuBar)
        XCTAssertEqual(settings.popupPosition, .remembered)
        XCTAssertEqual(settings.searchMode, .fuzzy)
        XCTAssertEqual(settings.sortMode, .lastCopied)
        XCTAssertTrue(settings.useLiquidGlass)
        XCTAssertFalse(settings.ignoreAllCopies)
        XCTAssertTrue(settings.blockedBundleIDs.isEmpty)
        XCTAssertNil(settings.popupSavedTop)
        XCTAssertFalse(settings.hasCompletedOnboarding)
    }

    func testRoundTrip() {
        let settings = makeSettings()
        settings.historySize = 50
        settings.historyRetentionDays = 30
        settings.iconVisibility = .both
        settings.popupPosition = .cursor
        settings.searchMode = .regex
        settings.sortMode = .numberOfCopies
        settings.useLiquidGlass = false
        settings.ignoreAllCopies = true
        settings.blockedBundleIDs = ["com.a", "com.b"]
        settings.popupSavedTop = CGPoint(x: 12, y: 34)
        settings.hasCompletedOnboarding = true

        XCTAssertEqual(settings.historySize, 50)
        XCTAssertEqual(settings.historyRetentionDays, 30)
        XCTAssertEqual(settings.iconVisibility, .both)
        XCTAssertEqual(settings.popupPosition, .cursor)
        XCTAssertEqual(settings.searchMode, .regex)
        XCTAssertEqual(settings.sortMode, .numberOfCopies)
        XCTAssertFalse(settings.useLiquidGlass)
        XCTAssertTrue(settings.ignoreAllCopies)
        XCTAssertEqual(settings.blockedBundleIDs, ["com.a", "com.b"])
        XCTAssertEqual(settings.popupSavedTop, CGPoint(x: 12, y: 34))
        XCTAssertTrue(settings.hasCompletedOnboarding)
    }

    func testClearingSavedPositionSurvivesReloadAndSupportsZeroCoordinates() {
        let name = "settings-position-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        settings.popupSavedTop = .zero
        XCTAssertEqual(AppSettings(defaults: defaults).popupSavedTop, .zero)
        settings.popupSavedTop = nil
        XCTAssertNil(AppSettings(defaults: defaults).popupSavedTop)
    }

    func testUnknownPersistedEnumValuesFallBackToSupportedDefaults() {
        let name = "settings-invalid-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        for key in ["iconVisibility", "popupPosition", "searchMode", "sortMode"] {
            defaults.set("removed-value", forKey: key)
        }
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.iconVisibility, .menuBar)
        XCTAssertEqual(settings.popupPosition, .remembered)
        XCTAssertEqual(settings.searchMode, .fuzzy)
        XCTAssertEqual(settings.sortMode, .lastCopied)
    }

    func testHotkeyMigrationFlagPersistsWithoutChangingShortcutRegistration() {
        let name = "settings-migration-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertFalse(settings.didMigrateHotkeyToV)
        settings.didMigrateHotkeyToV = true
        XCTAssertTrue(AppSettings(defaults: defaults).didMigrateHotkeyToV)
    }
}
