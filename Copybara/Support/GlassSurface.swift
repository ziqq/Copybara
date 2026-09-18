import SwiftUI

/// Whether the macOS 26 Liquid Glass material should be used.
enum LiquidGlass {
    /// Enabled in settings and available on this OS.
    static var isEnabled: Bool {
        if #available(macOS 26.0, *) { return AppSettings.shared.useLiquidGlass }
        return false
    }

    /// The OS supports Liquid Glass (macOS 26+).
    static var isSupported: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }
}

/// Applies the Liquid Glass material in a rounded shape when enabled/available;
/// otherwise leaves the view unchanged so a host material can show through.
struct GlassSurface: ViewModifier {
    var enabled: Bool
    var cornerRadius: CGFloat = PopupMetrics.cornerRadius

    func body(content: Content) -> some View {
        if enabled, #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
        }
    }
}

/// A rounded surface that uses Liquid Glass when enabled, else a vibrant material.
struct GlassOrMaterial: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if LiquidGlass.isEnabled, #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
