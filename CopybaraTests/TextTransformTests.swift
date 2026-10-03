// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

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
