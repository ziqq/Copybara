// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import XCTest
import CoreData
import AppKit
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

        XCTAssertEqual(store.recentItems(limit: 10, includePayloads: false, sort: .firstCopied).map(\.preview), ["img", "a", "b"])
        XCTAssertEqual(store.recentItems(limit: 10, includePayloads: false, sort: .numberOfCopies).first?.preview, "a")
        XCTAssertEqual(store.count(), 3)
    }

    func testFirstCopyDateSurvivesRecopyInBothStoreAndPopupSorts() throws {
        let store = makeStore()
        store.insertTextSynchronously("a")
        let first = try XCTUnwrap(store.recentItems().first)
        store.insertTextSynchronously("b")
        store.insertTextSynchronously("a")
        let latest = store.recentItems()
        let recopied = try XCTUnwrap(latest.first)
        XCTAssertEqual(recopied.preview, "a")
        XCTAssertEqual(recopied.firstCopiedAt, first.createdAt)
        XCTAssertGreaterThan(recopied.createdAt, first.createdAt)
        XCTAssertEqual(store.recentItems(sort: .firstCopied).map(\.preview), ["a", "b"])
        XCTAssertEqual(ClipSearch.sort(latest, by: .firstCopied).map(\.preview), ["a", "b"])
        XCTAssertEqual(recopied.with(isPinned: true).firstCopiedAt, first.createdAt)
        XCTAssertEqual(recopied.with(data: Data([1])).firstCopiedAt, first.createdAt)
    }

    func testRichTextFormattingIsNotLostThroughDeduplication() throws {
        let store = makeStore()
        let board = NSPasteboard(name: .init("rich-dedup-\(UUID())"))
        defer { board.releaseGlobally() }
        board.setString("same text", forType: .string)
        store.insertSynchronously(try XCTUnwrap(PasteboardReader.read(board, appBundleID: nil)))
        for color in [NSColor.red, NSColor.blue] {
            board.clearContents()
            let attributed = NSAttributedString(string: "same text", attributes: [.foregroundColor: color])
            let data = try XCTUnwrap(attributed.rtf(from: NSRange(location: 0, length: attributed.length), documentAttributes: [:]))
            board.setData(data, forType: .rtf)
            let capture = try XCTUnwrap(PasteboardReader.read(board, appBundleID: nil))
            store.insertSynchronously(capture)
            store.insertSynchronously(capture)
            XCTAssertTrue(store.recentItems().contains { $0.kind == .rtf && $0.data == data && $0.copyCount == 2 })
        }
        XCTAssertEqual(store.count(), 3, "plain text and two different rich representations must survive")
    }

    func testIdenticalHashesAcrossKindsDoNotDiscardPayload() {
        let store = makeStore()
        store.insertSynchronously(ClipCapture(kind: .text, text: "same", data: nil, contentHash: "legacy", appBundleID: nil))
        store.insertSynchronously(ClipCapture(kind: .rtf, text: "same", data: Data([1]), contentHash: "legacy", appBundleID: nil))
        XCTAssertEqual(store.count(), 2)
        XCTAssertEqual(store.recentItems().first?.data, Data([1]))
    }

    func testExistingSQLiteStoreMigratesWithoutLosingHistoryOrPayloads() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("copybara-migration-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.sqlite")
        let bundle = Bundle(for: AppDelegate.self)
        let modelURL = try XCTUnwrap(bundle.url(forResource: "Copybara", withExtension: "momd"))
            .appendingPathComponent("Copybara.mom")
        let legacyModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
        XCTAssertNil(legacyModel.entitiesByName["ClipEntity"]?.attributesByName["firstCopiedAt"])
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: legacyModel)
        let legacyStore = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let id = UUID(), oldDate = Date(timeIntervalSince1970: 1_000)
        let item = NSEntityDescription.insertNewObject(forEntityName: "ClipEntity", into: context)
        item.setValue(id, forKey: "id")
        item.setValue("legacy", forKey: "text")
        item.setValue("rtf", forKey: "kind")
        item.setValue(Data([7, 8, 9]), forKey: "data")
        item.setValue("hash", forKey: "contentHash")
        item.setValue(oldDate, forKey: "createdAt")
        item.setValue(true, forKey: "isPinned")
        item.setValue(4, forKey: "copyCount")
        try context.save()
        context.reset()
        try coordinator.remove(legacyStore)

        let stack = CoreDataStack(storeURL: url)
        let store = HistoryStore(stack: stack)
        let migrated = try XCTUnwrap(store.recentItems().first)
        XCTAssertEqual(migrated.id, id)
        XCTAssertEqual(migrated.firstCopiedAt, oldDate)
        XCTAssertEqual(migrated.data, Data([7, 8, 9]))
        XCTAssertTrue(migrated.isPinned)
        store.insertSynchronously(ClipCapture(kind: .rtf, text: "legacy", data: Data([7, 8, 9]), contentHash: "hash", appBundleID: nil))
        let recopied = try XCTUnwrap(store.recentItems(includePayloads: false).first)
        XCTAssertEqual(recopied.firstCopiedAt, oldDate)
        XCTAssertEqual(recopied.copyCount, 5)
        XCTAssertGreaterThan(recopied.createdAt, oldDate)
        for persistentStore in stack.container.persistentStoreCoordinator.persistentStores {
            try stack.container.persistentStoreCoordinator.remove(persistentStore)
        }
    }

}
