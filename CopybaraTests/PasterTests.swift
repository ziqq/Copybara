// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import XCTest
import AppKit
@testable import Copybara

final class PasterTests: XCTestCase {
    private func makePasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("paster-test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        return pasteboard
    }

    func testStageText() {
        let pasteboard = makePasteboard()
        Paster(pasteboard: pasteboard).stage(item: ClipItemDO(kind: .text, preview: "hi"))
        XCTAssertEqual(pasteboard.string(forType: .string), "hi")
    }

    func testStageRichTextIncludesRTFAndPlain() {
        let pasteboard = makePasteboard()
        let rtf = Data([0x01, 0x02, 0x03])
        Paster(pasteboard: pasteboard).stage(item: ClipItemDO(kind: .rtf, preview: "rich", data: rtf))
        XCTAssertEqual(pasteboard.data(forType: .rtf), rtf)
        XCTAssertEqual(pasteboard.string(forType: .string), "rich")
    }

    func testStagePlainDropsRTF() {
        let pasteboard = makePasteboard()
        Paster(pasteboard: pasteboard).stage(item: ClipItemDO(kind: .rtf, preview: "rich", data: Data([0x01])), plain: true)
        XCTAssertNil(pasteboard.data(forType: .rtf))
        XCTAssertEqual(pasteboard.string(forType: .string), "rich")
    }

    func testStageImageWritesPNG() {
        let pasteboard = makePasteboard()
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        Paster(pasteboard: pasteboard).stage(item: ClipItemDO(kind: .image, preview: "img", data: png))
        XCTAssertEqual(pasteboard.data(forType: .png), png)
    }

    func testStageFileWritesURLs() {
        let pasteboard = makePasteboard()
        let data = FilePayload.archive(["/tmp/copybara-x.txt"])
        Paster(pasteboard: pasteboard).stage(item: ClipItemDO(kind: .file, preview: "copybara-x.txt", data: data))
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        XCTAssertEqual(urls?.first?.path, "/tmp/copybara-x.txt")
    }

    func testStageRealImageOffersBothNativeRepresentations() throws {
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 7, pixelsHigh: 5,
                                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                               isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let board = makePasteboard()
        defer { board.releaseGlobally() }
        Paster(pasteboard: board).stage(item: ClipItemDO(kind: .image, preview: "img", data: png))
        XCTAssertEqual(board.data(forType: .png), png)
        let tiff = try XCTUnwrap(board.data(forType: .tiff))
        XCTAssertEqual(NSBitmapImageRep(data: tiff)?.pixelsWide, 7)
        XCTAssertEqual(NSBitmapImageRep(data: tiff)?.pixelsHigh, 5)
    }

    func testCommandVUsesSessionRouteAndDeviceCommandFlag() {
        var events: [CGEvent] = []
        var taps: [CGEventTapLocation] = []
        let paster = Paster(pasteboard: makePasteboard(), accessibilityPermission: { true }, frontmostPID: { 123 },
                            postEvent: { events.append($0); taps.append($1) })
        paster.pasteIntoFrontmostApp(expectedPID: 123)
        XCTAssertEqual(events.map(\.type), [.keyDown, .keyUp])
        XCTAssertEqual(taps, [.cgSessionEventTap, .cgSessionEventTap])
        for event in events {
            XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), 9)
            XCTAssertTrue(event.flags.contains(.maskCommand))
            XCTAssertNotEqual(event.flags.rawValue & 0x8, 0)
            XCTAssertFalse(event.flags.contains(.maskShift))
        }
    }

    func testPasteNeverPostsWithoutPermissionOrToWrongTarget() {
        for (trusted, frontmost, expected) in [(false, pid_t(123), pid_t(123)), (true, 456, 123),
                                                (true, ProcessInfo.processInfo.processIdentifier, ProcessInfo.processInfo.processIdentifier)] {
            var posted = false
            let paster = Paster(pasteboard: makePasteboard(), accessibilityPermission: { trusted }, frontmostPID: { frontmost },
                                postEvent: { _, _ in posted = true })
            paster.pasteIntoFrontmostApp(expectedPID: expected)
            XCTAssertFalse(posted)
        }
    }

}
