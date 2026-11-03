// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

#if DEBUG
import AppKit
import SwiftUI

/// Shows the production popup with fixed sample data and a neutral backdrop.
/// Launch with COPYBARA_SCREENSHOT=1 and capture this window. A live window is
/// needed for Liquid Glass; ImageRenderer cannot capture the glass compositor.
@MainActor
enum ScreenshotRenderer {
    private static var window: NSWindow?

    static func showPopup() {
        let ru = Locale.preferredLanguages.first?.hasPrefix("ru") == true
        let shot = ProcessInfo.processInfo.environment["COPYBARA_SHOT"] ?? "history"
        let all = sampleItems()
        let items = shot == "pins" ? all.filter { $0.isPinned } : all
        let oo = PopupOO.preview(items, hovered: shot == "history" ? items[2].id : nil)
        let title: String
        let subtitle: String
        switch shot {
        case "pins":
            title = ru ? "Важное — всегда рядом." : "Keep the useful things close."
            subtitle = ru ? "Закрепляйте записи и добавляйте комментарии." : "Pin favorite clips and add a note for next time."
        case "settings":
            title = ru ? "Ваш буфер. Ваши правила." : "Your clipboard. Your rules."
            subtitle = ru ? "Настройте историю, поиск и внешний вид." : "Choose your history, search, and appearance settings."
        default:
            title = ru ? "Всё, что вы копировали." : "Everything you copied. Within reach."
            subtitle = ru ? "Текст, ссылки, изображения и файлы — в одном месте." : "Text, links, images, and files. One keyboard shortcut away."
        }
        let size = NSSize(width: 1440, height: 900)
        let scene = ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.10, blue: 0.14), Color(red: 0.20, green: 0.12, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 14) {
                Text("Copybara").font(.system(size: 22, weight: .semibold)).foregroundStyle(Color(red: 0.96, green: 0.65, blue: 0.39))
                Text(title).font(.system(size: 48, weight: .bold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 23)).foregroundStyle(.white.opacity(0.72))
                Spacer().frame(height: 18)
                if shot == "settings" {
                    SettingsView().clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    PopupView(oo: oo, autoFocus: false, useGlass: LiquidGlass.isSupported, onCommit: { _ in }, onAction: { _ in })
                }
            }
            .multilineTextAlignment(.center)
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, .dark)
        .accentColor(Color("AccentColor"))

        let panel = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                             styleMask: [.borderless],
                             backing: .buffered, defer: false)
        panel.title = "Copybara App Store Capture"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = NSHostingView(rootView: scene)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = panel
    }

    /// Fixed colors behind the popup make the real glass refraction visible.
    private static var backdrop: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.12, green: 0.15, blue: 0.20),
                                    Color(red: 0.19, green: 0.12, blue: 0.09)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 44) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.18, green: 0.40, blue: 0.52))
                    .frame(width: 310, height: 68)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.55, green: 0.26, blue: 0.10))
                    .frame(width: 440, height: 90)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.27, green: 0.23, blue: 0.44))
                    .frame(width: 250, height: 64)
            }
            .padding(.top, 40)
            .padding(.leading, 12)
        }
    }

    static func sampleItems() -> [ClipItemDO] {
        func ago(_ seconds: TimeInterval) -> Date { Date().addingTimeInterval(-seconds) }
        return [
            ClipItemDO(kind: .snippet, preview: Locale.preferredLanguages.first?.hasPrefix("ru") == true ? "Подпись письма" : "Email signature", createdAt: ago(30),
                       pasteText: "Best regards,\nAnton"),
            ClipItemDO(kind: .text, preview: "https://github.com/ziqq/Copybara",
                       createdAt: ago(75), appBundleID: "com.apple.Safari"),
            ClipItemDO(kind: .text, preview: "git commit -m \"feat(m2): search modes\"",
                       createdAt: ago(240), appBundleID: "com.apple.Terminal", note: Locale.preferredLanguages.first?.hasPrefix("ru") == true ? "Коммит релиза" : "Release commit"),
            ClipItemDO(kind: .text, preview: "#C2703D", createdAt: ago(3600),
                       isPinned: true, copyCount: 4, note: Locale.preferredLanguages.first?.hasPrefix("ru") == true ? "Цвет бренда" : "Brand accent"),
            ClipItemDO(kind: .image, preview: "Image 1200×800", createdAt: ago(900),
                       data: sampleImagePNG()),
            ClipItemDO(kind: .file, preview: "Copybara.dmg", createdAt: ago(7200)),
            ClipItemDO(kind: .text, preview: "The quick brown capybara jumps over the clipboard.",
                       createdAt: ago(180), copyCount: 2)
        ]
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
