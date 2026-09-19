import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

/// Observable Object backing the settings screen. Reads and writes through
/// `AppSettings`, publishing changes for the SwiftUI form.
@MainActor
final class SettingsOO: ObservableObject {
    @Published var historySize: Int {
        didSet { settings.historySize = historySize }
    }
    @Published var historyRetentionDays: Int {
        didSet { settings.historyRetentionDays = historyRetentionDays }
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
    @Published var useLiquidGlass: Bool {
        didSet { settings.useLiquidGlass = useLiquidGlass }
    }
    @Published var searchMode: SearchMode {
        didSet { settings.searchMode = searchMode }
    }
    @Published var sortMode: SortMode {
        didSet { settings.sortMode = sortMode }
    }
    @Published var ignoreAllCopies: Bool {
        didSet { settings.ignoreAllCopies = ignoreAllCopies }
    }
    @Published var blockedBundleIDs: [String] {
        didSet { settings.blockedBundleIDs = blockedBundleIDs }
    }

    /// Whether the OS supports toggling launch at login (macOS 13+).
    let launchAtLoginSupported = LaunchAtLoginManager.isSupported
    /// Whether the OS supports Liquid Glass (macOS 26+).
    let liquidGlassSupported = LiquidGlass.isSupported

    private let settings: AppSettings

    init(settings: AppSettings = .shared) {
        self.settings = settings
        self.historySize = settings.historySize
        self.historyRetentionDays = settings.historyRetentionDays
        self.iconVisibility = settings.iconVisibility
        self.popupPosition = settings.popupPosition
        self.useLiquidGlass = settings.useLiquidGlass
        self.searchMode = settings.searchMode
        self.sortMode = settings.sortMode
        self.launchAtLogin = LaunchAtLoginManager.isEnabled
        self.ignoreAllCopies = settings.ignoreAllCopies
        self.blockedBundleIDs = settings.blockedBundleIDs
    }

    /// Opens a file picker to add an app to the blocklist by its bundle id.
    func addBlockedApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
        if !blockedBundleIDs.contains(bundleID) {
            blockedBundleIDs.append(bundleID)
        }
    }

    func removeBlockedApp(_ bundleID: String) {
        blockedBundleIDs.removeAll { $0 == bundleID }
    }
}
