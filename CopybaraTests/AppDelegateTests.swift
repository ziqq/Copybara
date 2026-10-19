// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import XCTest
@testable import Copybara

@MainActor
final class AppDelegateTests: XCTestCase {
    func testIconVisibilityNotificationAppliesDockPolicyAndCanReturnToMenuBarOnly() throws {
        let delegate = AppDelegate()
        let originalPolicy = NSApp.activationPolicy()
        defer { NSApp.setActivationPolicy(originalPolicy) }
        let selector = NSSelectorFromString("iconVisibilityChanged:")
        let bundleID = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let originalPreferences = UserDefaults.standard.persistentDomain(forName: bundleID) as NSDictionary?

        // Dispatch just the observer's real Objective-C entry point. Launching
        // the services would use the user's history and global shortcut.
        for (value, policy) in [(IconVisibility.menuBar, NSApplication.ActivationPolicy.accessory),
                                (.dock, .regular), (.both, .regular), (.menuBar, .accessory)] {
            let note = Notification(name: .copybaraIconVisibilityChanged, object: nil,
                                    userInfo: ["value": value.rawValue])
            XCTAssertTrue(NSApp.sendAction(selector, to: delegate, from: note as NSNotification))
            XCTAssertEqual(NSApp.activationPolicy(), policy,
                           "changing icon visibility must apply the corresponding Dock policy immediately")
        }

        XCTAssertEqual(UserDefaults.standard.persistentDomain(forName: bundleID) as NSDictionary?, originalPreferences,
                       "applying a visibility notification must not rewrite the user's preferences")
    }

    func testMalformedIconVisibilityNotificationsPreserveCurrentApplicationPolicy() {
        let delegate = AppDelegate()
        let originalPolicy = NSApp.activationPolicy()
        defer { NSApp.setActivationPolicy(originalPolicy) }
        let selector = NSSelectorFromString("iconVisibilityChanged:")

        for policy in [NSApplication.ActivationPolicy.accessory, .regular] {
            XCTAssertTrue(NSApp.setActivationPolicy(policy))
            for payload: [AnyHashable: Any]? in [nil, [:], ["value": 42], ["value": "unknown"]] {
                let note = Notification(name: .copybaraIconVisibilityChanged, object: nil, userInfo: payload)
                XCTAssertTrue(NSApp.sendAction(selector, to: delegate, from: note as NSNotification))
                XCTAssertEqual(NSApp.activationPolicy(), policy,
                               "an absent, mistyped or unknown visibility must not change the Dock policy")
            }
        }
    }
}
