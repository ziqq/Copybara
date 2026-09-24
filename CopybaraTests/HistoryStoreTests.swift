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

    func testPinnedItemSortsFirstAndSurvivesTrim() {
        let store = makeStore(limit: 2)
        store.insertTextSynchronously("a")
        store.insertTextSynchronously("b")

        let a = try! XCTUnwrap(store.recentItems().first { $0.preview == "a" })
        store.togglePin(id: a.id)

        store.insertTextSynchronously("c")
        store.insertTextSynchronously("d") // pushes non-pinned past the cap

        let items = store.recentItems()
        XCTAssertEqual(items.first?.preview, "a", "pinned item sorts to the top")
        XCTAssertTrue(items.contains { $0.preview == "a" && $0.isPinned })
        XCTAssertFalse(items.contains { $0.preview == "b" }, "oldest non-pinned is trimmed")
    }

    func testDeduplicationIncrementsCopyCount() {
        let store = makeStore()
        store.insertTextSynchronously("a")
        store.insertTextSynchronously("a")
        store.insertTextSynchronously("a")

        let item = try! XCTUnwrap(store.recentItems().first { $0.preview == "a" })
        XCTAssertEqual(item.copyCount, 3)
    }

    func testDeleteRemovesOnlyThatItem() {
        let store = makeStore()
        store.insertTextSynchronously("x")
        store.insertTextSynchronously("y")

        let x = try! XCTUnwrap(store.recentItems().first { $0.preview == "x" })
        store.delete(id: x.id)

        let items = store.recentItems()
        XCTAssertEqual(items.map(\.preview), ["y"])
    }

    func testClearUnpinnedKeepsPinnedItems() {
        let store = makeStore()
        store.insertTextSynchronously("a")
        store.insertTextSynchronously("b")
        let a = try! XCTUnwrap(store.recentItems().first { $0.preview == "a" })
        store.togglePin(id: a.id)

        store.clearUnpinned()

        XCTAssertEqual(store.recentItems().map(\.preview), ["a"])
    }

    func testCaptureInsertStoresPayloadAndDedupsByContentHash() {
        let store = makeStore()
        let payload = Data([0x01, 0x02, 0x03, 0x04])
        let capture = ClipCapture(
            kind: .image,
            text: "Image 10×10",
            data: payload,
            contentHash: payload.sha256Hex,
            appBundleID: nil
        )

        store.insertSynchronously(capture)
        store.insertSynchronously(capture)

        let items = store.recentItems()
        XCTAssertEqual(items.count, 1, "same content hash must not duplicate")
        XCTAssertEqual(items.first?.kind, .image)
        XCTAssertEqual(items.first?.data, payload)
        XCTAssertEqual(items.first?.copyCount, 2)
    }

    func testPruneExpiredRemovesOldUnpinnedButKeepsPinned() {
        let store = makeStore()
        store.insertTextSynchronously("old")
        store.insertTextSynchronously("keepMePinned")
        let pinned = try! XCTUnwrap(store.recentItems().first { $0.preview == "keepMePinned" })
        store.togglePin(id: pinned.id)

        // Treat "now" as 2 days ahead so both items are older than 1 day.
        store.pruneExpired(olderThan: 1, now: Date().addingTimeInterval(2 * 86_400))

        let items = store.recentItems().map(\.preview)
        XCTAssertFalse(items.contains("old"))
        XCTAssertTrue(items.contains("keepMePinned"))
    }

    func testPruneExpiredZeroKeepsEverything() {
        let store = makeStore()
        store.insertTextSynchronously("a")
        store.pruneExpired(olderThan: 0, now: Date().addingTimeInterval(999 * 86_400))
        XCTAssertEqual(store.recentItems().count, 1)
    }

    func testClearAllRemovesEverythingIncludingPinned() {
        let store = makeStore()
        store.insertTextSynchronously("a")
        let a = try! XCTUnwrap(store.recentItems().first)
        store.togglePin(id: a.id)

        store.clearAll()

        XCTAssertTrue(store.recentItems().isEmpty)
    }

    func testTrimToLimitAppliesLoweredLimit() {
        let store = makeStore(limit: 10)
        for text in ["a", "b", "c", "d"] { store.insertTextSynchronously(text) }
        store.sizeLimit = 2
        store.trimToLimit()
        XCTAssertEqual(store.recentItems().map(\.preview), ["d", "c"])
    }

    func testListSnapshotSortsInStoreAndOmitsPayloads() {
        let store = makeStore()
        store.insertSynchronously(ClipCapture(kind: .image, text: "img", data: Data([1, 2]), contentHash: "h", appBundleID: nil))
        store.insertTextSynchronously("a")
        store.insertTextSynchronously("b")
        store.insertTextSynchronously("a") // copyCount 2, now newest

        let list = store.recentItems(limit: 10, includePayloads: false)
        XCTAssertEqual(list.map(\.preview), ["a", "b", "img"])
        XCTAssertNil(list.last?.data)
        XCTAssertEqual(store.payload(id: list.last!.id), Data([1, 2]))

        XCTAssertEqual(store.recentItems(limit: 10, includePayloads: false, sort: .firstCopied).map(\.preview), ["img", "b", "a"])
        XCTAssertEqual(store.recentItems(limit: 10, includePayloads: false, sort: .numberOfCopies).first?.preview, "a")
        XCTAssertEqual(store.count(), 3)
    }
}
