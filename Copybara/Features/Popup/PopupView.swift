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
    /// Invoked when the user commits an item (Return or click).
    var onCommit: (ClipItemDO) -> Void

    @FocusState private var searchFocused: Bool

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
            oo.reload()
            searchFocused = true
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
                            ClipRowView(item: item, isSelected: index == oo.selectedIndex)
                                .onTapGesture { onCommit(item) }
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

    private var footer: some View {
        HStack(spacing: 14) {
            hint(key: "return", label: "Paste")
            hint(key: "arrow.up.arrow.down", label: "Navigate")
            hint(key: "escape", label: "Close")
            Spacer()
            Text("\(oo.results.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: PopupMetrics.footerHeight)
    }

    private func hint(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: key)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
    }
}
