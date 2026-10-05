// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import ImageIO

/// Downsampled, cached images for clip rows and the preview card.
///
/// Rows show image clips at 18pt, but the stored payload is the full-size
/// capture (often megabytes). Decoding that on every row render made scrolling
/// stutter; ImageIO decodes straight to the target size instead, once per clip.
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    init() {
        cache.countLimit = 500
    }

    /// A previously decoded thumbnail, without doing any work.
    func cached(id: UUID, maxPixel: Int) -> NSImage? {
        cache.object(forKey: key(id, maxPixel))
    }

    /// Decodes `data` to at most `maxPixel` on its longest side and caches it.
    /// Thread-safe (`NSCache`), so it can run off the main thread.
    func image(id: UUID, maxPixel: Int, data: Data) -> NSImage? {
        if let hit = cached(id: id, maxPixel: maxPixel) { return hit }
        guard let image = Self.downsample(data, maxPixel: maxPixel) else { return nil }
        store(image, id: id, maxPixel: maxPixel)
        return image
    }

    func store(_ image: NSImage, id: UUID, maxPixel: Int) {
        cache.setObject(image, forKey: key(id, maxPixel))
    }

    private func key(_ id: UUID, _ maxPixel: Int) -> NSString {
        "\(id.uuidString)-\(maxPixel)" as NSString
    }

    static func downsample(_ data: Data, maxPixel: Int) -> NSImage? {
        guard let cgImage = downsampleCGImage(data, maxPixel: maxPixel) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    static func downsampleCGImage(_ data: Data, maxPixel: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}
