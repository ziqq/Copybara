import XCTest
@testable import Copybara

final class TextTransformTests: XCTestCase {
    func testTrimmed() {
        XCTAssertEqual(TextTransform.trimmed.apply("  hi \n"), "hi")
    }

    func testLowercased() {
        XCTAssertEqual(TextTransform.lowercased.apply("HeLLo"), "hello")
    }

    func testUppercased() {
        XCTAssertEqual(TextTransform.uppercased.apply("HeLLo"), "HELLO")
    }
}
