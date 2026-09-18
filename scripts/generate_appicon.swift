#!/usr/bin/env swift
import AppKit
import Foundation

// Renders the Copybara app icon at all required macOS sizes into
// Copybara/Resources/Assets.xcassets/AppIcon.appiconset and writes its
// Contents.json. Re-run after tweaking the drawing.
//
//   swift scripts/generate_appicon.swift

let accent = NSColor(srgbRed: 0.76, green: 0.447, blue: 0.235, alpha: 1)
let accentDark = NSColor(srgbRed: 0.60, green: 0.33, blue: 0.16, alpha: 1)

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func renderIcon(size: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // Background squircle with a warm vertical gradient.
    let inset = size * 0.06
    let bgRect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    ctx.saveGState()
    ctx.addPath(roundedRect(bgRect, bgRect.width * 0.2237))
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [accent.cgColor, accentDark.cgColor] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: bgRect.midX, y: bgRect.maxY),
        end: CGPoint(x: bgRect.midX, y: bgRect.minY),
        options: []
    )
    ctx.restoreGState()

    // Clipboard board (white).
    let boardW = size * 0.44
    let boardH = size * 0.54
    let boardRect = CGRect(x: (size - boardW) / 2, y: (size - boardH) / 2 - size * 0.01, width: boardW, height: boardH)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.addPath(roundedRect(boardRect, size * 0.055))
    ctx.fillPath()

    // Clip at the top.
    let clipW = boardW * 0.38
    let clipH = boardH * 0.14
    let clipRect = CGRect(x: (size - clipW) / 2, y: boardRect.maxY - clipH * 0.62, width: clipW, height: clipH)
    ctx.setFillColor(accentDark.cgColor)
    ctx.addPath(roundedRect(clipRect, clipH * 0.42))
    ctx.fillPath()

    // Three "lines of text".
    ctx.setFillColor(NSColor(white: 0.80, alpha: 1).cgColor)
    let lineH = boardH * 0.075
    let lineW = boardW * 0.62
    let lineX = boardRect.minX + (boardW - lineW) / 2
    for index in 0..<3 {
        let lineY = boardRect.minY + boardH * 0.56 - CGFloat(index) * (boardH * 0.19)
        ctx.addPath(roundedRect(CGRect(x: lineX, y: lineY, width: lineW, height: lineH), lineH / 2))
        ctx.fillPath()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Copybara/Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

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
