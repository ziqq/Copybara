// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

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
    private let foregroundBundleID: () -> String?
    private let now: () -> Date

    private var timer: Timer?
    private var lastChangeCount: Int
    private var skipNextCopy = false
    private var lastForegroundBundleID: String?
    private var activationObserver: NSObjectProtocol?
    private var lastPruneDate: Date?

    init(
        store: HistoryStore,
        settings: AppSettings = .shared,
        pasteboard: NSPasteboard = .general,
        foregroundBundleID: @escaping () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier },
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.settings = settings
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
        self.foregroundBundleID = foregroundBundleID
        self.lastForegroundBundleID = foregroundBundleID()
        self.now = now
    }

    /// Skips recording the very next copy (⌥⇧-click on the menu icon).
    func ignoreNextCopy() {
        skipNextCopy = true
    }

    /// Begins polling. Safe to call repeatedly; any existing timer is replaced.
    func start(interval: TimeInterval = 0.5) {
        stop()
        applicationActivated(bundleID: foregroundBundleID())
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.applicationActivated(bundleID: app?.bundleIdentifier)
        }
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
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
    }

    deinit { stop() }

    /// Discard unread clipboard changes on either side of a blocked-app
    /// transition. The pasteboard supplies no trustworthy source identity.
    func applicationActivated(bundleID: String?) {
        let blocked = Set(settings.blockedBundleIDs)
        if lastForegroundBundleID.map(blocked.contains) == true || bundleID.map(blocked.contains) == true {
            discardPendingChange()
        }
        lastForegroundBundleID = bundleID
    }

    private func discardPendingChange() {
        let current = pasteboard.changeCount
        if current != lastChangeCount { skipNextCopy = false }
        lastChangeCount = current
    }

    func poll() {
        let date = now()
        if lastPruneDate == nil || date.timeIntervalSince(lastPruneDate!) >= 3_600 {
            store.pruneExpired(olderThan: settings.historyRetentionDays, now: date)
            lastPruneDate = date
        }

        let sourceBundleID = foregroundBundleID()
        if sourceBundleID != lastForegroundBundleID {
            applicationActivated(bundleID: sourceBundleID)
        }
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
