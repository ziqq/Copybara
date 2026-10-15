// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import SwiftUI
import XCTest
@testable import Copybara

@MainActor
final class ClipRowViewTests: XCTestCase {
    @discardableResult
    private func render(_ item: ClipItemDO, selected: Bool = false, query: String = "") throws -> NSSize {
        let row = ClipRowView(item: item, isSelected: selected, query: query, index: 0)
            .frame(width: PopupMetrics.width)
        let hosting = NSHostingView(rootView: row)
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        XCTAssertEqual(size.height, PopupMetrics.rowHeight - 4, accuracy: 1)
        return size
    }

    func testImageRowDecodesOnlyRowSizedThumbnailAndReusesItWithoutPayload() throws {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1_200, pixelsHigh: 600,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let item = ClipItemDO(kind: .image, preview: "Image 1200×600", data: data)
        try render(item)
        let thumbnail = try XCTUnwrap(ThumbnailCache.shared.cached(id: item.id, maxPixel: ClipRowView.thumbnailPixels))
        XCTAssertEqual(thumbnail.size, NSSize(width: 36, height: 18))
        XCTAssertNil(ThumbnailCache.shared.cached(id: item.id, maxPixel: 600),
                     "rendering a list row must not decode the large preview")
        try render(item.with(data: nil), selected: true)
        XCTAssertTrue(ThumbnailCache.shared.cached(id: item.id, maxPixel: ClipRowView.thumbnailPixels) === thumbnail)
    }

    func testLargeMultilineTextKeepsFixedRowSizeWithSearchHighlight() throws {
        let text = "prefix HISTORY suffix\n" + String(repeating: "long text 😀\n", count: 10_000)
        let item = ClipItemDO(preview: text, isPinned: true, appBundleID: "com.apple.finder", copyCount: 4)
        let normal = try render(item, query: "history")
        let selected = try render(item, selected: true, query: "history")
        XCTAssertEqual(normal, selected)
        XCTAssertEqual(normal.width, PopupMetrics.width, accuracy: 1)
        XCTAssertFalse(item.rowText.contains("\n"))
        XCTAssertLessThanOrEqual(item.rowText.count, 300)
    }

    func testCorruptImageFallsBackWithoutCachingInvalidThumbnail() throws {
        let item = ClipItemDO(kind: .image, preview: "unavailable", data: Data([1, 2]))
        try render(item)
        XCTAssertNil(ThumbnailCache.shared.cached(id: item.id, maxPixel: ClipRowView.thumbnailPixels))
    }
}
