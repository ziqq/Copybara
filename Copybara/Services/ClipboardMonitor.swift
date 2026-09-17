import AppKit

/// Watches the general pasteboard for changes and records new text clips.
///
/// `NSPasteboard` exposes no change notification, so the monitor polls
/// `changeCount` on a timer (the same approach Maccy uses). The poll itself is
/// cheap — it only compares an integer — and does real work only when the count
/// actually changes.
final class ClipboardMonitor {
    private let pasteboard: NSPasteboard
    private let store: HistoryStore
    private let filter: PasteboardFilter

    private var timer: Timer?
    private var lastChangeCount: Int

    init(
        store: HistoryStore,
        filter: PasteboardFilter = PasteboardFilter(),
        pasteboard: NSPasteboard = .general
    ) {
        self.store = store
        self.filter = filter
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
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

        let types = pasteboard.types ?? []
        let sourceBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        guard filter.shouldStore(types: types, sourceBundleID: sourceBundleID) else {
            Log.clipboard.debug("Ignored a filtered pasteboard change")
            return
        }

        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        store.insertText(text, appBundleID: sourceBundleID)
        Log.clipboard.debug("Recorded a clip (\(text.count, privacy: .public) chars)")
    }
}
