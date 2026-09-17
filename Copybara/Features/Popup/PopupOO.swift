import Combine
import Foundation

/// Observable Object for the search popup: holds the query, filtered results, and
/// the current selection.
@MainActor
final class PopupOO: ObservableObject {
    @Published var query: String = "" {
        didSet { refilter() }
    }
    @Published private(set) var results: [ClipItemDO] = []
    @Published var selectedIndex: Int = 0

    private let store: HistoryStore
    private var allItems: [ClipItemDO] = []

    init(store: HistoryStore) {
        self.store = store
    }

    /// The currently highlighted item, if any.
    var selectedItem: ClipItemDO? {
        guard results.indices.contains(selectedIndex) else { return nil }
        return results[selectedIndex]
    }

    /// Clears the query, reloads history, and resets the selection. Call when the
    /// popup is about to be shown.
    func reset() {
        query = ""
        selectedIndex = 0
        reload()
    }

    /// Reloads history from the store and re-applies the current filter.
    func reload() {
        allItems = store.recentItems()
        refilter()
    }

    /// Moves the selection by `delta`, clamped to the current results.
    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), results.count - 1)
    }

    private func refilter() {
        if query.isEmpty {
            results = allItems
        } else {
            results = allItems
                .compactMap { item -> (ClipItemDO, Int)? in
                    guard let score = FuzzyMatcher.score(query, in: item.preview) else { return nil }
                    return (item, score)
                }
                .sorted { $0.1 > $1.1 }
                .map(\.0)
        }
        selectedIndex = results.isEmpty ? 0 : min(selectedIndex, results.count - 1)
    }
}
