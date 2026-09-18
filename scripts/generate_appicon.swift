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

    // Capybara mascot.
    let cx = size / 2
    let tan = NSColor(srgbRed: 0.88, green: 0.70, blue: 0.49, alpha: 1)
    let tanDark = NSColor(srgbRed: 0.79, green: 0.58, blue: 0.38, alpha: 1)
    let earInner = NSColor(srgbRed: 0.58, green: 0.39, blue: 0.25, alpha: 1)
    let dark = NSColor(srgbRed: 0.25, green: 0.15, blue: 0.09, alpha: 1)

    func fillRoundRect(_ rect: CGRect, _ r: CGFloat, _ color: NSColor) {
        ctx.setFillColor(color.cgColor)
        ctx.addPath(roundedRect(rect, r))
        ctx.fillPath()
    }
    func fillEllipse(_ rect: CGRect, _ color: NSColor) {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: rect)
    }

    let headW = size * 0.58
    let headH = size * 0.50
    let headRect = CGRect(x: cx - headW / 2, y: size * 0.27, width: headW, height: headH)

    // Ears (behind the head).
    let earW = size * 0.17
    let earH = size * 0.16
    for sign in [-1.0, 1.0] as [CGFloat] {
        let earRect = CGRect(x: cx + sign * size * 0.18 - earW / 2, y: headRect.maxY - earH * 0.45, width: earW, height: earH)
        fillEllipse(earRect, tanDark)
        let inW = earW * 0.5, inH = earH * 0.5
        fillEllipse(CGRect(x: earRect.midX - inW / 2, y: earRect.midY - inH / 2, width: inW, height: inH), earInner)
    }

    // Head.
    fillRoundRect(headRect, size * 0.21, tan)

    // Eyes.
    let eyeW = size * 0.058, eyeH = size * 0.075
    let eyeY = headRect.midY + size * 0.05
    for sign in [-1.0, 1.0] as [CGFloat] {
        fillEllipse(CGRect(x: cx + sign * size * 0.125 - eyeW / 2, y: eyeY, width: eyeW, height: eyeH), dark)
    }

    // Muzzle.
    let muzW = size * 0.38, muzH = size * 0.23
    let muzRect = CGRect(x: cx - muzW / 2, y: headRect.minY + size * 0.02, width: muzW, height: muzH)
    fillRoundRect(muzRect, size * 0.11, tanDark)

    // Nostrils.
    let noseW = size * 0.055, noseH = size * 0.06
    let noseY = muzRect.maxY - noseH - size * 0.03
    for sign in [-1.0, 1.0] as [CGFloat] {
        fillEllipse(CGRect(x: cx + sign * size * 0.065 - noseW / 2, y: noseY, width: noseW, height: noseH), dark)
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
