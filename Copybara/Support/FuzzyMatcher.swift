import Foundation

/// A small, dependency-free fuzzy matcher used to filter clip history as the
/// user types in the popup search field.
///
/// The algorithm is a case-insensitive subsequence match: every character of the
/// query must appear in `candidate` in order. Consecutive matches are rewarded so
/// that tighter matches rank above scattered ones.
enum FuzzyMatcher {
    /// Returns `true` when `query` fuzzy-matches `candidate`.
    static func matches(_ query: String, in candidate: String) -> Bool {
        score(query, in: candidate) != nil
    }

    /// Returns a score (higher is better) when `query` fuzzy-matches `candidate`,
    /// or `nil` when there is no match. An empty query matches everything with a
    /// neutral score of `0`.
    static func score(_ query: String, in candidate: String) -> Int? {
        if query.isEmpty { return 0 }

        let needle = Array(query.lowercased())
        let haystack = Array(candidate.lowercased())

        var needleIndex = 0
        var total = 0
        var previousMatch = -2

        for (position, character) in haystack.enumerated() {
            guard needleIndex < needle.count, character == needle[needleIndex] else { continue }
            total += (position == previousMatch + 1) ? 5 : 1
            previousMatch = position
            needleIndex += 1
        }

        return needleIndex == needle.count ? total : nil
    }
}
