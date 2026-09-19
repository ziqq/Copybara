import Foundation

/// A text transformation applied when pasting (from the ⌘K actions menu).
enum TextTransform: String, CaseIterable, Identifiable {
    case trimmed
    case lowercased
    case uppercased

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trimmed: return "Paste Trimmed"
        case .lowercased: return "Paste lowercased"
        case .uppercased: return "Paste UPPERCASED"
        }
    }

    func apply(_ text: String) -> String {
        switch self {
        case .trimmed: return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .lowercased: return text.lowercased()
        case .uppercased: return text.uppercased()
        }
    }
}
