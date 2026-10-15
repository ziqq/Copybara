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

    func testEmojiQueryMatchesInOrderAndRejectsReversedSequence() {
        let pattern = FuzzyMatcher.Pattern("😀b")
        XCTAssertNotNil(pattern.score(in: "start 😀 then B"))
        XCTAssertNil(pattern.score(in: "B before 😀"))
        XCTAssertNil(pattern.score(in: "no emoji here"))
        XCTAssertTrue(pattern.isContained(in: "prefix 😀B suffix"))
        XCTAssertFalse(pattern.isContained(in: "😀 separated B"))
    }

    func testMultiCharacterCaseMappingUsesUnicodeFallback() {
        let pattern = FuzzyMatcher.Pattern("ßa")
        XCTAssertNotNil(pattern.score(in: "Fußball"))
        XCTAssertNil(pattern.score(in: "only a"))
        XCTAssertTrue(pattern.isContained(in: "ßA"))
        XCTAssertFalse(pattern.isContained(in: "unrelated"))
    }

    func testSubstringSearchFindsMatchAfterOverlappingPrefix() {
        let pattern = FuzzyMatcher.Pattern("ababaca")
        XCTAssertTrue(pattern.isContained(in: "zzabababacazz"))
        XCTAssertFalse(pattern.isContained(in: "ababababab"))
        XCTAssertFalse(pattern.isContained(in: "ababac"))
    }

    func testPreparedEmptyPatternMatchesEmptyAndNonemptyCandidates() {
        let pattern = FuzzyMatcher.Pattern("")
        for candidate in ["", "anything", "😀"] {
            XCTAssertEqual(pattern.score(in: candidate), 0)
            XCTAssertTrue(pattern.isContained(in: candidate))
        }
    }
}
