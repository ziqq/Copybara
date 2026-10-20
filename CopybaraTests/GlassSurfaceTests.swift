// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import SwiftUI
import XCTest
@testable import Copybara

@MainActor
final class GlassSurfaceTests: XCTestCase {
    func testDisabledLiquidGlassClipsMaterialToRequestedRoundedShape() throws {
        let defaults = UserDefaults.standard
        let originalArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        var arguments = originalArguments
        arguments["useLiquidGlass"] = false
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        defer { defaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain) }

        let content = Color.red.frame(width: 120, height: 80)
            .modifier(GlassOrMaterial(cornerRadius: 20))
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 120, height: 80)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)

        let center = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(center.redComponent, 0.9)
        XCTAssertGreaterThan(center.alphaComponent, 0.95)
        for x in [0, bitmap.pixelsWide - 1] {
            for y in [0, bitmap.pixelsHigh - 1] {
                let corner = try XCTUnwrap(bitmap.colorAt(x: x, y: y))
                XCTAssertLessThan(corner.alphaComponent, 0.05,
                                  "disabling glass must still clip the content to the rounded surface")
            }
        }
    }
}
