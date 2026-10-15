// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import XCTest
@testable import Copybara

final class ThumbnailCacheTests: XCTestCase {
    private func png(width: Int = 120, height: Int = 60) throws -> Data {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }

    func testDownsamplingPreservesLandscapeAspectRatio() throws {
        let image = try XCTUnwrap(ThumbnailCache.downsampleCGImage(try png(), maxPixel: 30))
        XCTAssertEqual(image.width, 30)
        XCTAssertEqual(image.height, 15)
    }

    func testDownsamplingPreservesPortraitAspectRatio() throws {
        let image = try XCTUnwrap(ThumbnailCache.downsampleCGImage(try png(width: 60, height: 120), maxPixel: 30))
        XCTAssertEqual(image.width, 15)
        XCTAssertEqual(image.height, 30)
    }

    func testAppKitImageUsesDownsampledPixelSize() throws {
        let image = try XCTUnwrap(ThumbnailCache.downsample(try png(), maxPixel: 40))
        XCTAssertEqual(image.size, NSSize(width: 40, height: 20))
    }

    func testInvalidImageDoesNotPoisonCache() throws {
        let cache = ThumbnailCache(), id = UUID()
        XCTAssertNil(cache.image(id: id, maxPixel: 30, data: Data("not an image".utf8)))
        XCTAssertNil(cache.cached(id: id, maxPixel: 30))
        XCTAssertNotNil(cache.image(id: id, maxPixel: 30, data: try png()))
    }

    func testEmptyImageCannotBeDecoded() {
        XCTAssertNil(ThumbnailCache.downsample(Data(), maxPixel: 30))
    }

    func testRepeatedRequestReusesDecodedImage() throws {
        let cache = ThumbnailCache(), id = UUID()
        let first = try XCTUnwrap(cache.image(id: id, maxPixel: 30, data: try png()))
        // A cached thumbnail must be returned without decoding the new payload.
        let second = try XCTUnwrap(cache.image(id: id, maxPixel: 30, data: Data()))
        XCTAssertTrue(first === second)
        XCTAssertTrue(cache.cached(id: id, maxPixel: 30) === first)
    }

    func testRowAndPreviewSizesHaveSeparateCacheEntries() throws {
        let cache = ThumbnailCache(), id = UUID(), data = try png()
        let row = try XCTUnwrap(cache.image(id: id, maxPixel: 18, data: data))
        XCTAssertNil(cache.cached(id: id, maxPixel: 60))
        let preview = try XCTUnwrap(cache.image(id: id, maxPixel: 60, data: data))
        XCTAssertEqual(row.size.width, 18)
        XCTAssertEqual(preview.size.width, 60)
        XCTAssertTrue(cache.cached(id: id, maxPixel: 18) === row)
    }

    func testDifferentClipsDoNotShareCacheEntries() throws {
        let cache = ThumbnailCache(), firstID = UUID(), secondID = UUID()
        let image = try XCTUnwrap(cache.image(id: firstID, maxPixel: 30, data: try png()))
        XCTAssertNil(cache.cached(id: secondID, maxPixel: 30))
        cache.store(image, id: secondID, maxPixel: 30)
        XCTAssertTrue(cache.cached(id: secondID, maxPixel: 30) === image)
    }
}
