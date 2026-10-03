import ApplicationServices
import SwiftUI

/// An action available for the selected clip, surfaced in the ⌘K actions menu.
enum PopupAction {
    case paste
    case pastePlain
    case pasteTransformed(TextTransform)
    case copy
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
    @State private var axTrusted: Bool = Paster().hasAccessibilityPermission

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
            // Defer so the window is key before we request focus, otherwise the
            // search field needs an extra click to accept typing.
            if autoFocus {
                DispatchQueue.main.async { searchFocused = true }
            }
        }
        .onChange(of: previewItem) { onHoverPreview($0) }
        .onReceive(axTimer) { _ in
            let trusted = Paster().hasAccessibilityPermission
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

            if oo.scope != .all {
                Button { oo.scope = .all } label: {
                    HStack(spacing: 4) {
                        Text(oo.scope.title).font(.system(size: 11, weight: .medium))
                        Image(systemName: "xmark.circle.fill").font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Content type filter (⌘L to cycle)")
            }
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
                Text(L10n.string(oo.query.isEmpty ? "No clips yet" : "No matches"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(height: PopupMetrics.listHeight(for: 0))
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(oo.visibleResults.enumerated()), id: \.element.id) { index, item in
                            ClipRowView(
                                item: item,
                                isSelected: index == oo.selectedIndex,
                                query: oo.query,
                                index: index,
                                onDelete: { oo.delete(item) },
                                loadThumbnail: { [oo] in
                                    await oo.thumbnail(for: $0, maxPixel: ClipRowView.thumbnailPixels)
                                }
                            )
                                .onTapGesture { onCommit(item) }
                                .onAppear { oo.rowAppeared(at: index) }
                                .contextMenu { rowMenu(for: item) }
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
        raycastFooter
            .padding(.horizontal, 12)
        .frame(height: PopupMetrics.footerHeight)
    }

    private var raycastFooter: some View {
        HStack(spacing: 8) {
            // The warning takes the icon's place instead of the whole footer, so
            // Paste and the ⌘K actions (Delete, Pin…) stay reachable.
            if axTrusted {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Button { OnboardingController.openAccessibilitySettings() } label: {
                    accessibilityWarning
                }
                .buttonStyle(.plain)
                .help("Open System Settings › Privacy & Security › Accessibility")
            }

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
            Text(L10n.string(title)).font(.system(size: 11))
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

    private var isTextSelected: Bool {
        guard let kind = oo.selectedItem?.kind else { return false }
        return kind == .text || kind == .rtf || kind == .snippet
    }

    private var actionsMenu: some View {
        VStack(alignment: .leading, spacing: 2) {
            actionRow("Paste", keys: "↩", action: .paste)
            actionRow("Paste as Plain Text", keys: "⌥⇧↩", action: .pastePlain)
            actionRow("Copy", keys: "⌘C", action: .copy)
            if isTextSelected {
                ForEach(TextTransform.allCases) { transform in
                    actionRow(transform.title, keys: nil, action: .pasteTransformed(transform))
                }
            }
            Divider()
            if oo.selectedItem?.kind != .snippet {
                actionRow(oo.selectedItem?.isPinned == true ? "Unpin" : "Pin", keys: "⌥P", action: .pin)
            }
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
                Text(L10n.string(title)).font(.system(size: 12))
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
            Text("Enable Accessibility to paste automatically")
                .font(.system(size: 11))
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Row context menu

    /// Right-click menu for a row; acts on that row, not the keyboard selection.
    @ViewBuilder
    private func rowMenu(for item: ClipItemDO) -> some View {
        Button("Paste") { onCommit(item) }
        Button("Paste as Plain Text") { run(.pastePlain, on: item) }
        Button("Copy") { run(.copy, on: item) }
        if item.kind != .snippet {
            Divider()
            Button(L10n.string(item.isPinned ? "Unpin" : "Pin")) { run(.pin, on: item) }
        }
        Divider()
        Button("Delete") { oo.delete(item) }
    }

    private func run(_ action: PopupAction, on item: ClipItemDO) {
        oo.select(item)
        onAction(action)
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
