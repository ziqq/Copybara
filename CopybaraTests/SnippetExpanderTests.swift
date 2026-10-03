// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import XCTest
@testable import Copybara

final class SnippetExpanderTests: XCTestCase {
    func testNoPlaceholdersUnchanged() {
        XCTAssertEqual(SnippetExpander.expand("plain text"), "plain text")
    }

    func testClipboardPlaceholder() {
        XCTAssertEqual(SnippetExpander.expand("Re: ${clipboard}", clipboard: "hello"), "Re: hello")
    }

    func testDatePlaceholderIsReplaced() {
        let out = SnippetExpander.expand("d=${date}", now: Date(timeIntervalSince1970: 1_000_000))
        XCTAssertFalse(out.contains("${date}"))
        XCTAssertTrue(out.hasPrefix("d="))
    }

    func testUUIDPlaceholderReplacedWithUUID() {
        let out = SnippetExpander.expand("${uuid}")
        XCTAssertFalse(out.contains("${uuid}"))
        XCTAssertNotNil(UUID(uuidString: out))
    }
}
