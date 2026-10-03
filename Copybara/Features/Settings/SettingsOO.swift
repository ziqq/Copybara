// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import ApplicationServices
import Combine
import Foundation
import UniformTypeIdentifiers

/// Observable Object backing the settings screen. Reads and writes through
/// `AppSettings`, publishing changes for the SwiftUI form.
@MainActor
final class SettingsOO: ObservableObject {
    @Published var historySize: Int {
        didSet {
            settings.historySize = historySize
            notifyServices()
        }
    }
    @Published var historyRetentionDays: Int {
        didSet {
            settings.historyRetentionDays = historyRetentionDays
            notifyServices()
        }
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
        didSet {
            guard launchAtLogin != LaunchAtLoginManager.isEnabled else { return }
            LaunchAtLoginManager.setEnabled(launchAtLogin)
            // Reflect what the system actually did (registration can fail).
            let actual = LaunchAtLoginManager.isEnabled
            if actual != launchAtLogin {
                DispatchQueue.main.async { self.launchAtLogin = actual }
            }
        }
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
        didSet {
            settings.ignoreAllCopies = ignoreAllCopies
            notifyServices()
        }
    }
    @Published var blockedBundleIDs: [String] {
        didSet { settings.blockedBundleIDs = blockedBundleIDs }
    }
    @Published var snippets: [Snippet] {
        didSet { snippetStore.save(snippets) }
    }
    /// Whether Copybara currently holds the Accessibility permission.
    @Published private(set) var accessibilityGranted = Paster().hasAccessibilityPermission

    /// Whether the OS supports toggling launch at login (macOS 13+).
    let launchAtLoginSupported = LaunchAtLoginManager.isSupported
    /// Whether the OS supports Liquid Glass (macOS 26+).
    let liquidGlassSupported = LiquidGlass.isSupported

    private let settings: AppSettings
    private let snippetStore: SnippetStore

    init(settings: AppSettings = .shared, snippetStore: SnippetStore = .shared) {
        self.settings = settings
        self.snippetStore = snippetStore
        self.snippets = snippetStore.all()
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

    /// Re-reads state that can change outside the form (System Settings, the
    /// status-item menu) while the window is open.
    func refreshExternalState() {
        let granted = Paster().hasAccessibilityPermission
        if granted != accessibilityGranted { accessibilityGranted = granted }
        if settings.ignoreAllCopies != ignoreAllCopies { ignoreAllCopies = settings.ignoreAllCopies }
    }

    private func notifyServices() {
        NotificationCenter.default.post(name: .copybaraSettingsChanged, object: nil)
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

    func addSnippet() {
        snippets.append(Snippet(title: "", content: ""))
    }

    func deleteSnippets(at offsets: IndexSet) {
        snippets.remove(atOffsets: offsets)
    }
}
