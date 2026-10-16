// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import UniformTypeIdentifiers
import XCTest
@testable import Copybara

@MainActor
final class SettingsOOTests: XCTestCase {
    private func make() -> (SettingsOO, AppSettings) {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "soo-\(UUID().uuidString)")!)
        return (SettingsOO(settings: settings), settings)
    }

    func testWritesThroughToSettings() {
        let (oo, settings) = make()
        oo.historySize = 42
        oo.historyRetentionDays = 7
        oo.searchMode = .exact
        oo.sortMode = .firstCopied
        oo.popupPosition = .center
        oo.useLiquidGlass = false
        oo.ignoreAllCopies = true
        oo.blockedBundleIDs = ["com.z"]

        XCTAssertEqual(settings.historySize, 42)
        XCTAssertEqual(settings.historyRetentionDays, 7)
        XCTAssertEqual(settings.searchMode, .exact)
        XCTAssertEqual(settings.sortMode, .firstCopied)
        XCTAssertEqual(settings.popupPosition, .center)
        XCTAssertFalse(settings.useLiquidGlass)
        XCTAssertTrue(settings.ignoreAllCopies)
        XCTAssertEqual(settings.blockedBundleIDs, ["com.z"])
    }

    func testIconVisibilityPostsNotification() {
        let (oo, _) = make()
        let expectation = expectation(forNotification: .copybaraIconVisibilityChanged, object: nil)
        oo.iconVisibility = .dock
        wait(for: [expectation], timeout: 1)
    }

    func testRefreshReadsMenuChangesWithoutOverwritingThem() {
        let (oo, settings) = make()
        settings.ignoreAllCopies = true
        settings.popupPosition = .cursor

        oo.refreshExternalState()

        XCTAssertTrue(oo.ignoreAllCopies)
        XCTAssertEqual(oo.popupPosition, .cursor)
        XCTAssertTrue(settings.ignoreAllCopies)
        XCTAssertEqual(settings.popupPosition, .cursor)
    }

    func testHistoryAndRecordingChangesNotifyRunningServices() {
        let (oo, _) = make()
        let changed = expectation(forNotification: .copybaraSettingsChanged, object: nil)
        changed.expectedFulfillmentCount = 3
        oo.historySize = 50
        oo.historyRetentionDays = 7
        oo.ignoreAllCopies = true
        wait(for: [changed], timeout: 1)
    }

    func testRemoveBlockedAppPreservesOtherEntries() {
        let (oo, settings) = make()
        oo.blockedBundleIDs = ["com.first", "com.second"]
        oo.removeBlockedApp("com.first")
        oo.removeBlockedApp("com.missing")
        XCTAssertEqual(oo.blockedBundleIDs, ["com.second"])
        XCTAssertEqual(settings.blockedBundleIDs, ["com.second"])
    }

    func testCancellingBlockedAppPickerPreservesBlocklistAndRestrictsSelectionToApplications() {
        let (oo, settings) = make()
        oo.blockedBundleIDs = ["com.example.already-blocked"]
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        let deadline = Date().addingTimeInterval(2)
        var inspected = false
        let cancel = Timer(timeInterval: 0.01, repeats: true) { timer in
            let panel = NSApp.modalWindow as? NSOpenPanel ?? NSApp.windows.compactMap { $0 as? NSOpenPanel }
                .first { !existing.contains(ObjectIdentifier($0)) }
            if let panel {
                panel.alphaValue = 0
                inspected = true
                XCTAssertTrue(panel.canChooseFiles)
                XCTAssertFalse(panel.canChooseDirectories)
                XCTAssertFalse(panel.allowsMultipleSelection)
                XCTAssertEqual(panel.allowedContentTypes, [.application])
                panel.cancel(nil)
                timer.invalidate()
            } else if Date() >= deadline {
                XCTFail("The application's blocklist picker did not enter its modal session")
                NSApp.abortModal()
                timer.invalidate()
            }
        }
        RunLoop.main.add(cancel, forMode: .common)
        RunLoop.main.add(cancel, forMode: .modalPanel)
        defer { cancel.invalidate() }

        oo.addBlockedApp()

        XCTAssertTrue(inspected)
        XCTAssertEqual(oo.blockedBundleIDs, ["com.example.already-blocked"])
        XCTAssertEqual(settings.blockedBundleIDs, ["com.example.already-blocked"])
    }

    func testSnippetEditsAndDeletionPersistAcrossSettingsInstances() {
        let name = "soo-snippets-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        let store = SnippetStore(defaults: defaults)
        let first = Snippet(title: "First", content: "one")
        let second = Snippet(title: "Second", content: "two")
        store.save([first, second])
        let oo = SettingsOO(settings: settings, snippetStore: store)
        XCTAssertEqual(oo.snippets, [first, second])

        oo.addSnippet()
        oo.snippets[2].title = "Third"
        oo.snippets[2].content = "three"
        oo.deleteSnippets(at: IndexSet(integer: 1))

        let reloaded = SettingsOO(settings: settings, snippetStore: store)
        XCTAssertEqual(reloaded.snippets.map(\.title), ["First", "Third"])
        XCTAssertEqual(reloaded.snippets.map(\.content), ["one", "three"])
        XCTAssertEqual(reloaded.snippets.first?.id, first.id)
    }
}
