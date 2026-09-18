import SwiftUI

/// A floating preview of a clip shown while hovering a row: full content (text,
/// full-size image, or file paths) plus source app, time, and copy count.
struct PreviewCard: View {
    let item: ClipItemDO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider()
            content
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let icon = AppIconProvider.icon(forBundleID: item.appBundleID) {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            }
            Text(AppIconProvider.name(forBundleID: item.appBundleID) ?? item.kind.rawValue.capitalized)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            if item.copyCount > 1 {
                Text("×\(item.copyCount)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Text(RelativeTime.short(from: item.createdAt))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .image:
            if let data = item.data, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Text(item.preview).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        case .file:
            let paths = item.data.flatMap(FilePayload.paths(from:)) ?? [item.preview]
            VStack(alignment: .leading, spacing: 4) {
                ForEach(paths, id: \.self) { path in
                    HStack(spacing: 6) {
                        Image(systemName: "doc").font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(path).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                    }
                }
            }
        case .text, .rtf:
            Text(item.preview)
                .font(.system(size: 12))
                .lineLimit(12)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}
