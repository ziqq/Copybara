import Foundation

/// A small, dependency-free fuzzy matcher used to filter clip history as the
/// user types in the popup search field.
///
/// The algorithm is a case-insensitive subsequence match: every character of the
/// query must appear in `candidate` in order. Consecutive matches are rewarded so
/// that tighter matches rank above scattered ones.
///
/// It runs against every clip on each keystroke, so the hot path compares UTF-16
/// code units against the query's lower- and upper-case forms instead of
/// lower-casing and copying each candidate, and stops as soon as the query is
/// fully matched.
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
        return Pattern(query).score(in: candidate)
    }

    /// A query prepared once and matched against many candidates.
    struct Pattern {
        private let lower: [UInt16]
        private let upper: [UInt16]
        /// Set when a query character has no single-unit case mapping (e.g. "ß");
        /// such queries use the slower Character-based path.
        private let fallback: String?
        /// KMP failure table over the case-folded query, for `isContained`.
        private let failure: [Int]

        init(_ query: String) {
            var lower: [UInt16] = []
            var upper: [UInt16] = []
            var simple = true
            for character in query {
                let lo = Array(String(character).lowercased().utf16)
                let up = Array(String(character).uppercased().utf16)
                guard lo.count == 1, up.count == 1 else { simple = false; break }
                lower.append(lo[0])
                upper.append(up[0])
            }
            self.lower = simple ? lower : []
            self.upper = simple ? upper : []
            self.fallback = simple ? nil : query
            self.failure = simple ? Self.failureTable(lower) : []
        }

        private static func failureTable(_ pattern: [UInt16]) -> [Int] {
            var table = [Int](repeating: 0, count: pattern.count)
            var length = 0
            for i in pattern.indices.dropFirst() {
                while length > 0, pattern[i] != pattern[length] { length = table[length - 1] }
                if pattern[i] == pattern[length] { length += 1 }
                table[i] = length
            }
            return table
        }

        func score(in candidate: String) -> Int? {
            if let fallback { return Self.slowScore(fallback, in: candidate) }
            let count = lower.count
            guard count > 0 else { return 0 }

            var matched = 0
            var total = 0
            var previousMatch = -2
            var position = 0
            for unit in candidate.utf16 {
                if unit == lower[matched] || unit == upper[matched] {
                    total += (position == previousMatch + 1) ? 5 : 1
                    previousMatch = position
                    matched += 1
                    if matched == count { return total }
                }
                position += 1
            }
            return nil
        }

        /// Case-insensitive substring test (the "Exact" search mode) on the same
        /// fast path. Knuth–Morris–Pratt, so the candidate is read in a single
        /// forward pass: random access into bridged Core Data strings is slow.
        func isContained(in candidate: String) -> Bool {
            if let fallback { return candidate.range(of: fallback, options: [.caseInsensitive, .literal]) != nil }
            let count = lower.count
            guard count > 0 else { return true }
            var matched = 0
            for unit in candidate.utf16 {
                while matched > 0, unit != lower[matched], unit != upper[matched] {
                    matched = failure[matched - 1]
                }
                if unit == lower[matched] || unit == upper[matched] {
                    matched += 1
                    if matched == count { return true }
                }
            }
            return false
        }

        private static func slowScore(_ query: String, in candidate: String) -> Int? {
            let needle = Array(query.lowercased())
            var needleIndex = 0
            var total = 0
            var previousMatch = -2
            for (position, character) in candidate.lowercased().enumerated() {
                guard character == needle[needleIndex] else { continue }
                total += (position == previousMatch + 1) ? 5 : 1
                previousMatch = position
                needleIndex += 1
                if needleIndex == needle.count { return total }
            }
            return nil
        }
    }
}
