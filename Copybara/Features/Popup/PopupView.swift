import ApplicationServices
import SwiftUI

/// The search popup: a focused search field over a scrollable list of clip
/// results with a highlighted selection and a keyboard-hint footer.
///
/// Keyboard navigation (↑/↓/Return/Esc) is handled by `PopupController` via a
/// local event monitor, which updates `oo.selectedIndex` and calls `onCommit`.
/// The window is sized to match `PopupMetrics.totalHeight(for:)` so few results
/// produce a compact popup rather than a tall empty box.
struct PopupView: View {
    @ObservedObject var oo: PopupOO
    /// Auto-focus the search field on appear (disabled for screenshots).
    var autoFocus: Bool = true
    /// Invoked when the user commits an item (Return or click).
    var onCommit: (ClipItemDO) -> Void
    /// Invoked with the hovered item (or nil) so the controller can show a
    /// side preview panel.
    var onHoverPreview: (ClipItemDO?) -> Void = { _ in }

    @FocusState private var searchFocused: Bool
    @State private var previewItem: ClipItemDO?

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            resultsArea
            Divider()
            footer
        }
        .frame(width: PopupMetrics.width,
               height: PopupMetrics.totalHeight(for: oo.results.count))
        .onAppear {
            if !oo.isPreview { oo.reload() }
            if autoFocus { searchFocused = true }
        }
        .onChange(of: previewItem) { onHoverPreview($0) }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            TextField("Search clips…", text: $oo.query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($searchFocused)
        }
        .padding(.horizontal, 14)
        .frame(height: PopupMetrics.searchHeight)
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsArea: some View {
        if oo.results.isEmpty {
            VStack {
                Spacer()
                Text(oo.query.isEmpty ? "No clips yet" : "No matches")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(height: PopupMetrics.listHeight(for: 0))
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(oo.results.enumerated()), id: \.element.id) { index, item in
                            ClipRowView(item: item, isSelected: index == oo.selectedIndex, query: oo.query)
                                .onTapGesture { onCommit(item) }
                                .onHover { hovering in
                                    previewItem = hovering ? item : (previewItem?.id == item.id ? nil : previewItem)
                                }
                                .id(item.id)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                }
                .frame(height: PopupMetrics.listHeight(for: oo.results.count))
                .onChange(of: oo.selectedIndex) { _ in
                    guard let item = oo.selectedItem else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(item.id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        if AXIsProcessTrusted() {
            hintsRow
                .padding(.horizontal, 12)
                .frame(height: PopupMetrics.footerHeight)
        } else {
            accessibilityWarning
                .padding(.horizontal, 12)
                .frame(height: PopupMetrics.footerHeight)
                .contentShape(Rectangle())
                .onTapGesture { OnboardingController.openAccessibilitySettings() }
        }
    }

    private var hintsRow: some View {
        HStack(spacing: 12) {
            hint("↩", "Paste")
            hint("↑↓", nil)
            hint("→", "Preview")
            hint("⌥P", "Pin")
            hint("⌥⌫", "Delete")
            hint("esc", "Close")
            Spacer()
            Text("\(oo.results.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var accessibilityWarning: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
            Text("Enable Accessibility so clicking pastes automatically")
                .font(.system(size: 11))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func hint(_ keys: String, _ label: String?) -> some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 11, weight: .medium, design: .rounded))
            if let label {
                Text(label)
                    .font(.system(size: 11))
            }
        }
        .foregroundStyle(.secondary)
    }
}

#if DEBUG
#Preview("Popup") {
    PopupView(oo: .preview(ScreenshotRenderer.sampleItems()), autoFocus: false, onCommit: { _ in })
        .background(Color(red: 0.14, green: 0.13, blue: 0.13))
        .environment(\.colorScheme, .dark)
        .padding(40)
}

#Preview("Clip preview card") {
    PreviewCard(item: ScreenshotRenderer.sampleItems()[3])
        .environment(\.colorScheme, .dark)
        .padding(40)
}
#endif
