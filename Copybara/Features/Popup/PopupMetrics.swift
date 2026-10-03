// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import CoreGraphics

/// Shared layout constants for the popup, used by both the SwiftUI view (to lay
/// itself out) and `PopupController` (to size the window to match).
enum PopupMetrics {
    static let width: CGFloat = 560
    static let cornerRadius: CGFloat = 12
    static let searchHeight: CGFloat = 52
    static let rowHeight: CGFloat = 44
    static let footerHeight: CGFloat = 32
    static let dividerHeight: CGFloat = 1
    static let maxVisibleRows = 8

    /// Height of the results area for a given item count (min one row so the
    /// empty state is visible), capped at `maxVisibleRows`.
    static func listHeight(for count: Int) -> CGFloat {
        CGFloat(min(max(count, 1), maxVisibleRows)) * rowHeight
    }

    /// Total popup height for a given item count.
    static func totalHeight(for count: Int) -> CGFloat {
        searchHeight + dividerHeight + listHeight(for: count) + dividerHeight + footerHeight
    }
}
