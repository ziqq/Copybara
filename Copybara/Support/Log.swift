import OSLog

/// Namespaced `os.Logger` instances used across Copybara.
///
/// Logging is intentionally lightweight and never records clip *contents* at
/// default levels — only sizes and coarse events — to respect the local-only
/// privacy principle.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "dev.ustinoff.copybara"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let clipboard = Logger(subsystem: subsystem, category: "clipboard")
    static let paste = Logger(subsystem: subsystem, category: "paste")
}
