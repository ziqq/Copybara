#if DEBUG
import AppKit
import SwiftUI

/// Renders the real `PopupView` with sample data to a PNG, for README imagery.
/// Triggered headlessly via the `COPYBARA_SCREENSHOT` environment variable so no
/// real clipboard data or desktop is captured.
enum ScreenshotRenderer {
    @MainActor
    static func renderPopup(to path: String) {
        guard #available(macOS 13.0, *) else {
            FileHandle.standardError.write(Data("Screenshot needs macOS 13+\n".utf8))
            return
        }

        let items = sampleItems()

        let scene = ZStack {
            LinearGradient(
                colors: [Color(red: 0.17, green: 0.15, blue: 0.14), Color(red: 0.09, green: 0.08, blue: 0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            ScreenshotPopup(items: items)
                .background(Color(red: 0.14, green: 0.13, blue: 0.13))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 28, y: 12)
                .padding(52)
        }
        .frame(width: PopupMetrics.width + 104,
               height: PopupMetrics.totalHeight(for: items.count) + 104)
        .environment(\.colorScheme, .dark)
        // Offscreen rendering doesn't pick up the asset accent, so set it directly.
        .accentColor(Color(red: 0.76, green: 0.447, blue: 0.235))

        let renderer = ImageRenderer(content: scene)
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("Failed to render screenshot\n".utf8))
            return
        }
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? png.write(to: URL(fileURLWithPath: path))
        FileHandle.standardError.write(Data("Wrote screenshot to \(path)\n".utf8))
    }

    static func sampleItems() -> [ClipItemDO] {
        func ago(_ seconds: TimeInterval) -> Date { Date().addingTimeInterval(-seconds) }
        return [
            ClipItemDO(kind: .snippet, preview: "Email signature", createdAt: ago(30),
                       pasteText: "Best regards,\nAnton"),
            ClipItemDO(kind: .text, preview: "https://github.com/ziqq/Copybara",
                       createdAt: ago(75), appBundleID: "com.apple.Safari"),
            ClipItemDO(kind: .text, preview: "git commit -m \"feat(m2): search modes\"",
                       createdAt: ago(240), appBundleID: "com.apple.Terminal"),
            ClipItemDO(kind: .text, preview: "#C2703D", createdAt: ago(3600),
                       isPinned: true, copyCount: 4),
            ClipItemDO(kind: .image, preview: "Image 1200×800", createdAt: ago(900),
                       data: sampleImagePNG()),
            ClipItemDO(kind: .file, preview: "Copybara.dmg", createdAt: ago(7200)),
            ClipItemDO(kind: .text, preview: "The quick brown capybara jumps over the clipboard.",
                       createdAt: ago(180), copyCount: 2)
        ]
    }

    /// A static composite mirroring the popup layout, built from the real
    /// `ClipRowView` (ImageRenderer can't render `ScrollView`/`TextField`).
    private struct ScreenshotPopup: View {
        let items: [ClipItemDO]

        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    Text("Search clips…")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: PopupMetrics.searchHeight)

                Divider()

                VStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ClipRowView(item: item, isSelected: index == 0, query: "", index: index)
                    }
                }
                .padding(6)
                .frame(height: PopupMetrics.listHeight(for: items.count))

                Divider()

                HStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 16, height: 16)
                    Spacer()
                    footerAction("Paste", "↩")
                    Divider().frame(height: 14)
                    footerAction("Actions", "⌘K")
                }
                .padding(.horizontal, 12)
                .frame(height: PopupMetrics.footerHeight)
            }
            .frame(width: PopupMetrics.width)
        }

        private func footerAction(_ title: String, _ keys: String) -> some View {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 11))
                Text(keys)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.primary.opacity(0.08)))
            }
            .foregroundStyle(.secondary)
        }
    }

    private static func sampleImagePNG() -> Data? {
        let size = 64
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let ctx = NSGraphicsContext.current!.cgContext
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [NSColor(srgbRed: 0.85, green: 0.55, blue: 0.3, alpha: 1).cgColor,
                     NSColor(srgbRed: 0.55, green: 0.3, blue: 0.5, alpha: 1).cgColor] as CFArray,
            locations: [0, 1]
        )!
        ctx.drawLinearGradient(gradient, start: .zero,
                               end: CGPoint(x: size, y: size), options: [])
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}
#endif
