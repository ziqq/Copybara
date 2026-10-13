#!/usr/bin/env swift
// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

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

    // A long, blunt muzzle and small ears make the capybara readable in profile.
    // Work in unit coordinates so every asset is rendered from the same paths.
    ctx.saveGState()
    ctx.scaleBy(x: size, y: size)
    let fur = NSColor(srgbRed: 0.92, green: 0.75, blue: 0.54, alpha: 1)
    let muzzle = NSColor(srgbRed: 0.83, green: 0.62, blue: 0.40, alpha: 1)
    let earInner = NSColor(srgbRed: 0.61, green: 0.41, blue: 0.25, alpha: 1)
    let dark = NSColor(srgbRed: 0.27, green: 0.16, blue: 0.09, alpha: 1)

    // Ear behind the head; much smaller than the previous round bear-like ears.
    ctx.setFillColor(muzzle.cgColor)
    ctx.fillEllipse(in: CGRect(x: 0.29, y: 0.655, width: 0.125, height: 0.15))
    ctx.setFillColor(earInner.cgColor)
    ctx.fillEllipse(in: CGRect(x: 0.326, y: 0.704, width: 0.054, height: 0.061))

    let head = CGMutablePath()
    head.move(to: CGPoint(x: 0.245, y: 0.255))
    head.addCurve(to: CGPoint(x: 0.19, y: 0.33),
                  control1: CGPoint(x: 0.205, y: 0.255), control2: CGPoint(x: 0.19, y: 0.285))
    head.addLine(to: CGPoint(x: 0.19, y: 0.475))
    head.addCurve(to: CGPoint(x: 0.375, y: 0.71),
                  control1: CGPoint(x: 0.19, y: 0.635), control2: CGPoint(x: 0.255, y: 0.71))
    head.addCurve(to: CGPoint(x: 0.57, y: 0.64),
                  control1: CGPoint(x: 0.47, y: 0.71), control2: CGPoint(x: 0.52, y: 0.66))
    head.addLine(to: CGPoint(x: 0.73, y: 0.605))
    head.addCurve(to: CGPoint(x: 0.845, y: 0.49),
                  control1: CGPoint(x: 0.81, y: 0.585), control2: CGPoint(x: 0.845, y: 0.55))
    head.addLine(to: CGPoint(x: 0.845, y: 0.425))
    head.addCurve(to: CGPoint(x: 0.745, y: 0.335),
                  control1: CGPoint(x: 0.845, y: 0.37), control2: CGPoint(x: 0.815, y: 0.335))
    head.addLine(to: CGPoint(x: 0.52, y: 0.335))
    head.addCurve(to: CGPoint(x: 0.455, y: 0.255),
                  control1: CGPoint(x: 0.49, y: 0.335), control2: CGPoint(x: 0.49, y: 0.255))
    head.closeSubpath()
    ctx.setFillColor(fur.cgColor)
    ctx.addPath(head)
    ctx.fillPath()

    // A broad muzzle follows the silhouette rather than forming a round snout.
    ctx.saveGState()
    ctx.addPath(head)
    ctx.clip()
    let snout = CGMutablePath()
    snout.move(to: CGPoint(x: 0.61, y: 0.585))
    snout.addCurve(to: CGPoint(x: 0.625, y: 0.335),
                   control1: CGPoint(x: 0.665, y: 0.49), control2: CGPoint(x: 0.59, y: 0.40))
    snout.addLine(to: CGPoint(x: 0.90, y: 0.30))
    snout.addLine(to: CGPoint(x: 0.90, y: 0.62))
    snout.closeSubpath()
    ctx.setFillColor(muzzle.cgColor)
    ctx.addPath(snout)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.setFillColor(dark.cgColor)
    ctx.fillEllipse(in: CGRect(x: 0.445, y: 0.565, width: 0.05, height: 0.061))
    ctx.fillEllipse(in: CGRect(x: 0.765, y: 0.48, width: 0.04, height: 0.033))

    // Omit the thin mouth at 16/32 px; the eye, nostril, and silhouette carry it.
    if size >= 64 {
        let mouth = CGMutablePath()
        mouth.move(to: CGPoint(x: 0.705, y: 0.425))
        mouth.addCurve(to: CGPoint(x: 0.843, y: 0.43),
                       control1: CGPoint(x: 0.755, y: 0.412), control2: CGPoint(x: 0.815, y: 0.416))
        ctx.setStrokeColor(dark.withAlphaComponent(0.65).cgColor)
        ctx.setLineWidth(0.012)
        ctx.setLineCap(.round)
        ctx.addPath(mouth)
        ctx.strokePath()
    }
    ctx.restoreGState()

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
