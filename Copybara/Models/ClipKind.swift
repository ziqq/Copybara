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
}
