// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import SwiftUI
import XCTest
@testable import Copybara

@MainActor
final class PreviewCardTests: XCTestCase {
    private func render(_ item: ClipItemDO) throws -> NSBitmapImageRep {
        let hosting = NSHostingView(rootView: PreviewCard(item: item))
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        XCTAssertGreaterThan(bitmap.pixelsWide, 0)
        XCTAssertGreaterThan(bitmap.pixelsHigh, 0)
        return bitmap
    }

    func testLargeImagePreviewUsesBoundedThumbnail() throws {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1_200, pixelsHigh: 600,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let item = ClipItemDO(kind: .image, preview: "Image 1200×600", appBundleID: "com.apple.finder", copyCount: 3, data: data)
        XCTAssertNil(ThumbnailCache.shared.cached(id: item.id, maxPixel: 600))
        _ = try render(item)
        let thumbnail = try XCTUnwrap(ThumbnailCache.shared.cached(id: item.id, maxPixel: 600))
        XCTAssertEqual(thumbnail.size, NSSize(width: 600, height: 300))
    }

    func testCorruptImageFallsBackWithoutCachingInvalidPayload() throws {
        let item = ClipItemDO(kind: .image, preview: "Image unavailable", data: Data([1, 2]))
        _ = try render(item)
        XCTAssertNil(ThumbnailCache.shared.cached(id: item.id, maxPixel: 600))
    }

    func testMissingFilePayloadStillProducesVisiblePreview() throws {
        let item = ClipItemDO(kind: .file, preview: "report.pdf")
        let bitmap = try render(item)
        XCTAssertGreaterThan(bitmap.pixelsHigh, 24, "the fallback must have room for both header and file row")
    }
}
