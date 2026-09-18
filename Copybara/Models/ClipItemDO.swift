import Foundation

/// Data Object: an immutable snapshot of a single clipboard entry as shown in the UI.
///
/// This is the value type the SwiftUI layer renders; it is produced from the
/// Core Data `ClipEntity` by `HistoryStore` and never mutated in place.
struct ClipItemDO: Identifiable, Hashable {
    let id: UUID
    let kind: ClipKind
    /// A short, single-line preview of the content for the list row.
    let preview: String
    let createdAt: Date
    let isPinned: Bool
    /// Bundle identifier of the app the content was copied from, when known.
    let appBundleID: String?
    /// How many times this exact content has been copied.
    let copyCount: Int
    /// Payload for non-text kinds (RTF data, PNG data, archived file paths).
    let data: Data?

    init(
        id: UUID = UUID(),
        kind: ClipKind = .text,
        preview: String,
        createdAt: Date = Date(),
        isPinned: Bool = false,
        appBundleID: String? = nil,
        copyCount: Int = 1,
        data: Data? = nil
    ) {
        self.id = id
        self.kind = kind
        self.preview = preview
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.appBundleID = appBundleID
        self.copyCount = copyCount
        self.data = data
    }
}
