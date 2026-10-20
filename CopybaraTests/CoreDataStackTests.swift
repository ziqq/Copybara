// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import CoreData
import XCTest
@testable import Copybara

final class CoreDataStackTests: XCTestCase {
    func testFailedStoreOpenPreservesExistingContentsAndDoesNotAttachAnotherStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("copybara-store-error-\(UUID())")
        let storeURL = directory.appendingPathComponent("history.sqlite", isDirectory: true)
        try FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = storeURL.appendingPathComponent("preserve.txt")
        let contents = Data("existing contents must survive a failed store open".utf8)
        try contents.write(to: marker)

        // A directory cannot be opened as a SQLite database. The failure must
        // not replace that path or silently attach an unrelated empty store.
        let stack = CoreDataStack(storeURL: storeURL)

        XCTAssertTrue(stack.container.persistentStoreCoordinator.persistentStores.isEmpty)
        XCTAssertEqual(try Data(contentsOf: marker), contents)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: storeURL.path), ["preserve.txt"])
        XCTAssertTrue(stack.viewContext.automaticallyMergesChangesFromParent)
    }
}
