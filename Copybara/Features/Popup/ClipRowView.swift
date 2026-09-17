import SwiftUI

/// A single clip row in the popup list.
struct ClipRowView: View {
    let item: ClipItemDO
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .frame(width: 18)

            Text(displayText)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isSelected ? Color.white : Color.primary)

            Spacer(minLength: 8)

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: PopupMetrics.rowHeight - 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private var iconName: String {
        switch item.kind {
        case .text: return "text.alignleft"
        case .rtf: return "doc.richtext"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    /// Collapse whitespace/newlines so multi-line clips render as one tidy line.
    private var displayText: String {
        item.preview
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
