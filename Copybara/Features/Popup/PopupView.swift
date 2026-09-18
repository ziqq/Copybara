import ApplicationServices
import SwiftUI

/// An action available for the selected clip, surfaced in the ⌘K actions menu.
enum PopupAction {
    case paste
    case pastePlain
    case pin
    case delete
    case clearAll
}

/// The search popup: a focused search field over a scrollable list of clip
/// results with a highlighted selection and a Raycast-style action footer.
///
/// Keyboard navigation (↑/↓/Return/Esc) is handled by `PopupController` via a
/// local event monitor, which updates `oo.selectedIndex` and calls `onCommit`.
/// The window is sized to match `PopupMetrics.totalHeight(for:)` so few results
/// produce a compact popup rather than a tall empty box.
struct PopupView: View {
    @ObservedObject var oo: PopupOO
    /// Auto-focus the search field on appear (disabled for screenshots).
    var autoFocus: Bool = true
    /// Draw the popup's own Liquid Glass surface (macOS 26). When false, the
    /// hosting window supplies a vibrant material instead.
    var useGlass: Bool = false
    /// Invoked when the user commits an item (Return or click).
    var onCommit: (ClipItemDO) -> Void
    /// Invoked with the hovered item (or nil) so the controller can show a
    /// side preview panel.
    var onHoverPreview: (ClipItemDO?) -> Void = { _ in }
    /// Invoked when an action is chosen (footer, ⌘K menu, or click).
    var onAction: (PopupAction) -> Void = { _ in }

    @FocusState private var searchFocused: Bool
    @State private var previewItem: ClipItemDO?
    @State private var axTrusted: Bool = AXIsProcessTrusted()

    private let axTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

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
        .modifier(GlassSurface(enabled: useGlass))
        .onAppear {
            if !oo.isPreview { oo.reload() }
            // Defer so the window is key before we request focus, otherwise the
            // search field needs an extra click to accept typing.
            if autoFocus {
                DispatchQueue.main.async { searchFocused = true }
            }
        }
        .onChange(of: previewItem) { onHoverPreview($0) }
        .onReceive(axTimer) { _ in
            let trusted = AXIsProcessTrusted()
            if trusted != axTrusted { axTrusted = trusted }
        }
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
                            ClipRowView(item: item, isSelected: index == oo.selectedIndex, query: oo.query, index: index)
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
                    // Minimal scroll to keep the selection visible — no recentering
                    // and no animation, so stepping through the list stays stable
                    // (Raycast-style) instead of jittering.
                    guard let item = oo.selectedItem else { return }
                    proxy.scrollTo(item.id)
                }
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        Group {
            if axTrusted {
                raycastFooter
            } else {
                accessibilityWarning
                    .contentShape(Rectangle())
                    .onTapGesture { OnboardingController.openAccessibilitySettings() }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: PopupMetrics.footerHeight)
    }

    private var raycastFooter: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 16, height: 16)

            Spacer()

            Button {
                if let item = oo.selectedItem { onCommit(item) }
            } label: {
                actionLabel("Paste", keys: "↩")
            }
            .buttonStyle(.plain)
            .disabled(oo.selectedItem == nil)

            Divider().frame(height: 14)

            Button { oo.showActions.toggle() } label: {
                actionLabel("Actions", keys: "⌘K")
            }
            .buttonStyle(.plain)
            .popover(isPresented: $oo.showActions, arrowEdge: .bottom) { actionsMenu }
        }
    }

    private func actionLabel(_ title: String, keys: String) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 11))
            keycap(keys)
        }
        .foregroundStyle(.secondary)
    }

    private func keycap(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.primary.opacity(0.08)))
            .foregroundStyle(.secondary)
    }

    // MARK: - Actions menu (⌘K)

    private var actionsMenu: some View {
        VStack(alignment: .leading, spacing: 2) {
            actionRow("Paste", keys: "↩", action: .paste)
            actionRow("Paste as Plain Text", keys: "⌥⇧↩", action: .pastePlain)
            Divider()
            actionRow(oo.selectedItem?.isPinned == true ? "Unpin" : "Pin", keys: "⌥P", action: .pin)
            actionRow("Delete", keys: "⌥⌫", action: .delete)
            Divider()
            actionRow("Clear History", keys: nil, action: .clearAll)
        }
        .padding(6)
        .frame(width: 240)
    }

    private func actionRow(_ title: String, keys: String?, action: PopupAction) -> some View {
        Button {
            oo.showActions = false
            onAction(action)
        } label: {
            HStack {
                Text(title).font(.system(size: 12))
                Spacer()
                if let keys { keycap(keys) }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
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
