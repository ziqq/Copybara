// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import CoreData

/// Owns the Core Data stack that persists clip history locally on device.
///
/// The store is loaded from the `Copybara` managed object model. Pass
/// `inMemory: true` to get an ephemeral store for tests.
final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Copybara")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        // Adding attributes (e.g. copyCount) is handled by lightweight migration.
        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                Log.app.error("Core Data failed to load store: \(error.localizedDescription, privacy: .public)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Main-queue context used for reads that feed the UI.
    var viewContext: NSManagedObjectContext { container.viewContext }

    /// A private-queue context for background writes.
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }
}
