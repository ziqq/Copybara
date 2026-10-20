// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import CoreData
import XCTest

@MainActor
final class ApplicationInteractionTests: XCTestCase {
    func testPopupHoverDeletionAndNativeMenuActionsUseOwnedHistory() throws {
        try withApplication { app, _ in
            let status = app.statusItems.firstMatch
            status.click()
            let search = app.textFields["Search clips…"]
            XCTAssertTrue(search.waitForExistence(timeout: 3))
            let pinned = app.staticTexts["Pinned UI clip"].firstMatch
            XCTAssertTrue(pinned.exists)
            pinned.hover()
            let row = app.staticTexts["Delete by hover"].firstMatch
            XCTAssertTrue(row.exists)
            let rowFrame = row.frame
            row.hover()
            let remove = app.buttons.allElementsBoundByIndex.first {
                abs($0.frame.midY - rowFrame.midY) < 10 && $0.frame.minX > rowFrame.maxX
            }
            try XCTUnwrap(remove, "hovering a row must expose its delete button").click()
            search.hover()
            XCTAssertTrue(row.waitForNonExistence(timeout: 3))
            XCTAssertTrue(pinned.exists, "deleting an unpinned row must preserve the favorite")

            status.rightClick()
            XCTAssertTrue(search.waitForNonExistence(timeout: 3), "opening the native menu must dismiss the popup")
            XCTAssertTrue(app.menuItems["Copybara — 2 items"].exists)
            app.menuItems["Settings"].hover()
            app.menuItems["Ignore Next Copy"].click()
            status.rightClick()
            app.menuItems["Show Copybara"].click()
            XCTAssertTrue(search.waitForExistence(timeout: 3))
            XCTAssertFalse(row.exists, "reopening the popup must keep the deletion")
            XCTAssertTrue(pinned.exists)
            status.rightClick()
            app.menuItems["Clear All Except Favorites"].click()
            status.rightClick()
            XCTAssertTrue(app.menuItems["Copybara — 1 item"].exists)
            app.menuItems["Show Copybara"].click()
            XCTAssertTrue(search.waitForExistence(timeout: 3))
            XCTAssertTrue(pinned.exists)
            XCTAssertFalse(app.staticTexts["Another UI clip"].exists)
        }
    }

    func testSettingsButtonsAndUpdaterRunThroughApplicationDelegate() throws {
        try withApplication { app, source in
            let status = app.statusItems.firstMatch
            status.rightClick()
            app.menuItems["Settings"].hover()
            app.menuItems["Open Settings"].click()
            let settings = app.windows["Copybara Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 3))
            let addSnippet = settings.buttons["Add Snippet"]
            reveal(addSnippet, in: settings)
            let titleFields = settings.textFields.count
            addSnippet.click()
            XCTAssertEqual(settings.textFields.count, titleFields + 1)
            let addApp = settings.buttons["Add App to Blocklist…"]
            reveal(addApp, in: settings)
            addApp.click()
            app.typeKey("g", modifierFlags: [.command, .shift])
            app.typeText(source)
            app.typeKey(.return, modifierFlags: [])
            app.dialogs["open-panel"].buttons["OKButton"].click()
            XCTAssertTrue(app.dialogs["open-panel"].waitForNonExistence(timeout: 3))
            let bundleID = try XCTUnwrap(Bundle(url: URL(fileURLWithPath: source))?.bundleIdentifier)
            let name = FileManager.default.displayName(atPath: source).replacingOccurrences(of: ".app", with: "")
            let expectedNames = [bundleID, name]
            let blocked = settings.staticTexts.matching(NSPredicate(format: "value IN %@ OR label IN %@", expectedNames, expectedNames)).firstMatch
            reveal(blocked, in: settings)
            XCTAssertTrue(blocked.exists)
            let blockedFrame = blocked.frame
            let remove = settings.buttons.allElementsBoundByIndex.first {
                abs($0.frame.midY - blockedFrame.midY) < 10 && $0.frame.minX > blockedFrame.maxX
            }
            try XCTUnwrap(remove, "each blocked application must have a remove control").click()
            XCTAssertTrue(blocked.waitForNonExistence(timeout: 3))
            settings.buttons[XCUIIdentifierCloseWindow].click()

            status.rightClick()
            app.menuItems["Check for Updates…"].click()
            let cancel = app.dialogs.buttons["Cancel Update"].firstMatch
            XCTAssertTrue(cancel.waitForExistence(timeout: 5), "the unsupported local feed must show a recoverable error")
            cancel.click()
            XCTAssertTrue(cancel.waitForNonExistence(timeout: 3))
        }
    }

    private func reveal(_ element: XCUIElement, in window: XCUIElement) {
        for _ in 0..<8 {
            if element.isHittable { return }
            window.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -240)
        }
        XCTAssertTrue(element.isHittable)
    }

    private func withApplication(_ body: (XCUIApplication, String) throws -> Void) throws {
        continueAfterFailure = false
        let applicationURL = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["COPYBARA_APP_PATH"]))
        let identifier = try XCTUnwrap(Bundle(url: applicationURL)?.bundleIdentifier)
        guard identifier.hasPrefix("dev.ustinoff.copybara.coverage.") else {
            throw XCTSkip("UI tests require the isolated test command in CONTRIBUTING.md")
        }
        stopApplication(at: applicationURL)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CopybaraUI-\(UUID())")
        let home = directory.appendingPathComponent("home")
        let defaults = try XCTUnwrap(UserDefaults(suiteName: identifier))
        let originalPreferences = defaults.persistentDomain(forName: identifier)
        let original = NSWorkspace.shared.frontmostApplication
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        addTeardownBlock { @MainActor in
            let restoreFocus = NSWorkspace.shared.frontmostApplication?.bundleURL?.resolvingSymlinksInPath() == applicationURL.resolvingSymlinksInPath()
            self.stopApplication(at: applicationURL)
            if let originalPreferences { defaults.setPersistentDomain(originalPreferences, forName: identifier) }
            else { defaults.removePersistentDomain(forName: identifier) }
            try? FileManager.default.removeItem(at: directory)
            if restoreFocus, let original, !original.isTerminated { original.activate() }
        }
        try seedHistory(in: home, applicationURL: applicationURL)
        let app = XCUIApplication(url: applicationURL)
        app.launchEnvironment["HOME"] = home.path
        app.launchEnvironment["CFFIXED_USER_HOME"] = home.path
        if let profile = ProcessInfo.processInfo.environment["LLVM_PROFILE_FILE"], profile.contains("%p") || profile.contains("%m") {
            app.launchEnvironment["LLVM_PROFILE_FILE"] = profile
        }
        app.launchArguments = ["-ignoreAllCopies", "YES", "-didMigrateHotkeyToV", "YES",
                               "-KeyboardShortcuts_togglePopup", "NO", "-iconVisibility", "both",
                               "-popupPosition", "menuBarIcon", "-historyRetentionDays", "0", "-AppleLanguages", "(en)",
                               "-SUFeedURL", directory.appendingPathComponent("unsupported.xml").absoluteString]
        app.launch()
        let finish = app.buttons["Get Started"]
        if finish.waitForExistence(timeout: 2) { finish.click() }
        app.activate()
        XCTAssertTrue(app.statusItems.firstMatch.waitForExistence(timeout: 3))
        try body(app, applicationURL.path)
        app.statusItems.firstMatch.rightClick()
        app.menuItems["quit"].click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 3))
    }

    private func stopApplication(at url: URL) {
        for running in NSWorkspace.shared.runningApplications where running.bundleURL?.resolvingSymlinksInPath() == url.resolvingSymlinksInPath() {
            running.terminate()
            let deadline = Date().addingTimeInterval(2)
            while !running.isTerminated, Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
            if !running.isTerminated {
                running.forceTerminate()
                let stopped = Date().addingTimeInterval(2)
                while !running.isTerminated, Date() < stopped { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
            }
            XCTAssertTrue(running.isTerminated, "the owned UI application must not outlive its fixture")
        }
    }

    private func seedHistory(in home: URL, applicationURL: URL) throws {
        let modelURL = applicationURL.appendingPathComponent("Contents/Resources/Copybara.momd")
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
        let container = NSPersistentContainer(name: "Copybara", managedObjectModel: model)
        let directory = home.appendingPathComponent("Library/Application Support/Copybara")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: directory.appendingPathComponent("Copybara.sqlite"))]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        let entity = try XCTUnwrap(model.entitiesByName["ClipEntity"])
        for (index, text) in ["Pinned UI clip", "Delete by hover", "Another UI clip"].enumerated() {
            let object = NSManagedObject(entity: entity, insertInto: container.viewContext)
            object.setValue(UUID(), forKey: "id")
            object.setValue(text, forKey: "text")
            object.setValue("text", forKey: "kind")
            object.setValue(Date().addingTimeInterval(Double(-index)), forKey: "createdAt")
            object.setValue(Date(), forKey: "firstCopiedAt")
            object.setValue(index == 0, forKey: "isPinned")
        }
        try container.viewContext.save()
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
    }
}
