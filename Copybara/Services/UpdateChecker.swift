import Foundation

/// On-demand update check via the GitHub Releases API: asks for the latest
/// published release and compares it to the running version from Info.plist.
///
/// Manual only (a menu item) — there is no background polling. Copybara never
/// downloads or replaces itself; it points the user to the release page. This is
/// the right fit for non-App-Store builds distributed via GitHub Releases (no
/// Sparkle keys, appcast, or notarization required).
enum UpdateChecker {
    static let repo = "ziqq/Copybara"
    static let releasesPage = URL(string: "https://github.com/\(repo)/releases/latest")!
    private static let apiURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!

    struct Release: Equatable {
        let version: String
        /// The release page.
        let url: URL
        /// The downloadable DMG asset, when present.
        let downloadURL: URL?
    }

    enum Outcome: Equatable {
        case upToDate(current: String)
        case available(Release)
        case failed(String)
    }

    static func current() -> String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    static func check() async -> Outcome {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // GitHub answers 403 without a User-Agent.
        request.setValue("Copybara", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            // 404 — no releases published yet. Not an error: nothing to update to.
            if status == 404 { return .upToDate(current: current()) }
            guard status == 200 else { return .failed("HTTP \(status)") }
            guard let release = parse(data) else { return .failed(L10n.string("Couldn't read the release info")) }
            let current = current()
            return isNewer(release.version, than: current) ? .available(release) : .upToDate(current: current)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Pure helpers (unit-tested)

    /// Parses a GitHub "latest release" JSON payload.
    static func parse(_ data: Data) -> Release? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = root["tag_name"] as? String, !tag.isEmpty
        else { return nil }

        let url = (root["html_url"] as? String).flatMap(URL.init(string:)) ?? releasesPage
        let assets = (root["assets"] as? [[String: Any]]) ?? []
        let download: URL? = assets.lazy.compactMap { entry -> URL? in
            guard let name = entry["name"] as? String, name.hasSuffix(".dmg"),
                  let link = (entry["browser_download_url"] as? String).flatMap(URL.init(string:)) else { return nil }
            return link
        }.first

        return Release(version: normalize(tag), url: url, downloadURL: download)
    }

    /// "v1.2.0" → "1.2.0".
    static func normalize(_ tag: String) -> String {
        (tag.hasPrefix("v") || tag.hasPrefix("V")) ? String(tag.dropFirst()) : tag
    }

    /// Numeric component comparison: "1.10.0" is newer than "1.9.9".
    static func isNewer(_ candidate: String, than base: String) -> Bool {
        let lhs = components(candidate), rhs = components(base)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        version.split(whereSeparator: { $0 == "." || $0 == "-" }).map { Int($0) ?? 0 }
    }
}
