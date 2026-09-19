import Foundation

/// Expands placeholders inside a snippet at paste time.
///
/// Supported: `${date}`, `${time}`, `${datetime}`, `${clipboard}` (the current
/// clipboard text), and `${uuid}`.
enum SnippetExpander {
    static func expand(_ text: String, now: Date = Date(), clipboard: String = "") -> String {
        guard text.contains("${") else { return text }

        var result = text
        result = result.replacingOccurrences(of: "${date}", with: formatted(now, date: .medium, time: .none))
        result = result.replacingOccurrences(of: "${time}", with: formatted(now, date: .none, time: .short))
        result = result.replacingOccurrences(of: "${datetime}", with: formatted(now, date: .medium, time: .short))
        result = result.replacingOccurrences(of: "${clipboard}", with: clipboard)
        while result.contains("${uuid}") {
            result = result.replacingOccurrences(of: "${uuid}", with: UUID().uuidString, range: result.range(of: "${uuid}"))
        }
        return result
    }

    private static func formatted(_ date: Date, date dateStyle: DateFormatter.Style, time timeStyle: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }
}
