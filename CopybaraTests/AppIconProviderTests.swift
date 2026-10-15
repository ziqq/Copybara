// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import XCTest
@testable import Copybara

@MainActor
final class AppIconProviderTests: XCTestCase {
    func testApplicationIconMatchesBundledAsset() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "AppIcon", withExtension: "icns"))
        let bundled = try XCTUnwrap(NSImage(contentsOf: url))
        let actual = AppIconProvider.applicationIcon
        XCTAssertTrue(actual.isValid)
        XCTAssertEqual(try XCTUnwrap(actual.tiffRepresentation), try XCTUnwrap(bundled.tiffRepresentation),
                       "the footer must use the current bundled artwork")
    }

    func testUnknownOrMissingSourceAppHasNoIconOrName() {
        for bundleID in [nil, "dev.copybara.missing.\(UUID())"] {
            XCTAssertNil(AppIconProvider.icon(forBundleID: bundleID))
            XCTAssertNil(AppIconProvider.name(forBundleID: bundleID))
        }
    }

    func testInstalledSourceAppIconAndNameAreCached() throws {
        let bundleID = "com.apple.finder"
        let icon = try XCTUnwrap(AppIconProvider.icon(forBundleID: bundleID))
        let name = try XCTUnwrap(AppIconProvider.name(forBundleID: bundleID))
        XCTAssertTrue(icon.isValid)
        XCTAssertFalse(name.isEmpty)
        XCTAssertFalse(name.hasSuffix(".app"))
        XCTAssertTrue(AppIconProvider.icon(forBundleID: bundleID) === icon)
        XCTAssertEqual(AppIconProvider.name(forBundleID: bundleID), name)
    }
}
