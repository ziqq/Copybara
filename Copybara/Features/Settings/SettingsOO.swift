import Combine
import Foundation

/// Observable Object backing the settings screen. Reads and writes through
/// `AppSettings`, publishing changes for the SwiftUI form.
@MainActor
final class SettingsOO: ObservableObject {
    @Published var historySize: Int {
        didSet { settings.historySize = historySize }
    }
    @Published var iconVisibility: IconVisibility {
        didSet {
            settings.iconVisibility = iconVisibility
            NotificationCenter.default.post(
                name: .copybaraIconVisibilityChanged,
                object: nil,
                userInfo: ["value": iconVisibility.rawValue]
            )
        }
    }
    @Published var popupPosition: PopupPosition {
        didSet { settings.popupPosition = popupPosition }
    }
    @Published var launchAtLogin: Bool {
        didSet { LaunchAtLoginManager.setEnabled(launchAtLogin) }
    }

    /// Whether the OS supports toggling launch at login (macOS 13+).
    let launchAtLoginSupported = LaunchAtLoginManager.isSupported

    private let settings: AppSettings

    init(settings: AppSettings = .shared) {
        self.settings = settings
        self.historySize = settings.historySize
        self.iconVisibility = settings.iconVisibility
        self.popupPosition = settings.popupPosition
        self.launchAtLogin = LaunchAtLoginManager.isEnabled
    }
}
