// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import CoreData
import XCTest
@testable import Copybara

@MainActor
final class ClipboardMonitorTests: XCTestCase {
    private func fixture() -> (CoreDataStack, HistoryStore, AppSettings, NSPasteboard) {
        let stack = CoreDataStack(inMemory: true)
        let store = HistoryStore(stack: stack)
        let name = "monitor-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        let settings = AppSettings(defaults: defaults)
        let board = NSPasteboard(name: .init(name))
        settings.blockedBundleIDs = ["blocked"]
        settings.historyRetentionDays = 0
        addTeardownBlock {
            defaults.removePersistentDomain(forName: name)
            board.releaseGlobally()
        }
        return (stack, store, settings, board)
    }

    func testCopyFromBlockedAppThenSwitchBeforePollIsDiscarded() async {
        let (stack, store, settings, board) = fixture()
        var foreground: String? = "blocked"
        let monitor = ClipboardMonitor(store: store, settings: settings, pasteboard: board,
                                       foregroundBundleID: { foreground })
        let (unexpected, stopObserving) = observeInsert(stack, inverted: true)
        board.clearContents()
        XCTAssertTrue(board.setString("private copy", forType: .string))
        foreground = "allowed"
        monitor.applicationActivated(bundleID: foreground)
        monitor.poll()
        await fulfillment(of: [unexpected], timeout: 0.2)
        stopObserving()
        XCTAssertEqual(store.count(), 0)

        let (inserted, _) = observeInsert(stack)
        board.clearContents()
        board.setString("public copy", forType: .string)
        monitor.poll()
        await fulfillment(of: [inserted], timeout: 2)
        XCTAssertEqual(store.recentItems(includePayloads: false).map(\.preview), ["public copy"])
    }

    func testPollAlsoDiscardsBlockedTransitionIfActivationNotificationWasDelayed() async {
        let (stack, store, settings, board) = fixture()
        var foreground: String? = "blocked"
        let monitor = ClipboardMonitor(store: store, settings: settings, pasteboard: board,
                                       foregroundBundleID: { foreground })
        let (unexpected, stopObserving) = observeInsert(stack, inverted: true)
        board.clearContents()
        XCTAssertTrue(board.setString("private copy", forType: .string))
        foreground = "allowed"
        monitor.poll()
        await fulfillment(of: [unexpected], timeout: 0.2)
        stopObserving()
        XCTAssertEqual(store.count(), 0)
    }

    func testRetentionPrunesDuringIdleRunAndKeepsPinnedClips() {
        let (_, store, settings, board) = fixture()
        settings.historyRetentionDays = 1
        store.insertTextSynchronously("old")
        store.insertTextSynchronously("pinned")
        store.togglePin(id: store.recentItems().first!.id)
        var date = Date()
        let monitor = ClipboardMonitor(store: store, settings: settings, pasteboard: board,
                                       foregroundBundleID: { "allowed" }, now: { date })
        monitor.poll()
        XCTAssertEqual(store.count(), 2)
        date = date.addingTimeInterval(2 * 86_400)
        monitor.poll() // pasteboard unchanged: housekeeping must still run
        XCTAssertEqual(store.recentItems().map(\.preview), ["pinned"])
    }

    func testRetentionZeroKeepsHistoryDuringIdleRun() {
        let (_, store, settings, board) = fixture()
        store.insertTextSynchronously("keep forever")
        var date = Date()
        let monitor = ClipboardMonitor(store: store, settings: settings, pasteboard: board,
                                       foregroundBundleID: { "allowed" }, now: { date })
        monitor.poll()
        date = date.addingTimeInterval(1_000 * 86_400)
        monitor.poll()
        XCTAssertEqual(store.count(), 1)
    }

    func testIgnoreNextCopyIsConsumedAtBlockedTransition() async {
        let (stack, store, settings, board) = fixture()
        var foreground: String? = "blocked"
        let monitor = ClipboardMonitor(store: store, settings: settings, pasteboard: board,
                                       foregroundBundleID: { foreground })
        monitor.ignoreNextCopy()
        board.clearContents()
        XCTAssertTrue(board.setString("blocked copy", forType: .string))
        foreground = "allowed"
        monitor.applicationActivated(bundleID: foreground)
        let (inserted, _) = observeInsert(stack)
        board.clearContents()
        board.setString("next allowed copy", forType: .string)
        monitor.poll()
        await fulfillment(of: [inserted], timeout: 2)
        XCTAssertEqual(store.recentItems(includePayloads: false).map(\.preview), ["next allowed copy"])
    }

    private func observeInsert(_ stack: CoreDataStack, inverted: Bool = false) -> (XCTestExpectation, () -> Void) {
        let saved = expectation(description: "clip inserted")
        saved.isInverted = inverted
        let observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: nil, queue: nil) { note in
            guard let context = note.object as? NSManagedObjectContext,
                  context.persistentStoreCoordinator === stack.container.persistentStoreCoordinator,
                  let inserted = note.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>,
                  !inserted.isEmpty else { return }
            saved.fulfill()
        }
        addTeardownBlock { NotificationCenter.default.removeObserver(observer) }
        return (saved, { NotificationCenter.default.removeObserver(observer) })
    }
}
