import AppKit

/// Watches the general pasteboard for changes and records new text clips.
///
/// `NSPasteboard` exposes no change notification, so the monitor polls
/// `changeCount` on a timer (the common approach for clipboard managers). The
/// poll itself is cheap — it only compares an integer — and does real work only
/// when the count actually changes.
final class ClipboardMonitor {
    private let pasteboard: NSPasteboard
    private let store: HistoryStore
    private let settings: AppSettings

    private var timer: Timer?
    private var lastChangeCount: Int
    private var skipNextCopy = false

    init(
        store: HistoryStore,
        settings: AppSettings = .shared,
        pasteboard: NSPasteboard = .general
    ) {
        self.store = store
        self.settings = settings
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    /// Skips recording the very next copy (⌥⇧-click on the menu icon).
    func ignoreNextCopy() {
        skipNextCopy = true
    }

    /// Begins polling. Safe to call repeatedly; any existing timer is replaced.
    func start(interval: TimeInterval = 0.5) {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer.tolerance = interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Log.clipboard.info("Clipboard monitor started")
    }

    /// Stops polling.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        // One-shot skip (⌥⇧-click) — consume it even while ignoring everything.
        if skipNextCopy {
            skipNextCopy = false
            Log.clipboard.debug("Ignored one copy on request")
            return
        }

        // Global "ignore all copies" toggle.
        if settings.ignoreAllCopies { return }

        let types = pasteboard.types ?? []
        let sourceBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        let filter = PasteboardFilter(blockedBundleIDs: Set(settings.blockedBundleIDs))
        guard filter.shouldStore(types: types, sourceBundleID: sourceBundleID) else {
            Log.clipboard.debug("Ignored a filtered pasteboard change")
            return
        }

        guard let capture = PasteboardReader.read(pasteboard, appBundleID: sourceBundleID) else { return }
        store.insert(capture)
        Log.clipboard.debug("Recorded a \(capture.kind.rawValue, privacy: .public) clip")
    }
}
