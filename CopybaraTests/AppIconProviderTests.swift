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

    func testMenuBarMarkRendersTwoSeparateLayersOnTransparentBackground() throws {
        let image = MenuBarIcon.image()
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertEqual(image.accessibilityDescription, "Copybara")
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 36, pixelsHigh: 36,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: 36, height: 36), from: .zero,
                   operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        // A horizontal slice through the C's center crosses its two stems,
        // separated by transparency; the open right side must remain clear.
        var stems = 0
        var previousOpaque = false
        for x in 0..<36 {
            let opaque = try XCTUnwrap(bitmap.colorAt(x: x, y: 18)).alphaComponent > 0.1
            if opaque && !previousOpaque { stems += 1 }
            previousOpaque = opaque
        }
        XCTAssertEqual(stems, 2)
        XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 0, y: 0)).alphaComponent, 0, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 35, y: 18)).alphaComponent, 0, accuracy: 0.01)
    }
}
