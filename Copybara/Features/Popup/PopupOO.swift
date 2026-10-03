// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import Combine
import Foundation

/// Observable Object for the search popup: holds the query, filtered results, and
/// the current selection.
///
/// Built to stay responsive with a very large history (100k clips):
/// - the first page of history loads synchronously so the popup opens filled,
///   the rest loads on a background thread;
/// - large searches run off the main thread, newest query wins, and typing
///   forward narrows the previous matches instead of rescanning everything;
/// - delete and pin edit the loaded list in place rather than reloading;
/// - the view renders a growing window (`visibleResults`) instead of every match.
@MainActor
final class PopupOO: ObservableObject {
    @Published var query: String = "" {
        didSet { if query != oldValue { refilter() } }
    }
    @Published var scope: KindScope = .all {
        didSet { if scope != oldValue { refilter() } }
    }
    @Published private(set) var results: [ClipItemDO] = []
    @Published var selectedIndex: Int = 0 {
        didSet { growWindowIfNeeded(for: selectedIndex) }
    }
    /// Whether the ⌘K actions menu is open.
    @Published var showActions: Bool = false
    /// How many results the list renders; grows as the user scrolls or moves
    /// the selection toward the end.
    @Published private(set) var displayLimit = PopupOO.pageSize

    /// Rows rendered per page of the list window, and history rows fetched
    /// synchronously when the popup opens.
    static let pageSize = 200
    /// Above this many clips, searching moves off the main thread.
    static let backgroundSearchThreshold = 5_000

    private let store: HistoryStore
    private let settings: AppSettings
    private let snippets: SnippetStore
    private var snippetItems: [ClipItemDO] = []
    private var historyItems: [ClipItemDO] = []
    private var allItems: [ClipItemDO] { snippetItems + historyItems }

    /// The last completed search, kept so a longer query can narrow it.
    private var lastSearch: (query: String, scope: KindScope, mode: SearchMode, matches: [ClipItemDO])?
    /// Bumped on every load/search; background work checks it before publishing.
    private var loadGeneration = 0
    private var searchGeneration = 0

    /// True for preview/screenshot instances so `onAppear` doesn't reload over
    /// the injected sample data.
    private(set) var isPreview = false

    init(store: HistoryStore, settings: AppSettings = .shared, snippets: SnippetStore = .shared) {
        self.store = store
        self.settings = settings
        self.snippets = snippets
    }

    /// The currently highlighted item, if any.
    var selectedItem: ClipItemDO? {
        guard results.indices.contains(selectedIndex) else { return nil }
        return results[selectedIndex]
    }

    /// The slice of `results` the list renders.
    var visibleResults: ArraySlice<ClipItemDO> {
        results.prefix(displayLimit)
    }

    /// Clears the query, reloads history, and resets the selection. Call when the
    /// popup is about to be shown.
    func reset() {
        query = ""
        scope = .all
        selectedIndex = 0
        showActions = false
        reload()
    }

    /// Cycles the content-type scope: All → Text → Images → Files → All.
    func cycleScope() {
        let all = KindScope.allCases
        let next = (all.firstIndex(of: scope).map { $0 + 1 } ?? 0) % all.count
        scope = all[next]
    }

    /// Reloads history from the store and re-applies the current filter. The
    /// first page is read synchronously; a larger history completes in the
    /// background and then re-filters.
    func reload() {
        loadGeneration += 1
        let generation = loadGeneration
        let mode = settings.sortMode
        // Snippets are always available, shown above the sorted history.
        snippetItems = snippets.asClipItems()
        historyItems = store.recentItems(limit: Self.pageSize, includePayloads: false, sort: mode)
        lastSearch = nil
        refilter()

        guard historyItems.count == Self.pageSize else { return } // that was all of it
        let store = self.store
        Task.detached(priority: .userInitiated) {
            let everything = store.recentItems(limit: 0, includePayloads: false, sort: mode)
            await MainActor.run { [weak self] in
                guard let self, generation == self.loadGeneration else { return }
                self.historyItems = everything
                self.lastSearch = nil
                self.refilter(keepSelection: true)
            }
        }
    }

    /// `item` with its binary payload loaded, for pasting or the preview card.
    /// List snapshots omit payloads to keep reloads cheap.
    func withPayload(_ item: ClipItemDO) -> ClipItemDO {
        guard item.needsPayload, item.data == nil else { return item }
        return item.with(data: store.payload(id: item.id))
    }

    /// A small thumbnail for an image clip, decoded off the main thread and cached.
    func thumbnail(for item: ClipItemDO, maxPixel: Int) async -> NSImage? {
        let cache = ThumbnailCache.shared
        if let hit = cache.cached(id: item.id, maxPixel: maxPixel) { return hit }
        let store = self.store
        return await Task.detached(priority: .userInitiated) {
            guard let data = item.data ?? store.payload(id: item.id) else { return nil }
            return cache.image(id: item.id, maxPixel: maxPixel, data: data)
        }.value
    }

    /// Called as rows appear; extends the rendered window near its end.
    func rowAppeared(at index: Int) {
        growWindowIfNeeded(for: index)
    }

    private func growWindowIfNeeded(for index: Int) {
        guard displayLimit < results.count, index >= displayLimit - 20 else { return }
        displayLimit = min(results.count, max(displayLimit, index + 1) + Self.pageSize)
    }

    /// Moves the selection by `delta`, clamped to the current results.
    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), results.count - 1)
    }

    /// Jumps the selection to the first item.
    func selectFirst() {
        guard !results.isEmpty else { return }
        selectedIndex = 0
    }

    /// Jumps the selection to the last rendered item; the window then grows by
    /// a page, so repeating it walks a huge list without building every row.
    func selectLast() {
        guard !results.isEmpty else { return }
        selectedIndex = min(results.count, displayLimit) - 1
    }

    /// The item at a 1-based position (for ⌘1–9 quick selection), if present.
    func item(atNumber number: Int) -> ClipItemDO? {
        let index = number - 1
        return results.indices.contains(index) ? results[index] : nil
    }

    /// Moves the selection to `item` (e.g. before running a row's context-menu
    /// action), if it is among the current results.
    func select(_ item: ClipItemDO) {
        if let index = results.firstIndex(where: { $0.id == item.id }) {
            selectedIndex = index
        }
    }

    /// Pins or unpins the selected item, re-sorting the loaded list in place.
    func togglePinSelected() {
        guard let item = selectedItem, item.kind != .snippet else { return }
        store.togglePin(id: item.id)
        guard let index = historyItems.firstIndex(where: { $0.id == item.id }) else { return }
        historyItems[index] = item.with(isPinned: !item.isPinned)
        historyItems = ClipSearch.sort(historyItems, by: settings.sortMode)
        lastSearch = nil
        refilter()
        select(historyItems[historyItems.firstIndex { $0.id == item.id }!])
    }

    /// Deletes the selected item, keeping the selection near its old position.
    func deleteSelected() {
        guard let item = selectedItem else { return }
        delete(item)
    }

    /// Deletes one item: a history clip, or a snippet (which lives in its own
    /// store). Removes it from the loaded list instead of reloading everything.
    func delete(_ item: ClipItemDO) {
        if item.kind == .snippet {
            snippets.delete(id: item.id)
            snippetItems.removeAll { $0.id == item.id }
        } else {
            store.delete(id: item.id)
            if let index = historyItems.firstIndex(where: { $0.id == item.id }) {
                historyItems.remove(at: index)
            }
        }
        if let index = results.firstIndex(where: { $0.id == item.id }) {
            results.remove(at: index)
        }
        lastSearch?.matches.removeAll { $0.id == item.id }
        selectedIndex = results.isEmpty ? 0 : min(selectedIndex, results.count - 1)
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
        oo.historyItems = items
        oo.results = items
        return oo
    }
#endif

    /// Re-runs the search. Small histories filter synchronously; large ones on
    /// a background thread, where a newer query supersedes an older one.
    private func refilter(keepSelection: Bool = false) {
        searchGeneration += 1
        let generation = searchGeneration
        let query = self.query, scope = self.scope, mode = settings.searchMode

        // Typing forward only removes matches, so search the previous matches.
        var base = allItems
        if let last = lastSearch, last.scope == scope, last.mode == mode,
           ClipSearch.narrows(query, from: last.query, mode: mode) {
            base = last.matches
        }

        guard base.count > Self.backgroundSearchThreshold else {
            apply(ClipSearch.search(base, query: query, mode: mode, scope: scope),
                  query: query, scope: scope, mode: mode, keepSelection: keepSelection)
            return
        }
        Task.detached(priority: .userInitiated) {
            let result = ClipSearch.search(base, query: query, mode: mode, scope: scope)
            await MainActor.run { [weak self] in
                guard let self, generation == self.searchGeneration else { return }
                self.apply(result, query: query, scope: scope, mode: mode, keepSelection: keepSelection)
            }
        }
    }

    private func apply(_ result: ClipSearch.Result, query: String, scope: KindScope, mode: SearchMode, keepSelection: Bool) {
        let selectedID = keepSelection ? selectedItem?.id : nil
        lastSearch = (query, scope, mode, result.matches)
        results = result.ranked
        displayLimit = Self.pageSize
        if let selectedID, let index = results.firstIndex(where: { $0.id == selectedID }) {
            selectedIndex = index
        } else {
            selectedIndex = results.isEmpty ? 0 : min(keepSelection ? selectedIndex : 0, results.count - 1)
        }
    }
}
