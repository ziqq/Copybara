import CoreData

/// Local, on-device store of clipboard history backed by Core Data.
///
/// Access to the `ClipEntity` managed object is done via key-value coding so the
/// store does not depend on the Xcode-generated subclass symbol at compile time.
final class HistoryStore {
    private static let entityName = "ClipEntity"

    private let stack: CoreDataStack

    /// Maximum number of non-pinned items to retain. Pinned items are never trimmed.
    var sizeLimit: Int

    init(stack: CoreDataStack = .shared, sizeLimit: Int = 200) {
        self.stack = stack
        self.sizeLimit = sizeLimit
    }

    // MARK: - Writes

    /// Inserts a text clip on a background context, de-duplicating against an
    /// existing identical entry (bumped to the top instead of duplicated), then
    /// enforces the size cap.
    func insertText(_ text: String, appBundleID: String? = nil) {
        let context = stack.newBackgroundContext()
        context.perform {
            self.performInsert(text: text, appBundleID: appBundleID, in: context)
        }
    }

    /// Synchronous insert used by tests; runs on the view context so a subsequent
    /// `recentItems()` read observes it immediately.
    func insertTextSynchronously(_ text: String, appBundleID: String? = nil) {
        let context = stack.viewContext
        context.performAndWait {
            self.performInsert(text: text, appBundleID: appBundleID, in: context)
        }
    }

    private func performInsert(text: String, appBundleID: String?, in context: NSManagedObjectContext) {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
        request.predicate = NSPredicate(format: "text == %@", text)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            existing.setValue(Date(), forKey: "createdAt")
        } else {
            let item = NSEntityDescription.insertNewObject(forEntityName: Self.entityName, into: context)
            item.setValue(UUID(), forKey: "id")
            item.setValue(text, forKey: "text")
            item.setValue(ClipKind.text.rawValue, forKey: "kind")
            item.setValue(Date(), forKey: "createdAt")
            item.setValue(false, forKey: "isPinned")
            item.setValue(appBundleID, forKey: "appBundleID")
        }

        trim(in: context)
        try? context.save()
    }

    /// Toggles the pinned state of a single item. Runs synchronously on the view
    /// context so a subsequent `recentItems()` read reflects it immediately.
    func togglePin(id: UUID) {
        let context = stack.viewContext
        context.performAndWait {
            guard let object = object(with: id, in: context) else { return }
            let pinned = object.value(forKey: "isPinned") as? Bool ?? false
            object.setValue(!pinned, forKey: "isPinned")
            try? context.save()
        }
    }

    /// Deletes a single item by id.
    func delete(id: UUID) {
        let context = stack.viewContext
        context.performAndWait {
            guard let object = object(with: id, in: context) else { return }
            context.delete(object)
            try? context.save()
        }
    }

    private func object(with id: UUID, in context: NSManagedObjectContext) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    /// Removes every stored clip.
    func clearAll() {
        let context = stack.newBackgroundContext()
        context.perform {
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: Self.entityName)
            let delete = NSBatchDeleteRequest(fetchRequest: fetch)
            delete.resultType = .resultTypeObjectIDs
            if let result = try? context.execute(delete) as? NSBatchDeleteResult,
               let ids = result.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: ids],
                    into: [self.stack.viewContext]
                )
            }
        }
    }

    // MARK: - Reads

    /// Fetches items ordered pinned-first, then newest-first.
    func recentItems(limit: Int = 200) -> [ClipItemDO] {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
        request.sortDescriptors = [
            NSSortDescriptor(key: "isPinned", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        request.fetchLimit = limit

        let objects = (try? stack.viewContext.fetch(request)) ?? []
        return objects.map(Self.makeDataObject)
    }

    // MARK: - Helpers

    private func trim(in context: NSManagedObjectContext) {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
        request.predicate = NSPredicate(format: "isPinned == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let objects = (try? context.fetch(request)) ?? []
        guard objects.count > sizeLimit else { return }
        for stale in objects[sizeLimit...] {
            context.delete(stale)
        }
    }

    private static func makeDataObject(from object: NSManagedObject) -> ClipItemDO {
        ClipItemDO(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            kind: ClipKind(rawValue: object.value(forKey: "kind") as? String ?? "text") ?? .text,
            preview: object.value(forKey: "text") as? String ?? "",
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            isPinned: object.value(forKey: "isPinned") as? Bool ?? false,
            appBundleID: object.value(forKey: "appBundleID") as? String
        )
    }
}
