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
}
