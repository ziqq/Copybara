// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import XCTest
@testable import Copybara

final class FuzzyMatcherTests: XCTestCase {
    func testEmptyQueryMatchesEverythingWithNeutralScore() {
        XCTAssertEqual(FuzzyMatcher.score("", in: "anything"), 0)
        XCTAssertTrue(FuzzyMatcher.matches("", in: ""))
    }

    func testSubsequenceMatching() {
        XCTAssertTrue(FuzzyMatcher.matches("hlo", in: "hello"))
        XCTAssertTrue(FuzzyMatcher.matches("HELLO", in: "hello")) // case-insensitive
        XCTAssertFalse(FuzzyMatcher.matches("xyz", in: "hello"))
        XCTAssertFalse(FuzzyMatcher.matches("hello!", in: "hello"))
    }

    func testConsecutiveMatchesScoreHigherThanScattered() {
        let consecutive = FuzzyMatcher.score("ell", in: "hello")
        let scattered = FuzzyMatcher.score("hlo", in: "hello")
        XCTAssertNotNil(consecutive)
        XCTAssertNotNil(scattered)
        XCTAssertGreaterThan(consecutive!, scattered!)
    }

    func testPatternSubstringIsCaseInsensitiveAndRestartsAfterPartialMatch() {
        XCTAssertTrue(FuzzyMatcher.Pattern("LLO").isContained(in: "hello"))
        XCTAssertTrue(FuzzyMatcher.Pattern("aab").isContained(in: "aaab"))
        XCTAssertTrue(FuzzyMatcher.Pattern("ПРИВЕТ").isContained(in: "ну привет"))
        XCTAssertFalse(FuzzyMatcher.Pattern("hlo").isContained(in: "hello"))
        XCTAssertTrue(FuzzyMatcher.Pattern("straße").isContained(in: "STRASSE STRAßE"))
    }

    func testCyrillicFuzzyMatch() {
        XCTAssertTrue(FuzzyMatcher.matches("првт", in: "Привет, мир"))
    }
}
