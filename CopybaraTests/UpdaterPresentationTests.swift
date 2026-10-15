// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import XCTest
import Sparkle
@testable import Copybara

@MainActor
final class UpdaterPresentationTests: XCTestCase {
    func testCompactPromptReturnsExactlyOneInstallationChoice() {
        for (response, choice) in [(NSApplication.ModalResponse.alertFirstButtonReturn, SPUUserUpdateChoice.install),
                                   (.alertSecondButtonReturn, .skip), (.abort, .dismiss)] {
            let driver = CompactUpdateUserDriver(hostBundle: .main, presentAlert: { _ in response })
            var replies: [SPUUserUpdateChoice] = []
            // Exercise the driver's real transition and reply without opening
            // a modal window or downloading/installing a test update.
            driver.showCompactUpdate(version: "0.1.6", current: "0.1.5") { replies.append($0) }
            XCTAssertEqual(replies, [choice])
            driver.dismissUpdateInstallation()
        }
    }

    func testUpdatePromptWrapsVersionTextInCompactWindow() throws {
        let alert = CompactUpdateUserDriver.makeAlert(version: "0.1.6", current: "0.1.5")
        let label = try XCTUnwrap(alert.accessoryView as? NSTextField)
        XCTAssertTrue(label.stringValue.contains("0.1.6"))
        XCTAssertTrue(label.stringValue.contains("0.1.5"))
        XCTAssertTrue(try XCTUnwrap(label.cell).wraps)
        alert.layout()
        XCTAssertLessThanOrEqual(alert.window.frame.width, 560,
                                 "the version sentence must wrap instead of widening the update window")
        XCTAssertEqual(alert.buttons.count, 2, "install and skip remain available")
        alert.window.close()
    }

    func testFocusRequestBringsTheActiveCompactPromptForward() {
        var driver: CompactUpdateUserDriver!
        var focusedWindow: NSWindow?
        driver = CompactUpdateUserDriver(hostBundle: .main, presentAlert: { alert in
            alert.window.alphaValue = 0
            alert.window.hasShadow = false
            focusedWindow = alert.window
            driver.showUpdateInFocus()
            XCTAssertTrue(alert.window.isVisible)
            return .alertSecondButtonReturn
        })
        defer { focusedWindow?.close(); driver = nil }
        var choices: [SPUUserUpdateChoice] = []
        driver.showCompactUpdate(version: "1.0", current: "0.9") { choices.append($0) }
        XCTAssertEqual(choices, [.skip])
    }

    func testLongVersionStringsRemainInWrappedPromptWithoutLosingEitherVersion() throws {
        let version = "2026.10.15-release-candidate-with-a-long-build-identifier"
        let current = "2026.09.01-previous-release-with-a-long-build-identifier"
        let alert = CompactUpdateUserDriver.makeAlert(version: version, current: current)
        defer { alert.window.close() }
        let label = try XCTUnwrap(alert.accessoryView as? NSTextField)
        XCTAssertTrue(label.stringValue.contains(version))
        XCTAssertTrue(label.stringValue.contains(current))
        XCTAssertEqual(label.preferredMaxLayoutWidth, 280)
        XCTAssertGreaterThan(label.frame.height, label.font?.pointSize ?? 0)
    }
}
