import Foundation

/// A content-type scope for the popup's results filter.
enum KindScope: String, CaseIterable, Identifiable {
    case all
    case text
    case image
    case file

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.string("All")
        case .text: return L10n.string("Text")
        case .image: return L10n.string("Images")
        case .file: return L10n.string("Files")
        }
    }

    func matches(_ kind: ClipKind) -> Bool {
        switch self {
        case .all: return true
        case .text: return kind == .text || kind == .rtf || kind == .snippet
        case .image: return kind == .image
        case .file: return kind == .file
        }
    }
}

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

    /// Whether results for `query` are always a subset of those for `previous`,
    /// so a search can narrow the previous results instead of rescanning all
    /// clips. True while typing forward in fuzzy/exact mode (not regex).
    static func narrows(_ query: String, from previous: String, mode: SearchMode) -> Bool {
        mode != .regex && !previous.isEmpty && query.count > previous.count && query.hasPrefix(previous)
    }

    /// Filters items by `query` using the chosen match mode. An empty query
    /// returns the input unchanged; fuzzy mode re-orders by relevance; an invalid
    /// regex returns no results.
    static func filter(_ items: [ClipItemDO], query: String, mode: SearchMode, scope: KindScope = .all) -> [ClipItemDO] {
        search(items, query: query, mode: mode, scope: scope).ranked
    }

    /// The outcome of a search: `matches` keeps the input order (the base for
    /// narrowing the next, longer query); `ranked` is what the popup shows.
    struct Result {
        var matches: [ClipItemDO]
        var ranked: [ClipItemDO]
    }

    static func search(_ items: [ClipItemDO], query: String, mode: SearchMode, scope: KindScope = .all) -> Result {
        let items = scope == .all ? items : items.filter { scope.matches($0.kind) }
        guard !query.isEmpty else { return Result(matches: items, ranked: items) }

        switch mode {
        case .fuzzy:
            let pattern = FuzzyMatcher.Pattern(query)
            var matches: [ClipItemDO] = []
            var scores: [Int] = []
            for item in items {
                guard let score = pattern.score(in: item.preview) else { continue }
                matches.append(item)
                scores.append(score)
            }
            // Stable, so equal scores keep the history order.
            let order = matches.indices.sorted { scores[$0] != scores[$1] ? scores[$0] > scores[$1] : $0 < $1 }
            return Result(matches: matches, ranked: order.map { matches[$0] })

        case .exact:
            let pattern = FuzzyMatcher.Pattern(query)
            let matches = items.filter { pattern.isContained(in: $0.preview) }
            return Result(matches: matches, ranked: matches)

        case .regex:
            guard let regex = try? NSRegularExpression(pattern: query, options: [.caseInsensitive]) else {
                return Result(matches: [], ranked: [])
            }
            let matches = items.filter { item in
                let range = NSRange(item.preview.startIndex..., in: item.preview)
                return regex.firstMatch(in: item.preview, options: [], range: range) != nil
            }
            return Result(matches: matches, ranked: matches)
        }
    }
}
