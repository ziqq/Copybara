// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import CoreData
import XCTest
@testable import Copybara

@MainActor
final class ApplicationStartupTests: XCTestCase {
    func testNormalStartupCreatesIsolatedEmptyHistoryAndMenuBarApplication() async throws {
        let name = "CopybaraRuntime-\(UUID().uuidString)"
        let identifier = "dev.copybara.runtime-test.\(UUID().uuidString.lowercased())"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        let home = directory.appendingPathComponent("home", isDirectory: true)
        let applicationURL = directory.appendingPathComponent("\(name).app", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer {
            UserDefaults(suiteName: identifier)?.removePersistentDomain(forName: identifier)
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.copyItem(at: Bundle.main.bundleURL, to: applicationURL)
        let infoURL = applicationURL.appendingPathComponent("Contents/Info.plist")
        var info = try XCTUnwrap(try PropertyListSerialization.propertyList(
            from: Data(contentsOf: infoURL), format: nil) as? [String: Any])
        let executable = try XCTUnwrap(info["CFBundleExecutable"] as? String)
        try FileManager.default.moveItem(
            at: applicationURL.appendingPathComponent("Contents/MacOS/\(executable)"),
            to: applicationURL.appendingPathComponent("Contents/MacOS/\(name)"))
        info["CFBundleExecutable"] = name
        info["CFBundleName"] = name
        info["CFBundleDisplayName"] = name
        info["CFBundleIdentifier"] = identifier
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: infoURL)

        let original = NSWorkspace.shared.frontmostApplication
        let existingPIDs = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = false
        configuration.arguments = [
            "-ignoreAllCopies", "YES", "-didMigrateHotkeyToV", "YES",
            "-KeyboardShortcuts_togglePopup", "NO", "-iconVisibility", "menuBar"
        ]
        // Run the real launch path, without XCTest injection or the screenshot
        // renderer. The unique executable/bundle also isolate defaults and the
        // store name if the OS does not honor the temporary home directory.
        configuration.environment = ["HOME": home.path, "CFFIXED_USER_HOME": home.path]
        let profile = ProcessInfo.processInfo.environment["LLVM_PROFILE_FILE"]
        configuration.environment["LLVM_PROFILE_FILE"] = profile.flatMap {
            $0.contains("%p") || $0.contains("%m") ? $0 : nil
        } ?? directory.appendingPathComponent("startup-%p.profraw").path
        let application = try await NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration)
        guard !existingPIDs.contains(application.processIdentifier), application.bundleIdentifier == identifier else {
            XCTFail("the startup fixture must own a separately identified application")
            return
        }
        defer { stop(application, restoring: original) }

        let deadline = Date().addingTimeInterval(5)
        var storeURL: URL?
        while !application.isTerminated, Date() < deadline {
            let files = FileManager.default.enumerator(at: home, includingPropertiesForKeys: nil)
            storeURL = files?.compactMap { $0 as? URL }.first { $0.lastPathComponent == "Copybara.sqlite" }
            if application.isFinishedLaunching, storeURL != nil { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertFalse(application.isTerminated, "normal startup must finish without crashing")
        XCTAssertTrue(application.isFinishedLaunching)
        XCTAssertEqual(application.activationPolicy, .accessory)
        let historyURL = try XCTUnwrap(storeURL, "startup must create its store inside the test-owned home")

        XCTAssertTrue(application.terminate())
        let stopped = Date().addingTimeInterval(5)
        while !application.isTerminated, Date() < stopped {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(application.isTerminated, "normal Quit must stop the fixture without a forced termination")
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: historyURL)
        XCTAssertEqual(metadata[NSStoreTypeKey] as? String, NSSQLiteStoreType)
        let store = HistoryStore(stack: CoreDataStack(storeURL: historyURL))
        XCTAssertEqual(store.count(), 0, "the isolated startup must not import or record the user's clipboard history")
    }

    private func stop(_ application: NSRunningApplication, restoring original: NSRunningApplication?) {
        let restoreFocus = NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier
        if !application.isTerminated {
            application.forceTerminate()
            let deadline = Date().addingTimeInterval(2)
            while !application.isTerminated, Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            }
            XCTAssertTrue(application.isTerminated, "the test must not leave its fixture process running")
        }
        if restoreFocus, let original, !original.isTerminated { original.activate() }
    }
}
