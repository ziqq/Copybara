// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import SwiftUI
import XCTest
@testable import Copybara

@MainActor
final class PopupDestinationTests: XCTestCase {
    func testDeferredPasteTargetsLiveApplicationAfterPopupCloses() async throws {
        let original = NSWorkspace.shared.frontmostApplication
        let existingPIDs = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("popup-destination-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = true
        // The existing debug renderer opens fixed sample data and returns
        // before clipboard monitoring, shortcuts or the user's store start.
        configuration.environment = [
            "COPYBARA_SCREENSHOT": "1",
            // Only the parent is the subject of this test's coverage report.
            "LLVM_PROFILE_FILE": directory.appendingPathComponent("destination-%p.profraw").path
        ]
        let destination = try await NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL, configuration: configuration)
        guard !existingPIDs.contains(destination.processIdentifier) else {
            XCTFail("the focus fixture must launch a separate process")
            return
        }
        defer { stopDestination(destination, restoring: original) }
        let deadline = Date().addingTimeInterval(5)
        while NSWorkspace.shared.frontmostApplication?.processIdentifier != destination.processIdentifier,
              !destination.isTerminated, Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertFalse(destination.isTerminated)
        XCTAssertEqual(NSWorkspace.shared.frontmostApplication?.processIdentifier, destination.processIdentifier)

        let name = "popup-destination-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        let board = NSPasteboard(name: .init(name))
        defer { board.releaseGlobally(); defaults.removePersistentDomain(forName: name) }
        let store = HistoryStore(stack: CoreDataStack(inMemory: true))
        store.insertTextSynchronously("paste into the live destination")
        let posted = expectation(description: "the deferred paste reaches the keyboard stream")
        posted.expectedFulfillmentCount = 2
        var types: [CGEventType] = []
        var targets: [pid_t?] = []
        let paster = Paster(pasteboard: board, accessibilityPermission: { true }, postEvent: { event, tap in
            // Capture the chord rather than posting keyboard input to macOS.
            types.append(event.type)
            targets.append(NSWorkspace.shared.frontmostApplication?.processIdentifier)
            XCTAssertEqual(tap, .cgSessionEventTap)
            XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), 9)
            posted.fulfill()
        })
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        let controller = PopupController(store: store, paster: paster,
            settings: AppSettings(defaults: defaults), snippets: SnippetStore(defaults: defaults))
        controller.onAccessibilityRequired = { XCTFail("the granted permission must not request recovery") }
        defer { controller.hide() }
        let window = try XCTUnwrap(NSApp.windows.compactMap { $0 as? PopupWindow }
            .first { !existing.contains(ObjectIdentifier($0)) })
        window.alphaValue = 0
        window.hasShadow = false
        controller.show()
        var views = [try XCTUnwrap(window.contentView)]
        var hosting: NSHostingView<PopupView>?
        while let view = views.popLast() {
            if let match = view as? NSHostingView<PopupView> { hosting = match; break }
            views.append(contentsOf: view.subviews)
        }
        try XCTUnwrap(hosting).rootView.onAction(.paste)
        XCTAssertFalse(controller.isVisible)
        XCTAssertTrue(types.isEmpty, "the chord must wait for the destination's focused field")

        await fulfillment(of: [posted], timeout: 3)

        XCTAssertEqual(types, [.keyDown, .keyUp])
        XCTAssertEqual(targets, [destination.processIdentifier, destination.processIdentifier])
        XCTAssertEqual(board.string(forType: .string), "paste into the live destination")
    }

    private func stopDestination(_ destination: NSRunningApplication, restoring original: NSRunningApplication?) {
        let restoreFocus = NSWorkspace.shared.frontmostApplication?.processIdentifier == destination.processIdentifier
        destination.terminate()
        let deadline = Date().addingTimeInterval(2)
        while !destination.isTerminated, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        if !destination.isTerminated { destination.forceTerminate() }
        if restoreFocus, let original, !original.isTerminated { original.activate() }
    }
}
