// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import CoreData
import XCTest
@testable import Copybara

final class HistoryStoreFailureTests: XCTestCase {
    private final class UnavailableStore: NSIncrementalStore {
        static let storeType = NSStringFromClass(UnavailableStore.self)
        private(set) var fetchRequests = 0

        override func loadMetadata() throws {
            metadata = [NSStoreTypeKey: Self.storeType, NSStoreUUIDKey: UUID().uuidString]
        }

        override func execute(_ request: NSPersistentStoreRequest,
                              with context: NSManagedObjectContext?) throws -> Any {
            if request.requestType == .fetchRequestType { fetchRequests += 1 }
            throw NSError(domain: "CopybaraTests.UnavailableStore", code: 1)
        }
    }

    func testUnavailableStoreReturnsEmptyReadsWithoutAttachingAnEmptyReplacement() throws {
        NSPersistentStoreCoordinator.registerStoreClass(UnavailableStore.self, forStoreType: UnavailableStore.storeType)
        let stack = CoreDataStack(inMemory: true)
        let coordinator = stack.container.persistentStoreCoordinator
        for store in coordinator.persistentStores { try coordinator.remove(store) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("unavailable-store-\(UUID())")
        defer { try? FileManager.default.removeItem(at: url) }
        let failing = try XCTUnwrap(try coordinator.addPersistentStore(
            ofType: UnavailableStore.storeType, configurationName: nil, at: url) as? UnavailableStore)
        // A supported Core Data store reports NSError for a real fetch failure;
        // removing every store instead would raise an Objective-C exception.
        let history = HistoryStore(stack: stack)
        let initialRequests = failing.fetchRequests

        XCTAssertTrue(history.recentItems().isEmpty)
        XCTAssertTrue(history.recentItems(includePayloads: false).isEmpty)
        XCTAssertNil(history.payload(id: UUID()))
        XCTAssertEqual(history.count(), 0)
        history.clearAll()
        history.clearUnpinned()
        history.pruneExpired(olderThan: 1)
        history.trimToLimit()

        XCTAssertGreaterThan(failing.fetchRequests, initialRequests)
        XCTAssertEqual(coordinator.persistentStores.count, 1)
        XCTAssertTrue(coordinator.persistentStores.first === failing,
                      "a storage failure must not be hidden by replacing the store with an empty one")
    }
}
