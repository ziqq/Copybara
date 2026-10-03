// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import XCTest
@testable import Copybara

final class HashingTests: XCTestCase {
    func testStringSHA256KnownVectors() {
        XCTAssertEqual("abc".sha256Hex, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual("".sha256Hex, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testDataAndStringHashesMatch() {
        XCTAssertEqual(Data("abc".utf8).sha256Hex, "abc".sha256Hex)
    }
}
