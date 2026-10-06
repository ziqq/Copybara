// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import XCTest
@testable import Copybara

@MainActor
final class WindowRecoveryTests: XCTestCase {
    func testPopupUnhidesApplicationAfterFailedPasteHandoff() {
        let suite = UserDefaults(suiteName: "window-recovery-\(UUID())")!
        let board = NSPasteboard(name: .init("window-recovery-\(UUID())"))
        defer { board.releaseGlobally(); NSApp.unhideWithoutActivation() }
        let popup = PopupController(store: HistoryStore(stack: CoreDataStack(inMemory: true)),
                                    paster: Paster(pasteboard: board), settings: AppSettings(defaults: suite),
                                    snippets: SnippetStore(defaults: suite))
        defer { popup.hide() }
        NSApp.hide(nil)
        XCTAssertTrue(NSApp.isHidden, "simulate the failed activation fallback used by paste")
        popup.show()
        XCTAssertFalse(NSApp.isHidden)
        XCTAssertTrue(popup.isVisible)
    }

    func testSettingsMenuCallbackRestoresHiddenApplicationAndWindow() async throws {
        let store = HistoryStore(stack: CoreDataStack(inMemory: true))
        let menu = StatusItemController(store: store)
        let settings = SettingsWindowController()
        let opened = expectation(description: "settings menu action completed")
        menu.onOpenSettings = { settings.show(); opened.fulfill() }
        defer { settings.window?.close(); NSApp.unhideWithoutActivation() }
        NSApp.hide(nil)
        XCTAssertTrue(NSApp.isHidden)
        let item = try XCTUnwrap(menu.buildMenu().items.first { $0.title == L10n.string("Settings…") })
        menu.perform(try XCTUnwrap(item.action))
        await fulfillment(of: [opened], timeout: 3)
        XCTAssertFalse(NSApp.isHidden)
        XCTAssertTrue(try XCTUnwrap(settings.window).isVisible)
    }

    func testToggleReopensHiddenPopupOnFirstClick() {
        let suite = UserDefaults(suiteName: "window-recovery-\(UUID())")!
        let board = NSPasteboard(name: .init("window-recovery-\(UUID())"))
        defer { board.releaseGlobally(); NSApp.unhideWithoutActivation() }
        let popup = PopupController(store: HistoryStore(stack: CoreDataStack(inMemory: true)),
                                    paster: Paster(pasteboard: board), settings: AppSettings(defaults: suite),
                                    snippets: SnippetStore(defaults: suite))
        defer { popup.hide() }
        popup.show()
        NSApp.hide(nil)
        XCTAssertTrue(NSApp.isHidden)
        popup.toggle()
        XCTAssertFalse(NSApp.isHidden)
        XCTAssertTrue(popup.isVisible)
    }

    func testLostPermissionShowsGuidanceEvenAfterCompletedOnboarding() throws {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "permission-recovery-\(UUID())")!)
        settings.hasCompletedOnboarding = true
        let controller = OnboardingController(paster: Paster(accessibilityPermission: { false }), settings: settings)
        defer { controller.window?.close() }
        controller.showIfNeeded()
        XCTAssertTrue(try XCTUnwrap(controller.window).isVisible)
        XCTAssertTrue(settings.hasCompletedOnboarding, "recovering permission must not reset user preferences")
    }

    func testTrustedReturningUserIsNotInterrupted() {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "permission-recovery-\(UUID())")!)
        settings.hasCompletedOnboarding = true
        let controller = OnboardingController(paster: Paster(accessibilityPermission: { true }), settings: settings)
        controller.showIfNeeded()
        XCTAssertNil(controller.window)
    }
}
