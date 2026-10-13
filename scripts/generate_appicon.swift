#!/usr/bin/env swift
// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import Foundation

// Renders the Copybara app icon at all required macOS sizes into
// Copybara/Resources/Assets.xcassets/AppIcon.appiconset and writes its
// Contents.json. Re-run after replacing scripts/assets/AppIcon.png.
//
//   swift scripts/generate_appicon.swift

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("scripts/assets/AppIcon.png")
guard let source = NSImage(contentsOf: sourceURL) else {
    fatalError("Cannot load app icon source at \(sourceURL.path)")
}
let iconset = root.appendingPathComponent("Copybara/Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func renderIcon(size: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.imageInterpolation = .high
    NSGraphicsContext.current!.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))
    source.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// (idiom size scale -> pixel size)
let specs: [(size: Int, scale: Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]

var images: [[String: String]] = []
var rendered: [Int: String] = [:]

for spec in specs {
    let pixels = spec.size * spec.scale
    let filename = "icon_\(pixels).png"
    if rendered[pixels] == nil {
        let data = renderIcon(size: CGFloat(pixels))
        try data.write(to: iconset.appendingPathComponent(filename))
        rendered[pixels] = filename
    }
    images.append([
        "idiom": "mac",
        "size": "\(spec.size)x\(spec.size)",
        "scale": "\(spec.scale)x",
        "filename": filename
    ])
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: iconset.appendingPathComponent("Contents.json"))

print("Generated \(rendered.count) icon sizes into \(iconset.path)")
