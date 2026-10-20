// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import CoreData
import XCTest
@testable import Copybara

@MainActor
final class SharedApplicationIntegrationTests: XCTestCase {
    func testApplyingSmallerHistoryLimitImmediatelyKeepsPinnedAndNewestClips() throws {
        try withSharedHistory { store, settings in
            settings.historySize = 2
            settings.historyRetentionDays = 0
            store.insertTextSynchronously("pinned")
            let pinned = try XCTUnwrap(store.recentItems().first)
            store.togglePin(id: pinned.id)
            for text in ["oldest", "middle", "newest"] { store.insertTextSynchronously(text) }
            XCTAssertEqual(store.count(), 4)

            applySettings()

            let items = store.recentItems()
            XCTAssertEqual(items.map(\.preview), ["pinned", "newest", "middle"])
            XCTAssertTrue(try XCTUnwrap(items.first).isPinned)
        }
    }

    func testApplyingRetentionImmediatelyRemovesExpiredUnpinnedHistory() throws {
        try withSharedHistory { store, settings in
            settings.historySize = 200
            settings.historyRetentionDays = 1
            for text in ["old pinned", "old unpinned", "recent"] { store.insertTextSynchronously(text) }
            let pinned = try XCTUnwrap(store.recentItems().first { $0.preview == "old pinned" })
            store.togglePin(id: pinned.id)
            let request = NSFetchRequest<NSManagedObject>(entityName: "ClipEntity")
            request.predicate = NSPredicate(format: "text BEGINSWITH %@", "old")
            for object in try CoreDataStack.shared.viewContext.fetch(request) {
                object.setValue(Date().addingTimeInterval(-2 * 86_400), forKey: "createdAt")
            }
            try CoreDataStack.shared.viewContext.save()
            XCTAssertEqual(store.count(), 3)

            applySettings()

            XCTAssertEqual(store.recentItems().map(\.preview), ["old pinned", "recent"])
            XCTAssertTrue(try XCTUnwrap(store.recentItems().first).isPinned)
        }
    }

    func testOpenSettingsRefreshesRecordingStateChangedThroughStatusMenu() async throws {
        try IsolatedTestHost.require()
        let settings = AppSettings.shared
        let original = settings.ignoreAllCopies
        settings.ignoreAllCopies = false
        let controller = SettingsWindowController()
        controller.show()
        let window = try XCTUnwrap(controller.window)
        window.alphaValue = 0
        defer {
            window.close()
            settings.ignoreAllCopies = original
        }
        window.contentView?.layoutSubtreeIfNeeded()
        let refreshed = expectation(description: "the open settings form publishes the menu change")
        let token = NotificationCenter.default.addObserver(forName: .copybaraSettingsChanged, object: nil, queue: .main) { _ in
            refreshed.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }
        let menuController = StatusItemController(store: HistoryStore(stack: CoreDataStack(inMemory: true)))
        let menu = try XCTUnwrap(menuController.buildMenu().items.first { $0.title == L10n.string("Settings") }?.submenu)
        let ignore = try XCTUnwrap(menu.items.first { $0.title == L10n.string("Ignore All Copies") })

        menuController.perform(try XCTUnwrap(ignore.action))
        XCTAssertTrue(settings.ignoreAllCopies)
        await fulfillment(of: [refreshed], timeout: 4)

        XCTAssertTrue(window.isVisible)
        XCTAssertTrue(settings.ignoreAllCopies)
    }

    private func withSharedHistory(_ body: (HistoryStore, AppSettings) throws -> Void) throws {
        // The shared stack may only be opened after both its home and bundle
        // namespace have been verified as belonging to this build's test host.
        try IsolatedTestHost.require()
        let settings = AppSettings.shared
        let originalSize = settings.historySize
        let originalRetention = settings.historyRetentionDays
        let store = HistoryStore(stack: .shared, sizeLimit: 200)
        store.clearAll()
        defer {
            store.clearAll()
            settings.historySize = originalSize
            settings.historyRetentionDays = originalRetention
        }
        try body(store, settings)
    }

    private func applySettings() {
        let delegate = AppDelegate()
        let note = Notification(name: .copybaraSettingsChanged)
        XCTAssertTrue(NSApp.sendAction(NSSelectorFromString("settingsChanged:"), to: delegate, from: note as NSNotification))
    }
}
