// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import SwiftUI
import XCTest
@testable import Copybara

@MainActor
final class OnboardingControllerTests: XCTestCase {
    func testRejectedGrantOpensRecoveryAndLaterGrantedPermissionStillRequiresExplicitFinish() throws {
        let name = "onboarding-recovery-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        var trusted = false, requests = 0, opened = 0
        let controller = OnboardingController(paster: Paster(accessibilityPermission: { trusted }), settings: settings,
            requestPermission: { requests += 1; return trusted }, openSettings: { opened += 1 })
        controller.showIfNeeded()
        let window = try XCTUnwrap(controller.window)
        window.alphaValue = 0
        defer { window.close() }
        let view = try XCTUnwrap(window.contentViewController as? NSHostingController<OnboardingView>).rootView

        view.onGrant()
        view.onGrant()
        XCTAssertEqual(requests, 2)
        XCTAssertEqual(opened, 2, "each rejected grant must provide the recovery path")
        XCTAssertTrue(window.isVisible)
        XCTAssertFalse(settings.hasCompletedOnboarding)

        trusted = true
        view.onGrant()
        XCTAssertEqual(requests, 3)
        XCTAssertEqual(opened, 2, "granted permission must not reopen System Settings")
        XCTAssertTrue(window.isVisible)
        XCTAssertFalse(settings.hasCompletedOnboarding)
        view.onFinish()
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertFalse(window.isVisible)
        controller.showIfNeeded()
        XCTAssertFalse(window.isVisible)
    }

    func testManualSettingsActionDoesNotRequestPermissionOrCompleteOnboarding() throws {
        let name = "onboarding-manual-settings-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        var requests = 0, opened = 0
        let controller = OnboardingController(paster: Paster(accessibilityPermission: { false }), settings: settings,
            requestPermission: { requests += 1; return false }, openSettings: { opened += 1 })
        controller.show()
        let window = try XCTUnwrap(controller.window)
        window.alphaValue = 0
        defer { window.close() }
        let view = try XCTUnwrap(window.contentViewController as? NSHostingController<OnboardingView>).rootView

        view.onOpenSettings()

        XCTAssertEqual(opened, 1)
        XCTAssertEqual(requests, 0)
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertTrue(window.isVisible)
    }

    func testInjectedCallbacksKeepControllerLifetimeAndStaleGrantHarmless() throws {
        let name = "onboarding-injected-lifetime-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        var requests = 0, opened = 0
        var controller: OnboardingController? = OnboardingController(
            paster: Paster(accessibilityPermission: { false }), settings: settings,
            requestPermission: { requests += 1; return false }, openSettings: { opened += 1 })
        weak var released = controller
        controller?.show()
        let window = try XCTUnwrap(controller?.window)
        window.alphaValue = 0
        let view = try XCTUnwrap(window.contentViewController as? NSHostingController<OnboardingView>).rootView
        window.close()
        controller = nil
        XCTAssertNil(released)

        view.onGrant()
        view.onFinish()
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(opened, 0)
        XCTAssertFalse(settings.hasCompletedOnboarding)
        // The independent Settings action must not capture the closed controller.
        view.onOpenSettings()
        XCTAssertEqual(opened, 1)
        XCTAssertFalse(window.isVisible)
    }

    func testAccessibilityRecoveryOpensTheCorrectPaneEvenWhenWorkspaceRejectsIt() {
        for accepted in [true, false] {
            var urls: [URL] = []

            OnboardingController.openAccessibilitySettings { url in urls.append(url); return accepted }

            XCTAssertEqual(urls.count, 1)
            XCTAssertEqual(urls.first?.scheme, "x-apple.systempreferences")
            // Foundation versions split opaque URL components differently;
            // System Settings receives the complete URL in either case.
            XCTAssertEqual(urls.first?.absoluteString,
                           "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        }
    }

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

    func testGrantWithExistingPermissionKeepsWelcomeOpenUntilExplicitFinish() throws {
        let name = "onboarding-already-trusted-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        var permissionReads = 0
        let controller = OnboardingController(paster: Paster(accessibilityPermission: {
            permissionReads += 1
            return true
        }), settings: settings, requestPermission: {
            permissionReads += 1
            return true
        })
        controller.show()
        let window = try XCTUnwrap(controller.window)
        window.alphaValue = 0
        defer { window.close() }
        let hosting = try XCTUnwrap(window.contentViewController as? NSHostingController<OnboardingView>)
        let readsBeforeGrant = permissionReads

        hosting.rootView.onGrant()

        XCTAssertEqual(permissionReads, readsBeforeGrant + 1)
        XCTAssertTrue(window.isVisible)
        XCTAssertFalse(settings.hasCompletedOnboarding, "granting permission must not replace the explicit finish action")
        hosting.rootView.onFinish()
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertFalse(window.isVisible)
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
