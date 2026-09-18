import Foundation

extension Notification.Name {
    /// Posted when the icon-visibility preference changes, so the app can update
    /// its activation policy live. `userInfo["value"]` carries the raw value.
    static let copybaraIconVisibilityChanged = Notification.Name("copybaraIconVisibilityChanged")
}

/// Where Copybara displays its icon.
enum IconVisibility: String, CaseIterable, Identifiable {
    case menuBar
    case dock
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .menuBar: return "Menu bar"
        case .dock: return "Dock"
        case .both: return "Both"
        }
    }
}

/// Where the search popup appears when opened.
enum PopupPosition: String, CaseIterable, Identifiable {
    case menuBarIcon
    case cursor
    case center

    var id: String { rawValue }

    var title: String {
        switch self {
        case .menuBarIcon: return "Menu bar icon"
        case .cursor: return "Cursor"
        case .center: return "Screen center"
        }
    }
}

/// How the search field matches the query against clips.
enum SearchMode: String, CaseIterable, Identifiable {
    case fuzzy
    case exact
    case regex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fuzzy: return "Fuzzy"
        case .exact: return "Exact"
        case .regex: return "Regex"
        }
    }
}

/// How the history list is ordered (pinned items always come first).
enum SortMode: String, CaseIterable, Identifiable {
    case lastCopied
    case firstCopied
    case numberOfCopies

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lastCopied: return "Last copied"
        case .firstCopied: return "First copied"
        case .numberOfCopies: return "Most copied"
        }
    }
}

/// Typed access to user preferences.
///
/// Backed by `UserDefaults` for the M0 skeleton.
/// TODO(M1): migrate to the `Defaults` package for type-safe, observable keys.
final class AppSettings {
    static let shared = AppSettings()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Keys {
        static let historySize = "historySize"
        static let iconVisibility = "iconVisibility"
        static let popupPosition = "popupPosition"
        static let blockedBundleIDs = "blockedBundleIDs"
        static let ignoreAllCopies = "ignoreAllCopies"
        static let searchMode = "searchMode"
        static let sortMode = "sortMode"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    /// Maximum number of non-pinned items to keep. Defaults to 200.
    var historySize: Int {
        get {
            let stored = defaults.integer(forKey: Keys.historySize)
            return stored == 0 ? 200 : stored
        }
        set { defaults.set(newValue, forKey: Keys.historySize) }
    }

    /// Where the app icon is shown. Defaults to the menu bar.
    var iconVisibility: IconVisibility {
        get { IconVisibility(rawValue: defaults.string(forKey: Keys.iconVisibility) ?? "") ?? .menuBar }
        set { defaults.set(newValue.rawValue, forKey: Keys.iconVisibility) }
    }

    /// Where the search popup appears. Defaults to the menu bar icon.
    var popupPosition: PopupPosition {
        get { PopupPosition(rawValue: defaults.string(forKey: Keys.popupPosition) ?? "") ?? .menuBarIcon }
        set { defaults.set(newValue.rawValue, forKey: Keys.popupPosition) }
    }

    /// Bundle identifiers of apps whose copies are never recorded.
    var blockedBundleIDs: [String] {
        get { defaults.stringArray(forKey: Keys.blockedBundleIDs) ?? [] }
        set { defaults.set(newValue, forKey: Keys.blockedBundleIDs) }
    }

    /// When enabled, no new copies are recorded at all.
    var ignoreAllCopies: Bool {
        get { defaults.bool(forKey: Keys.ignoreAllCopies) }
        set { defaults.set(newValue, forKey: Keys.ignoreAllCopies) }
    }

    /// How the search field matches. Defaults to fuzzy.
    var searchMode: SearchMode {
        get { SearchMode(rawValue: defaults.string(forKey: Keys.searchMode) ?? "") ?? .fuzzy }
        set { defaults.set(newValue.rawValue, forKey: Keys.searchMode) }
    }

    /// How the list is ordered. Defaults to last-copied.
    var sortMode: SortMode {
        get { SortMode(rawValue: defaults.string(forKey: Keys.sortMode) ?? "") ?? .lastCopied }
        set { defaults.set(newValue.rawValue, forKey: Keys.sortMode) }
    }

    /// Whether the first-run welcome / permission screen has been dismissed.
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }
}
