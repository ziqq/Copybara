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

    // MARK: - Scope

    func testScopeFiltersByKind() {
        let items = [
            ClipItemDO(kind: .text, preview: "a note"),
            ClipItemDO(kind: .rtf, preview: "rich note"),
            ClipItemDO(kind: .image, preview: "Image 10×10"),
            ClipItemDO(kind: .file, preview: "file.dmg")
        ]
        XCTAssertEqual(ClipSearch.filter(items, query: "", mode: .fuzzy, scope: .all).count, 4)
        // Text scope includes rich text.
        XCTAssertEqual(Set(ClipSearch.filter(items, query: "", mode: .fuzzy, scope: .text).map(\.preview)),
                       ["a note", "rich note"])
        XCTAssertEqual(ClipSearch.filter(items, query: "", mode: .fuzzy, scope: .image).map(\.preview), ["Image 10×10"])
        XCTAssertEqual(ClipSearch.filter(items, query: "", mode: .fuzzy, scope: .file).map(\.preview), ["file.dmg"])
    }

    func testScopeAndQueryCombine() {
        let items = [
            ClipItemDO(kind: .text, preview: "hello"),
            ClipItemDO(kind: .image, preview: "hello image")
        ]
        let result = ClipSearch.filter(items, query: "hello", mode: .exact, scope: .text)
        XCTAssertEqual(result.map(\.preview), ["hello"])
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

    func testNarrowingPreviousMatchesEqualsFullSearch() {
        let items = ["copybara", "cup of tea", "clip", "copy that", "cop", "zebra"].map { ClipItemDO(preview: $0) }
        for mode in [SearchMode.fuzzy, .exact] {
            let first = ClipSearch.search(items, query: "co", mode: mode)
            XCTAssertTrue(ClipSearch.narrows("cop", from: "co", mode: mode))
            let narrowed = ClipSearch.search(first.matches, query: "cop", mode: mode)
            XCTAssertEqual(narrowed.ranked, ClipSearch.search(items, query: "cop", mode: mode).ranked)
        }
    }

    func testNarrowingIsNotUsedForRegexOrEditedQueries() {
        XCTAssertFalse(ClipSearch.narrows("co.", from: "co", mode: .regex))
        XCTAssertFalse(ClipSearch.narrows("cp", from: "co", mode: .fuzzy))
        XCTAssertFalse(ClipSearch.narrows("c", from: "co", mode: .fuzzy))
        XCTAssertFalse(ClipSearch.narrows("co", from: "", mode: .fuzzy))
    }

    func testFuzzyTiesKeepHistoryOrder() {
        let items = ["ab one", "ab two", "ab three"].map { ClipItemDO(preview: $0) }
        XCTAssertEqual(ClipSearch.filter(items, query: "ab", mode: .fuzzy).map(\.preview), ["ab one", "ab two", "ab three"])
    }
}
