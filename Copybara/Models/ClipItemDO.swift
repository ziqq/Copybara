import Foundation

/// Data Object: an immutable snapshot of a single clipboard entry as shown in the UI.
///
/// This is the value type the SwiftUI layer renders; it is produced from the
/// Core Data `ClipEntity` by `HistoryStore` and never mutated in place.
struct ClipItemDO: Identifiable, Hashable {
    let id: UUID
    let kind: ClipKind
    /// The clip's text content (full text for text clips), used for search and paste.
    let preview: String
    let createdAt: Date
    let isPinned: Bool
    /// Bundle identifier of the app the content was copied from, when known.
    let appBundleID: String?
    /// How many times this exact content has been copied.
    let copyCount: Int
    /// Payload for non-text kinds (RTF data, PNG data, archived file paths).
    /// `nil` in list snapshots, which skip payloads; see `HistoryStore.payload(id:)`.
    let data: Data?
    /// Text to paste when it differs from `preview` (e.g. a snippet whose row
    /// shows a title but pastes its content). Falls back to `preview`.
    let pasteText: String?

    /// The text placed on the pasteboard for text-like kinds.
    var textToPaste: String { pasteText ?? preview }

    init(
        id: UUID = UUID(),
        kind: ClipKind = .text,
        preview: String,
        createdAt: Date = Date(),
        isPinned: Bool = false,
        appBundleID: String? = nil,
        copyCount: Int = 1,
        data: Data? = nil,
        pasteText: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.preview = preview
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.appBundleID = appBundleID
        self.copyCount = copyCount
        self.data = data
        self.pasteText = pasteText
    }

    /// Kinds whose paste/preview needs the binary payload, not just `preview`.
    var needsPayload: Bool { kind == .rtf || kind == .image || kind == .file }

    /// This item with its payload attached (copies every other field).
    func with(data: Data?) -> ClipItemDO {
        ClipItemDO(
            id: id, kind: kind, preview: preview, createdAt: createdAt, isPinned: isPinned,
            appBundleID: appBundleID, copyCount: copyCount, data: data, pasteText: pasteText
        )
    }

    /// `preview` flattened to one short line for the list row. Reads at most a
    /// bounded prefix, so rendering a row never walks (or lays out) a
    /// multi-kilobyte clip. Computed on demand: only visible rows need it, and
    /// precomputing it for a 100k-clip history dominated load time.
    var rowText: String { Self.singleLine(preview) }

    private static func singleLine(_ text: String, limit: Int = 300) -> String {
        var line = ""
        line.reserveCapacity(min(text.utf8.count, limit))
        var count = 0
        for character in text {
            if count == limit { break }
            if character.isNewline || character == "\t" {
                if !line.isEmpty, line.last != " " { line.append(" ") }
            } else if character != " " || !line.isEmpty {
                line.append(character)
            }
            count += 1
        }
        while line.last == " " { line.removeLast() }
        return line
    }
}
