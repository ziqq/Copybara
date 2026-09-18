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
    private let settings: AppSettings
    private var allItems: [ClipItemDO] = []
    /// True for preview/screenshot instances so `onAppear` doesn't reload over
    /// the injected sample data.
    private(set) var isPreview = false

    init(store: HistoryStore, settings: AppSettings = .shared) {
        self.store = store
        self.settings = settings
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

    /// Reloads history from the store, sorts by the current sort mode, and
    /// re-applies the current filter.
    func reload() {
        allItems = ClipSearch.sort(store.recentItems(), by: settings.sortMode)
        refilter()
    }

    /// Moves the selection by `delta`, clamped to the current results.
    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), results.count - 1)
    }

    /// The item at a 1-based position (for ⌘1–9 quick selection), if present.
    func item(atNumber number: Int) -> ClipItemDO? {
        let index = number - 1
        return results.indices.contains(index) ? results[index] : nil
    }

    /// Pins or unpins the selected item and reloads.
    func togglePinSelected() {
        guard let item = selectedItem else { return }
        store.togglePin(id: item.id)
        reload()
    }

    /// Deletes the selected item, keeping the selection near its old position.
    func deleteSelected() {
        guard let item = selectedItem else { return }
        store.delete(id: item.id)
        reload()
    }

    /// Clears all non-pinned items and reloads.
    func clearUnpinned() {
        store.clearUnpinned()
        reload()
    }

    /// Clears everything, including pinned items, and reloads.
    func clearAll() {
        store.clearAll()
        reload()
    }

#if DEBUG
    /// Builds an OO with fixed results, for SwiftUI previews and screenshots.
    static func preview(_ items: [ClipItemDO]) -> PopupOO {
        let oo = PopupOO(store: HistoryStore(stack: CoreDataStack(inMemory: true)))
        oo.isPreview = true
        oo.allItems = items
        oo.results = items
        return oo
    }
#endif

    private func refilter() {
        results = ClipSearch.filter(allItems, query: query, mode: settings.searchMode)
        selectedIndex = results.isEmpty ? 0 : min(selectedIndex, results.count - 1)
    }
}
