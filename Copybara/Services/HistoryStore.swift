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

    /// Inserts a captured clip (any kind) on a background context.
    func insert(_ capture: ClipCapture) {
        let context = stack.newBackgroundContext()
        context.perform {
            self.performInsert(capture, in: context)
        }
    }

    /// Inserts a plain-text clip. Convenience over `insert(_:)`.
    func insertText(_ text: String, appBundleID: String? = nil) {
        insert(ClipCapture(kind: .text, text: text, data: nil, contentHash: nil, appBundleID: appBundleID))
    }

    /// Synchronous text insert used by tests; runs on the view context so a
    /// subsequent `recentItems()` read observes it immediately.
    func insertTextSynchronously(_ text: String, appBundleID: String? = nil) {
        let context = stack.viewContext
        context.performAndWait {
            self.performInsert(
                ClipCapture(kind: .text, text: text, data: nil, contentHash: nil, appBundleID: appBundleID),
                in: context
            )
        }
    }

    /// Synchronous capture insert used by tests.
    func insertSynchronously(_ capture: ClipCapture) {
        let context = stack.viewContext
        context.performAndWait {
            self.performInsert(capture, in: context)
        }
    }

    private func performInsert(_ capture: ClipCapture, in context: NSManagedObjectContext) {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
        // De-duplicate by content hash when present, else by exact text.
        if let hash = capture.contentHash {
            request.predicate = NSPredicate(format: "contentHash == %@", hash)
        } else {
            request.predicate = NSPredicate(format: "contentHash == nil AND text == %@", capture.text)
        }
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            existing.setValue(Date(), forKey: "createdAt")
            let count = existing.value(forKey: "copyCount") as? Int ?? 1
            existing.setValue(count + 1, forKey: "copyCount")
        } else {
            let item = NSEntityDescription.insertNewObject(forEntityName: Self.entityName, into: context)
            item.setValue(UUID(), forKey: "id")
            item.setValue(capture.text, forKey: "text")
            item.setValue(capture.kind.rawValue, forKey: "kind")
            item.setValue(capture.data, forKey: "data")
            item.setValue(capture.contentHash, forKey: "contentHash")
            item.setValue(Date(), forKey: "createdAt")
            item.setValue(false, forKey: "isPinned")
            item.setValue(capture.appBundleID, forKey: "appBundleID")
            item.setValue(1, forKey: "copyCount")
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

    /// Removes every stored clip, including pinned ones.
    func clearAll() {
        deleteMatching(nil)
    }

    /// Removes every non-pinned clip, keeping pinned favorites.
    func clearUnpinned() {
        deleteMatching(NSPredicate(format: "isPinned == NO"))
    }

    private func deleteMatching(_ predicate: NSPredicate?) {
        let context = stack.viewContext
        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
            request.predicate = predicate
            let objects = (try? context.fetch(request)) ?? []
            objects.forEach(context.delete)
            try? context.save()
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
            appBundleID: object.value(forKey: "appBundleID") as? String,
            copyCount: object.value(forKey: "copyCount") as? Int ?? 1,
            data: object.value(forKey: "data") as? Data
        )
    }
}
