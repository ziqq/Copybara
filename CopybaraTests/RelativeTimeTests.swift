import XCTest
@testable import Copybara

final class RelativeTimeTests: XCTestCase {
    func testShortIsNonEmpty() {
        XCTAssertFalse(RelativeTime.short(from: Date().addingTimeInterval(-3600)).isEmpty)
    }

    func testAbsoluteIsNonEmpty() {
        XCTAssertFalse(RelativeTime.absolute(from: Date(timeIntervalSince1970: 1_000_000)).isEmpty)
    }
}
