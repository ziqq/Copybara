// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit

/// A capybara profile drawn as a template image: macOS supplies the menu-bar
/// color and dims it when copies are ignored. The 18pt vector contour stays
/// crisp on Retina displays; generous cutouts keep its features legible.
enum MenuBarIcon {
    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            NSColor.black.setFill()
            head().fill()

            context.saveGState()
            context.setBlendMode(.clear)

            let ear = NSBezierPath()
            ear.move(to: NSPoint(x: 5.7, y: 12.95))
            ear.curve(to: NSPoint(x: 5.6, y: 14.75), controlPoint1: NSPoint(x: 5.0, y: 13.65), controlPoint2: NSPoint(x: 5.15, y: 14.65))
            ear.curve(to: NSPoint(x: 6.95, y: 13.05), controlPoint1: NSPoint(x: 6.1, y: 14.8), controlPoint2: NSPoint(x: 6.9, y: 13.8))
            ear.curve(to: NSPoint(x: 5.7, y: 12.95), controlPoint1: NSPoint(x: 6.5, y: 12.8), controlPoint2: NSPoint(x: 6.05, y: 12.7))
            ear.close()
            ear.fill()

            let eye = NSBezierPath()
            eye.move(to: NSPoint(x: 9.5, y: 11.25))
            eye.curve(to: NSPoint(x: 11.45, y: 10.8), controlPoint1: NSPoint(x: 10.55, y: 11.45), controlPoint2: NSPoint(x: 11.05, y: 11.4))
            eye.curve(to: NSPoint(x: 9.5, y: 11.25), controlPoint1: NSPoint(x: 10.7, y: 10.05), controlPoint2: NSPoint(x: 9.6, y: 10.3))
            eye.close()
            eye.fill()

            NSBezierPath(ovalIn: NSRect(x: 15.25, y: 8.5, width: 1.1, height: 1.5)).fill()
            context.restoreGState()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Copybara"
        return image
    }

    /// Small ears, a long blunt muzzle, and a tapered neck form a single mark.
    private static func head() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 1.1, y: 5.1))
        path.curve(to: NSPoint(x: 5.0, y: 12.25), controlPoint1: NSPoint(x: 2.65, y: 7.1), controlPoint2: NSPoint(x: 3.1, y: 10.4))
        path.curve(to: NSPoint(x: 5.65, y: 15.4), controlPoint1: NSPoint(x: 4.4, y: 13.4), controlPoint2: NSPoint(x: 4.55, y: 15.5))
        path.curve(to: NSPoint(x: 7.35, y: 14.8), controlPoint1: NSPoint(x: 6.35, y: 15.35), controlPoint2: NSPoint(x: 6.75, y: 15.0))
        path.curve(to: NSPoint(x: 9.2, y: 14.55), controlPoint1: NSPoint(x: 7.8, y: 15.85), controlPoint2: NSPoint(x: 8.4, y: 15.75))
        path.curve(to: NSPoint(x: 15.1, y: 11.65), controlPoint1: NSPoint(x: 10.0, y: 13.1), controlPoint2: NSPoint(x: 13.4, y: 12.65))
        path.curve(to: NSPoint(x: 16.9, y: 7.0), controlPoint1: NSPoint(x: 17.2, y: 10.9), controlPoint2: NSPoint(x: 17.45, y: 9.1))
        path.curve(to: NSPoint(x: 12.8, y: 5.4), controlPoint1: NSPoint(x: 16.4, y: 5.2), controlPoint2: NSPoint(x: 14.3, y: 5.3))
        path.curve(to: NSPoint(x: 9.75, y: 2.65), controlPoint1: NSPoint(x: 10.5, y: 5.45), controlPoint2: NSPoint(x: 9.9, y: 4.6))
        path.curve(to: NSPoint(x: 4.3, y: 3.4), controlPoint1: NSPoint(x: 9.1, y: 1.6), controlPoint2: NSPoint(x: 6.35, y: 2.4))
        path.close()
        return path
    }
}
