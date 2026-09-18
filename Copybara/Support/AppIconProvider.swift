import AppKit

/// Resolves and caches the icon and display name of a source app from its bundle
/// identifier, for showing where a clip came from.
///
/// Lookups touch the filesystem, so results are cached. Accessed only from the
/// main thread (UI rendering).
enum AppIconProvider {
    private static var iconCache: [String: NSImage] = [:]
    private static var nameCache: [String: String] = [:]

    static func icon(forBundleID bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let cached = iconCache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        iconCache[bundleID] = icon
        return icon
    }

    static func name(forBundleID bundleID: String?) -> String? {
        guard let bundleID else { return nil }
        if let cached = nameCache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        nameCache[bundleID] = name
        return name
    }
}
