import SwiftUI

/// The search popup: a search field over a list of clip results.
///
/// M0 renders the UI and live fuzzy filtering. TODO(M1): keyboard navigation
/// (↑/↓), paste-on-Return, and dismissal on Esc, hosted inside `PopupWindow`.
struct PopupView: View {
    @ObservedObject var oo: PopupOO

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search clips…", text: $oo.query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(10)

            Divider()

            if oo.results.isEmpty {
                Spacer()
                Text(oo.query.isEmpty ? "No clips yet" : "No matches")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(oo.results) { item in
                    ClipRowView(item: item)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 420, height: 480)
        .onAppear { oo.reload() }
    }
}
