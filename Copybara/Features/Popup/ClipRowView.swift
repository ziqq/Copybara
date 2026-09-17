import SwiftUI

/// A single clip row in the popup list.
struct ClipRowView: View {
    let item: ClipItemDO

    var body: some View {
        HStack(spacing: 8) {
            Text(item.preview)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
