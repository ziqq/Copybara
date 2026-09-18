import SwiftUI

/// A single clip row in the popup list: source-app icon, the (match-highlighted)
/// content, and trailing metadata (copy count, relative time, pin). Hovering
/// shows a tooltip preview with the full content and details.
struct ClipRowView: View {
    let item: ClipItemDO
    let isSelected: Bool
    let query: String

    var body: some View {
        HStack(spacing: 10) {
            iconView
                .frame(width: 18, height: 18)
                .clipped()

            highlightedText
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isSelected ? Color.white : Color.primary)

            Spacer(minLength: 8)

            trailing
        }
        .padding(.horizontal, 12)
        .frame(height: PopupMetrics.rowHeight - 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .help(tooltip)
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconView: some View {
        if item.kind == .image, let data = item.data, let thumbnail = NSImage(data: data) {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        } else if let appIcon = AppIconProvider.icon(forBundleID: item.appBundleID) {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: kindIconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
        }
    }

    private var kindIconName: String {
        switch item.kind {
        case .text: return "text.alignleft"
        case .rtf: return "doc.richtext"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    // MARK: - Text + highlight

    private var displayText: String {
        item.preview
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private var highlightedText: Text {
        let text = displayText
        guard !query.isEmpty,
              let range = text.range(of: query, options: .caseInsensitive) else {
            return Text(text)
        }
        let prefix = String(text[text.startIndex..<range.lowerBound])
        let match = String(text[range])
        let suffix = String(text[range.upperBound...])
        return Text(prefix)
            + Text(match).fontWeight(.bold).foregroundColor(isSelected ? .white : .accentColor)
            + Text(suffix)
    }

    // MARK: - Trailing metadata

    private var trailing: some View {
        HStack(spacing: 8) {
            if item.copyCount > 1 {
                Text("×\(item.copyCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(metaColor)
            }
            Text(RelativeTime.short(from: item.createdAt))
                .font(.system(size: 11))
                .foregroundStyle(metaColor)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
            }
        }
    }

    private var metaColor: Color {
        isSelected ? Color.white.opacity(0.8) : Color.secondary
    }

    // MARK: - Tooltip

    private var tooltip: String {
        var body = item.preview
        if item.kind == .file, let data = item.data, let paths = FilePayload.paths(from: data) {
            body = paths.joined(separator: "\n")
        }
        var lines = [body]
        var meta: [String] = []
        if let app = AppIconProvider.name(forBundleID: item.appBundleID) {
            meta.append("From \(app)")
        }
        meta.append(RelativeTime.absolute(from: item.createdAt))
        if item.copyCount > 1 { meta.append("copied \(item.copyCount)×") }
        lines.append("")
        lines.append(meta.joined(separator: " · "))
        return lines.joined(separator: "\n")
    }
}
