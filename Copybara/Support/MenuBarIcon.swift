// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit

/// The app's two-layer C mark, drawn at the menu bar's native size. The template
/// follows the system appearance and dims while copies are ignored.
enum MenuBarIcon {
    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()

            let outer = NSBezierPath()
            outer.move(to: NSPoint(x: 14.2, y: 16))
            outer.line(to: NSPoint(x: 9, y: 16))
            outer.curve(to: NSPoint(x: 2, y: 9),
                        controlPoint1: NSPoint(x: 5.134, y: 16), controlPoint2: NSPoint(x: 2, y: 12.866))
            outer.curve(to: NSPoint(x: 9, y: 2),
                        controlPoint1: NSPoint(x: 2, y: 5.134), controlPoint2: NSPoint(x: 5.134, y: 2))
            outer.line(to: NSPoint(x: 14.2, y: 2))

            let inner = NSBezierPath()
            inner.move(to: NSPoint(x: 14.2, y: 12.5))
            inner.line(to: NSPoint(x: 9, y: 12.5))
            inner.curve(to: NSPoint(x: 5.5, y: 9),
                        controlPoint1: NSPoint(x: 7.067, y: 12.5), controlPoint2: NSPoint(x: 5.5, y: 10.933))
            inner.curve(to: NSPoint(x: 9, y: 5.5),
                        controlPoint1: NSPoint(x: 5.5, y: 7.067), controlPoint2: NSPoint(x: 7.067, y: 5.5))
            inner.line(to: NSPoint(x: 14.2, y: 5.5))

            for path in [outer, inner] {
                path.lineWidth = 2
                path.lineCapStyle = .round
                path.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Copybara"
        return image
    }
}
