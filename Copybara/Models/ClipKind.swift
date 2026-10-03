import Foundation

/// The kind of content stored for a clip.
///
/// M0 records only `.text`; the remaining cases are placeholders for v0.2
/// (images, rich text, and file references).
enum ClipKind: String, Codable, CaseIterable {
    case text
    case rtf
    case image
    case file
    /// A user-authored snippet (not captured from the pasteboard).
    case snippet

    var title: String {
        switch self {
        case .text: return L10n.string("Text")
        case .rtf: return L10n.string("Rich Text")
        case .image: return L10n.string("Image")
        case .file: return L10n.string("File")
        case .snippet: return L10n.string("Snippet")
        }
    }
}
