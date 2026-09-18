import XCTest
@testable import Copybara

final class ClipSearchTests: XCTestCase {
    private func item(_ text: String, pinned: Bool = false, copies: Int = 1, at date: Date = Date()) -> ClipItemDO {
        ClipItemDO(preview: text, createdAt: date, isPinned: pinned, copyCount: copies)
    }

    // MARK: - Filtering

    func testEmptyQueryReturnsEverything() {
        let items = [item("a"), item("b")]
        XCTAssertEqual(ClipSearch.filter(items, query: "", mode: .fuzzy).count, 2)
    }

    func testExactMatchIsCaseInsensitiveSubstring() {
        let items = [item("Hello World"), item("goodbye")]
        let result = ClipSearch.filter(items, query: "hello", mode: .exact)
        XCTAssertEqual(result.map(\.preview), ["Hello World"])
    }

    func testFuzzyMatchesSubsequence() {
        let items = [item("hello"), item("world")]
        let result = ClipSearch.filter(items, query: "hlo", mode: .fuzzy)
        XCTAssertEqual(result.map(\.preview), ["hello"])
    }

    func testRegexMatches() {
        let items = [item("order-123"), item("order-abc"), item("nope")]
        let result = ClipSearch.filter(items, query: #"order-\d+"#, mode: .regex)
        XCTAssertEqual(result.map(\.preview), ["order-123"])
    }

    func testInvalidRegexReturnsNoResults() {
        let items = [item("anything")]
        XCTAssertTrue(ClipSearch.filter(items, query: "[unterminated", mode: .regex).isEmpty)
    }

    // MARK: - Sorting

    func testSortPinnedFirstThenLastCopied() {
        let old = Date(timeIntervalSince1970: 1000)
        let new = Date(timeIntervalSince1970: 2000)
        let items = [
            item("old", at: old),
            item("pinned", pinned: true, at: old),
            item("new", at: new)
        ]
        let sorted = ClipSearch.sort(items, by: .lastCopied)
        XCTAssertEqual(sorted.map(\.preview), ["pinned", "new", "old"])
    }

    func testSortByNumberOfCopies() {
        let items = [item("a", copies: 1), item("b", copies: 5), item("c", copies: 3)]
        let sorted = ClipSearch.sort(items, by: .numberOfCopies)
        XCTAssertEqual(sorted.map(\.preview), ["b", "c", "a"])
    }
}
