// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import XCTest
import AppKit
@testable import Copybara

final class PasteboardReaderTests: XCTestCase {
    private func makePasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("copybara-test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        return pasteboard
    }

    func testReadsPlainText() {
        let pasteboard = makePasteboard()
        pasteboard.setString("hello", forType: .string)

        let capture = PasteboardReader.read(pasteboard, appBundleID: "com.example")
        XCTAssertEqual(capture?.kind, .text)
        XCTAssertEqual(capture?.text, "hello")
        XCTAssertNil(capture?.data)
        XCTAssertEqual(capture?.appBundleID, "com.example")
    }

    func testReadsRichText() {
        let pasteboard = makePasteboard()
        let attributed = NSAttributedString(string: "rich")
        let rtf = attributed.rtf(from: NSRange(location: 0, length: attributed.length), documentAttributes: [:])!
        pasteboard.setData(rtf, forType: .rtf)
        pasteboard.setString("rich", forType: .string)

        let capture = PasteboardReader.read(pasteboard, appBundleID: nil)
        XCTAssertEqual(capture?.kind, .rtf)
        XCTAssertEqual(capture?.text, "rich")
        XCTAssertNotNil(capture?.data)
    }

    func testReadsImage() {
        let pasteboard = makePasteboard()
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 4, height: 4))
        image.unlockFocus()
        pasteboard.setData(image.tiffRepresentation!, forType: .tiff)

        let capture = PasteboardReader.read(pasteboard, appBundleID: nil)
        XCTAssertEqual(capture?.kind, .image)
        XCTAssertNotNil(capture?.data)
    }

    func testFileURLsTakePriorityOverText() {
        let pasteboard = makePasteboard()
        pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/copybara-test.txt") as NSURL])

        let capture = PasteboardReader.read(pasteboard, appBundleID: nil)
        XCTAssertEqual(capture?.kind, .file)
        XCTAssertNotNil(capture?.data)
    }

    func testEmptyPasteboardReturnsNil() {
        XCTAssertNil(PasteboardReader.read(makePasteboard(), appBundleID: nil))
    }

    func testFilePayloadRoundTrip() throws {
        let paths = ["/tmp/a.txt", "/tmp/b.png"]
        let data = try XCTUnwrap(FilePayload.archive(paths))
        XCTAssertEqual(FilePayload.paths(from: data), paths)
    }

    func testWhitespaceOnlyTextIsNotRecorded() {
        let board = makePasteboard()
        defer { board.releaseGlobally() }
        board.setString(" \t\r\n ", forType: .string)
        XCTAssertNil(PasteboardReader.read(board, appBundleID: nil))
    }

    func testBrokenImageFallsBackToAvailablePlainText() {
        let board = makePasteboard()
        defer { board.releaseGlobally() }
        board.setData(Data([1, 2]), forType: .png)
        board.setString("image description", forType: .string)
        let capture = PasteboardReader.read(board, appBundleID: "com.example")
        XCTAssertEqual(capture?.kind, .text)
        XCTAssertEqual(capture?.text, "image description")
        XCTAssertEqual(capture?.appBundleID, "com.example")
    }

    func testBrokenRichTextRetainsAvailablePlainPreview() {
        let board = makePasteboard()
        defer { board.releaseGlobally() }
        board.setData(Data([1, 2]), forType: .rtf)
        board.setString("plain preview", forType: .string)
        XCTAssertEqual(PasteboardReader.read(board, appBundleID: nil)?.text, "plain preview")
    }

    func testBrokenRichTextWithoutPlainPreviewIsNotRecorded() {
        let board = makePasteboard()
        defer { board.releaseGlobally() }
        board.setData(Data([1, 2]), forType: .rtf)
        XCTAssertNil(PasteboardReader.read(board, appBundleID: "com.example"))
        board.clearContents()
        board.setString("next ordinary copy", forType: .string)
        XCTAssertEqual(PasteboardReader.read(board, appBundleID: "com.example")?.text, "next ordinary copy")
    }

    func testFilePayloadSupportsEmptyListAndRejectsInvalidArchive() throws {
        let data = try XCTUnwrap(FilePayload.archive([]))
        XCTAssertEqual(FilePayload.paths(from: data), [])
        XCTAssertNil(FilePayload.paths(from: Data([1, 2])))
    }
}
