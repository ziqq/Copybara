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
}
