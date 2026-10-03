// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit

/// The menu-bar icon: a capybara head in profile, drawn as a template image so
/// macOS tints it for light/dark menu bars and dims it when copies are ignored.
///
/// Drawn in code (18×18pt, y-up) rather than shipped as a bitmap, so it stays
/// crisp at any backing scale. Features are punched out of the silhouette.
enum MenuBarIcon {
    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            NSColor.black.setFill()
            NSColor.black.setStroke()

            NSBezierPath(ovalIn: NSRect(x: 3.3, y: 11.0, width: 3.6, height: 3.6)).fill() // ear
            head().fill()

            context.setBlendMode(.clear)
            NSBezierPath(ovalIn: NSRect(x: 7.9, y: 8.4, width: 2.2, height: 2.2)).fill() // eye
            NSBezierPath(roundedRect: NSRect(x: 14.8, y: 6.5, width: 1.2, height: 1.8), xRadius: 0.6, yRadius: 0.6).fill() // nostril
            let mouth = NSBezierPath()
            mouth.move(to: NSPoint(x: 12.9, y: 4.5))
            mouth.line(to: NSPoint(x: 15.3, y: 4.5))
            mouth.lineWidth = 1.0
            mouth.lineCapStyle = .round
            mouth.stroke()
            context.setBlendMode(.normal)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Copybara"
        return image
    }

    /// Boxy head facing right: rounded crown, long flat snout, blunt nose.
    private static func head() -> NSBezierPath {
        let scale: CGFloat = 1.07
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: 1 + x * scale, y: 1.9 + y * scale) }
        let path = NSBezierPath()
        path.move(to: p(0, 2.2))
        path.curve(to: p(4.6, 9.8), controlPoint1: p(-0.4, 7.2), controlPoint2: p(1.4, 9.8))
        path.line(to: p(11.6, 8.1))
        path.curve(to: p(15, 4.4), controlPoint1: p(14, 7.6), controlPoint2: p(15, 6.6))
        path.line(to: p(15, 2.6))
        path.curve(to: p(13, 0), controlPoint1: p(15, 1), controlPoint2: p(14.2, 0))
        path.line(to: p(3, 0))
        path.curve(to: p(0, 2.2), controlPoint1: p(1.2, 0), controlPoint2: p(0.2, 0.7))
        path.close()
        return path
    }
}
