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
}
