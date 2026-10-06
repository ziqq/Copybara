// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit

/// Two overlapping copies, drawn at the menu bar's native size. The template
/// follows the system appearance and dims while copies are ignored.
enum MenuBarIcon {
    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()

            let back = NSBezierPath()
            back.move(to: NSPoint(x: 4.3, y: 6))
            back.line(to: NSPoint(x: 4, y: 6))
            back.curve(to: NSPoint(x: 2, y: 8), controlPoint1: NSPoint(x: 2.9, y: 6), controlPoint2: NSPoint(x: 2, y: 6.9))
            back.line(to: NSPoint(x: 2, y: 14))
            back.curve(to: NSPoint(x: 4, y: 16), controlPoint1: NSPoint(x: 2, y: 15.1), controlPoint2: NSPoint(x: 2.9, y: 16))
            back.line(to: NSPoint(x: 10, y: 16))
            back.curve(to: NSPoint(x: 12, y: 14), controlPoint1: NSPoint(x: 11.1, y: 16), controlPoint2: NSPoint(x: 12, y: 15.1))
            back.line(to: NSPoint(x: 12, y: 13.7))
            back.lineWidth = 1.6
            back.lineCapStyle = .round
            back.stroke()

            let front = NSBezierPath(roundedRect: NSRect(x: 6, y: 2, width: 10, height: 10), xRadius: 2, yRadius: 2)
            front.lineWidth = 1.6
            front.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Copybara"
        return image
    }
}
