// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import XCTest
@testable import Copybara

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testSettingsWindowOpensAndCanReopenAfterClose() throws {
        let controller = SettingsWindowController()
        controller.show()
        let window = try XCTUnwrap(controller.window)
        defer { window.close() }
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(window.title, L10n.string("Copybara Settings"))
        XCTAssertEqual(window.contentView?.frame.size, NSSize(width: 480, height: 600))
        window.close()
        XCTAssertFalse(window.isVisible)
        controller.show()
        XCTAssertTrue(controller.window === window)
        XCTAssertTrue(window.isVisible)
    }
}
