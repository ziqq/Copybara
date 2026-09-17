import SwiftUI

/// The search popup: a focused search field over a scrollable list of clip
/// results with a highlighted selection.
///
/// Keyboard navigation (↑/↓/Return/Esc) is handled by `PopupController` via a
/// local event monitor, which updates `oo.selectedIndex` and calls `onCommit`.
/// This view reflects that selection and auto-scrolls to keep it visible.
struct PopupView: View {
    @ObservedObject var oo: PopupOO
    /// Invoked when the user commits an item (Return or click).
    var onCommit: (ClipItemDO) -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search clips…", text: $oo.query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(10)
                .focused($searchFocused)

            Divider()

            if oo.results.isEmpty {
                Spacer()
                Text(oo.query.isEmpty ? "No clips yet" : "No matches")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                resultsList
            }
        }
        .frame(width: 420, height: 480)
        .background(.regularMaterial)
        .onAppear {
            oo.reload()
            searchFocused = true
        }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(oo.results.enumerated()), id: \.element.id) { index, item in
                        ClipRowView(item: item)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(rowBackground(isSelected: index == oo.selectedIndex))
                            .contentShape(Rectangle())
                            .onTapGesture { onCommit(item) }
                            .id(item.id)
                    }
                }
                .padding(6)
            }
            .onChange(of: oo.selectedIndex) { _ in
                guard let item = oo.selectedItem else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(item.id, anchor: .center)
                }
            }
        }
    }

    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
    }
}
