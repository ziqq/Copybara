import Foundation

/// Pure filtering and sorting of clip history for the popup.
enum ClipSearch {
    /// Sorts items with pinned first, then by the chosen mode.
    static func sort(_ items: [ClipItemDO], by mode: SortMode) -> [ClipItemDO] {
        items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            switch mode {
            case .lastCopied:
                return lhs.createdAt > rhs.createdAt
            case .firstCopied:
                return lhs.createdAt < rhs.createdAt
            case .numberOfCopies:
                if lhs.copyCount != rhs.copyCount { return lhs.copyCount > rhs.copyCount }
                return lhs.createdAt > rhs.createdAt
            }
        }
    }

    /// Filters items by `query` using the chosen match mode. An empty query
    /// returns the input unchanged; fuzzy mode re-orders by relevance; an invalid
    /// regex returns no results.
    static func filter(_ items: [ClipItemDO], query: String, mode: SearchMode) -> [ClipItemDO] {
        guard !query.isEmpty else { return items }

        switch mode {
        case .fuzzy:
            return items
                .compactMap { item -> (ClipItemDO, Int)? in
                    guard let score = FuzzyMatcher.score(query, in: item.preview) else { return nil }
                    return (item, score)
                }
                .sorted { $0.1 > $1.1 }
                .map(\.0)

        case .exact:
            return items.filter { $0.preview.range(of: query, options: .caseInsensitive) != nil }

        case .regex:
            guard let regex = try? NSRegularExpression(pattern: query, options: [.caseInsensitive]) else {
                return []
            }
            return items.filter { item in
                let range = NSRange(item.preview.startIndex..., in: item.preview)
                return regex.firstMatch(in: item.preview, options: [], range: range) != nil
            }
        }
    }
}
