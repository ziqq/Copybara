// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import SwiftUI
import XCTest
@testable import Copybara

@MainActor
final class PopupViewRenderingTests: XCTestCase {
    private func withPopup(_ captures: [ClipCapture], _ body: (PopupOO, NSHostingView<PopupView>) throws -> Void) throws {
        let name = "popup-rendering-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = HistoryStore(stack: CoreDataStack(inMemory: true))
        for capture in captures { store.insertSynchronously(capture) }
        let oo = PopupOO(store: store, settings: AppSettings(defaults: defaults), snippets: SnippetStore(defaults: defaults))
        oo.reset()
        let hosting = NSHostingView(rootView: PopupView(oo: oo, autoFocus: false, onCommit: { _ in }))
        try body(oo, hosting)
    }

    @discardableResult
    private func render(_ hosting: NSHostingView<PopupView>, count: Int) throws -> NSSize {
        // ObservedObject invalidates the SwiftUI graph on the next run-loop
        // turn. Wait for the new geometry, with a bounded deadline for CI.
        let expectedHeight = PopupMetrics.totalHeight(for: count)
        let deadline = Date().addingTimeInterval(2)
        repeat {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            hosting.layoutSubtreeIfNeeded()
        } while abs(hosting.fittingSize.height - expectedHeight) > 1 && Date() < deadline
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        XCTAssertEqual(size.width, PopupMetrics.width, accuracy: 1)
        return size
    }

    func testTypeFilterCompactsRenderedPopupAndClearingItRestoresHeight() throws {
        let captures = (0..<8).map {
            ClipCapture(kind: .text, text: "Text \($0)", data: nil, contentHash: nil, appBundleID: nil)
        } + [ClipCapture(kind: .image, text: "Image", data: nil, contentHash: "image", appBundleID: nil)]
        try withPopup(captures) { oo, hosting in
            let full = try render(hosting, count: captures.count)
            oo.scope = .image
            let filtered = try render(hosting, count: 1)
            XCTAssertEqual(oo.results.map(\.kind), [.image])
            XCTAssertEqual(filtered.height, PopupMetrics.totalHeight(for: 1), accuracy: 1)
            XCTAssertLessThan(filtered.height, full.height)
            oo.scope = .all
            XCTAssertEqual(try render(hosting, count: captures.count), full)
        }
    }

    func testUnmatchedSearchKeepsCompactEmptyStateAndRecoversOnClear() throws {
        let captures = [ClipCapture(kind: .text, text: "Keep this clip", data: nil, contentHash: nil, appBundleID: nil)]
        try withPopup(captures) { oo, hosting in
            oo.query = "not present anywhere"
            XCTAssertTrue(oo.results.isEmpty)
            XCTAssertEqual(try render(hosting, count: 0).height, PopupMetrics.totalHeight(for: 0), accuracy: 1)
            oo.query = ""
            XCTAssertEqual(oo.selectedItem?.preview, "Keep this clip")
            XCTAssertEqual(try render(hosting, count: 1).height, PopupMetrics.totalHeight(for: 1), accuracy: 1)
        }
    }

    func testSelectingLastResultScrollsItIntoViewWithoutGrowingPopup() throws {
        let captures = (0..<80).map {
            ClipCapture(kind: .text, text: "Clip \($0)", data: nil, contentHash: nil, appBundleID: nil)
        }
        try withPopup(captures) { oo, hosting in
            let initialSize = try render(hosting, count: captures.count)
            let window = PopupWindow()
            window.alphaValue = 0
            window.hasShadow = false
            window.contentView = hosting
            window.setContentSize(initialSize)
            window.makeKeyAndOrderFront(nil)
            defer { window.orderOut(nil) }
            _ = try render(hosting, count: captures.count)
            let scroll = try XCTUnwrap(descendants(of: hosting).compactMap { $0 as? NSScrollView }.first)
            let document = try XCTUnwrap(scroll.documentView)
            let initialTop = scroll.documentVisibleRect.minY
            XCTAssertGreaterThan(document.bounds.height, scroll.contentSize.height,
                                 "scrolling needs a laid-out document: \(document.frame)")
            oo.selectLast()
            XCTAssertEqual(try render(hosting, count: captures.count), initialSize)
            let deadline = Date().addingTimeInterval(2)
            while scroll.documentVisibleRect.maxY < document.bounds.maxY - 12, Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.01))
                hosting.layoutSubtreeIfNeeded()
            }
            XCTAssertEqual(oo.selectedIndex, captures.count - 1)
            XCTAssertGreaterThan(scroll.documentVisibleRect.minY, initialTop)
            XCTAssertEqual(scroll.documentVisibleRect.maxY, document.bounds.maxY, accuracy: 12,
                           "keyboard selection must keep the last row visible")
        }
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
