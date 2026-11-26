// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import XCTest
import Sparkle
import SwiftUI
@testable import Copybara

@MainActor
final class UpdaterPresentationTests: XCTestCase {
    func testCompactPromptButtonsReturnTheirChoicesAndEndModalSession() {
        for (buttonY, expected) in [(64.0, SPUUserUpdateChoice.install), (30.0, .skip)] {
            let driver = CompactUpdateUserDriver(hostBundle: .main)
            let click = Timer(timeInterval: 0.2, repeats: false) { _ in
                MainActor.assumeIsolated {
                    guard let panel = NSApp.modalWindow else { return }
                    let point = NSPoint(x: panel.frame.width / 2, y: buttonY)
                    for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                        let event = NSEvent.mouseEvent(
                            with: type, location: point, modifierFlags: [],
                            timestamp: ProcessInfo.processInfo.systemUptime,
                            windowNumber: panel.windowNumber, context: nil,
                            eventNumber: 0, clickCount: 1, pressure: 1
                        )
                        if let event { NSApp.postEvent(event, atStart: false) }
                    }
                }
            }
            let timeout = Timer(timeInterval: 3, repeats: false) { _ in
                MainActor.assumeIsolated {
                    XCTFail("the update button did not finish the modal session")
                    NSApp.abortModal()
                }
            }
            RunLoop.main.add(click, forMode: .modalPanel)
            RunLoop.main.add(timeout, forMode: .modalPanel)
            defer { click.invalidate(); timeout.invalidate() }
            var choices: [SPUUserUpdateChoice] = []

            driver.showCompactUpdate(version: "1.0", current: "0.9") { choices.append($0) }

            XCTAssertEqual(choices, [expected])
            XCTAssertNil(NSApp.modalWindow)
            driver.dismissUpdateInstallation()
            XCTAssertEqual(choices, [expected], "cleanup must not reply to the update a second time")
        }
    }

    func testCompactPromptReturnsExactlyOneInstallationChoice() {
        for (response, choice) in [(NSApplication.ModalResponse.alertFirstButtonReturn, SPUUserUpdateChoice.install),
                                   (.alertSecondButtonReturn, .skip), (.abort, .dismiss)] {
            let driver = CompactUpdateUserDriver(hostBundle: .main, runModal: { _ in response })
            var replies: [SPUUserUpdateChoice] = []
            // Exercise the driver's real transition and reply without opening
            // a modal window or downloading/installing a test update.
            driver.showCompactUpdate(version: "0.1.6", current: "0.1.5") { replies.append($0) }
            XCTAssertEqual(replies, [choice])
            driver.dismissUpdateInstallation()
        }
    }

    func testFocusRequestBringsTheActiveCompactPromptForward() {
        var driver: CompactUpdateUserDriver!
        driver = CompactUpdateUserDriver(hostBundle: .main, runModal: { panel in
            panel.orderOut(nil)
            driver.showUpdateInFocus()
            XCTAssertTrue(panel.isVisible)
            return .alertSecondButtonReturn
        })
        defer { driver = nil }
        var choices: [SPUUserUpdateChoice] = []
        driver.showCompactUpdate(version: "1.0", current: "0.9") { choices.append($0) }
        XCTAssertEqual(choices, [.skip])
    }

    func testLongVersionStringsWrapWithoutWideningThePanelOrLosingEitherVersion() {
        let version = "2026.10.15-release-candidate-with-a-long-build-identifier"
        let current = "2026.09.01-previous-release-with-a-long-build-identifier"
        var sizes: [NSSize] = []
        let driver = CompactUpdateUserDriver(hostBundle: .main, runModal: { panel in
            XCTAssertEqual(panel.styleMask, .borderless)
            sizes.append(panel.frame.size)
            let content = panel.contentView as? NSHostingView<UpdateDialogView>
            XCTAssertNotNil(content)
            if sizes.count == 2 {
                XCTAssertTrue(content?.rootView.message.contains(version) == true)
                XCTAssertTrue(content?.rootView.message.contains(current) == true)
            }
            return .cancel
        })
        driver.showCompactUpdate(version: "0.1.6", current: "0.1.5") { _ in }
        driver.showCompactUpdate(version: version, current: current) { _ in }
        XCTAssertEqual(sizes.map(\.width), [304, 304])
        if let normal = sizes.first, let wrapped = sizes.last {
            XCTAssertGreaterThan(wrapped.height, normal.height)
        }
    }

    func testDismissalClosesActiveCompactPromptAndRepliesOnce() {
        var driver: CompactUpdateUserDriver!
        driver = CompactUpdateUserDriver(hostBundle: .main, runModal: { panel in
            let session = NSApp.beginModalSession(for: panel)
            defer { NSApp.endModalSession(session) }
            _ = NSApp.runModalSession(session)
            driver.dismissUpdateInstallation()
            XCTAssertFalse(panel.isVisible)
            return .abort
        })
        defer { driver = nil }
        var choices: [SPUUserUpdateChoice] = []
        driver.showCompactUpdate(version: "1.0", current: "0.9") { choices.append($0) }
        XCTAssertEqual(choices, [.dismiss])
    }
}
