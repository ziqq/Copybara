import Foundation

/// Short relative timestamps for clip rows (e.g. "2m", "1h", "3d").
enum RelativeTime {
    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static func short(from date: Date) -> String {
        formatter.localizedString(for: date, relativeTo: Date())
    }

    private static let absoluteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func absolute(from date: Date) -> String {
        absoluteFormatter.string(from: date)
    }
}
