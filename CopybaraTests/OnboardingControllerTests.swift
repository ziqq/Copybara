// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import SwiftUI
import XCTest
@testable import Copybara

@MainActor
final class OnboardingControllerTests: XCTestCase {
    private func withController(trusted: Bool, _ body: (OnboardingController, AppSettings) throws -> Void) throws {
        let name = "onboarding-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        let controller = OnboardingController(paster: Paster(accessibilityPermission: { trusted }), settings: settings)
        defer { controller.window?.close() }
        try body(controller, settings)
    }

    func testFirstLaunchShowsWelcomeEvenWhenPermissionIsAlreadyGranted() throws {
        try withController(trusted: true) { controller, settings in
            controller.showIfNeeded()
            let window = try XCTUnwrap(controller.window)
            window.alphaValue = 0
            XCTAssertTrue(window.isVisible)
            XCTAssertFalse(settings.hasCompletedOnboarding)
        }
    }

    func testFinishingWelcomePersistsCompletionAndClosesWindow() throws {
        try withController(trusted: true) { controller, settings in
            controller.showIfNeeded()
            let window = try XCTUnwrap(controller.window)
            window.alphaValue = 0
            let hosting = try XCTUnwrap(window.contentViewController as? NSHostingController<OnboardingView>)
            hosting.rootView.onFinish()
            XCTAssertTrue(settings.hasCompletedOnboarding)
            XCTAssertFalse(window.isVisible)
            controller.showIfNeeded()
            XCTAssertFalse(window.isVisible, "a trusted user who finished onboarding must not see it again")
        }
    }

    func testRepeatedShowReusesExistingWelcomeWindow() throws {
        try withController(trusted: false) { controller, _ in
            controller.show()
            let first = try XCTUnwrap(controller.window)
            first.alphaValue = 0
            controller.show()
            XCTAssertTrue(controller.window === first)
            XCTAssertTrue(first.isVisible)
        }
    }

    func testDismissingGuidanceWithoutPermissionDoesNotClaimPermissionWasGranted() throws {
        try withController(trusted: false) { controller, settings in
            controller.showIfNeeded()
            let window = try XCTUnwrap(controller.window)
            window.alphaValue = 0
            let hosting = try XCTUnwrap(window.contentViewController as? NSHostingController<OnboardingView>)
            hosting.rootView.onFinish()
            XCTAssertTrue(settings.hasCompletedOnboarding)
            controller.showIfNeeded()
            XCTAssertTrue(window.isVisible, "permission recovery is still required after dismissing onboarding")
        }
    }

    func testClosedWelcomeCallbacksDoNotRetainControllerOrChangeCompletion() throws {
        let name = "onboarding-lifetime-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        var controller: OnboardingController? = OnboardingController(
            paster: Paster(accessibilityPermission: { false }), settings: settings)
        weak var released: OnboardingController?
        released = controller
        controller?.show()
        let window = try XCTUnwrap(controller?.window)
        window.alphaValue = 0
        let hosting = try XCTUnwrap(window.contentViewController as? NSHostingController<OnboardingView>)
        let grant = hosting.rootView.onGrant
        let finish = hosting.rootView.onFinish
        window.close()
        controller = nil
        guard released == nil else {
            XCTFail("the closed welcome view's callbacks must not retain its controller")
            return
        }

        // Retained UI callbacks must be harmless after their owner is gone;
        // in particular Grant must not proceed to a system permission request.
        grant()
        finish()

        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertFalse(window.isVisible)
    }
}
