import XCTest
@testable import Copybara

final class HistoryStoreTests: XCTestCase {
    private func makeStore(limit: Int = 200) -> HistoryStore {
        let stack = CoreDataStack(inMemory: true)
        return HistoryStore(stack: stack, sizeLimit: limit)
    }

    func testInsertAndFetch() {
        let store = makeStore()
        store.insertTextSynchronously("hello")

        let items = store.recentItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.preview, "hello")
    }

    func testDeduplicationBumpsExistingInsteadOfDuplicating() {
        let store = makeStore()
        store.insertTextSynchronously("a")
        store.insertTextSynchronously("b")
        store.insertTextSynchronously("a") // duplicate of the first entry

        let items = store.recentItems()
        XCTAssertEqual(items.count, 2, "duplicate content must not create a new row")
        XCTAssertEqual(items.first?.preview, "a", "the re-copied item is bumped to the top")
    }

    func testSizeCapTrimsOldestNonPinned() {
        let store = makeStore(limit: 3)
        for index in 1...5 {
            store.insertTextSynchronously("item\(index)")
        }

        let items = store.recentItems()
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items.map(\.preview), ["item5", "item4", "item3"])
    }
}
