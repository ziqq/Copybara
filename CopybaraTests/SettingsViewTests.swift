// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import SwiftUI
import XCTest
@testable import Copybara

@MainActor
final class SettingsViewTests: XCTestCase {
    func testSavedSnippetsRenderTheirEditableContentWithoutChangingPreferences() throws {
        let snippets = [Snippet(title: "Signature", content: "Best regards\nCopybara"),
                        Snippet(title: "Empty template", content: "")]
        let defaults = UserDefaults.standard
        let originalArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        let bundleID = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let originalPreferences = defaults.persistentDomain(forName: bundleID) as NSDictionary?
        var arguments = originalArguments
        arguments["snippets"] = try JSONEncoder().encode(snippets)
        arguments["blockedBundleIDs"] = ["com.apple.finder", "dev.copybara.missing-app"]
        // The recorder must not install its default global shortcut on a fresh
        // test host. The package treats this in-memory value as disabled.
        arguments["KeyboardShortcuts_togglePopup"] = false
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        defer { defaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain) }

        let hosting = NSHostingView(rootView: SettingsView())
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 600)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.contentView = hosting
        defer { window.close() }
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)

        var editors = descendants(of: hosting).compactMap { $0 as? NSTextView }
        for scroll in descendants(of: hosting).compactMap({ $0 as? NSScrollView }) {
            guard let document = scroll.documentView else { continue }
            for y in stride(from: CGFloat.zero, through: document.bounds.height, by: 200) {
                scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
                scroll.reflectScrolledClipView(scroll.contentView)
                hosting.layoutSubtreeIfNeeded()
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                editors.append(contentsOf: descendants(of: hosting).compactMap { $0 as? NSTextView })
            }
        }
        XCTAssertTrue(editors.contains { $0.string == snippets[0].content },
                      "the saved template content must appear in a native text editor")
        XCTAssertEqual(SnippetStore.shared.all(), snippets)
        XCTAssertEqual(defaults.persistentDomain(forName: bundleID) as NSDictionary?, originalPreferences,
                       "rendering the form must not change persisted preferences")
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
