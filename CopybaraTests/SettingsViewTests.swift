// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts
import SwiftUI
import XCTest
@testable import Copybara

@MainActor
final class SettingsViewTests: XCTestCase {
    func testSavedShortcutCanBeClearedInSettingsAndStaysDisabledWhenReopened() throws {
        for (shortcut, label) in [
            (KeyboardShortcuts.Shortcut(.v, modifiers: [.command, .shift]), "⇧⌘V"),
            (KeyboardShortcuts.Shortcut(.f20, modifiers: [.control, .option, .shift, .command]), "⌃⌥⇧⌘F20")
        ] {
            try withShortcutSettings(shortcut) { window, recorder in
                XCTAssertEqual(recorder.stringValue, label)
                XCTAssertEqual(KeyboardShortcuts.getShortcut(for: .togglePopup), shortcut)
                XCTAssertTrue(window.makeFirstResponder(recorder))
                let clear = try XCTUnwrap((recorder.cell as? NSSearchFieldCell)?.cancelButtonCell)

                clear.performClick(recorder)

                XCTAssertEqual(recorder.stringValue, "")
                XCTAssertNil(KeyboardShortcuts.getShortcut(for: .togglePopup), "clearing must persist the disabled shortcut")
                XCTAssertEqual(UserDefaults.standard.object(forKey: "KeyboardShortcuts_togglePopup") as? Bool, false)
                let reopened = NSHostingView(rootView: SettingsView())
                reopened.frame = NSRect(x: 0, y: 0, width: 480, height: 600)
                window.contentView = reopened
                reopened.layoutSubtreeIfNeeded()
                let reopenedRecorder = try XCTUnwrap(descendants(of: reopened).compactMap { $0 as? KeyboardShortcuts.RecorderCocoa }.first)
                XCTAssertEqual(reopenedRecorder.stringValue, "", "reopening must not reinstall the default shortcut")
                XCTAssertNil((reopenedRecorder.cell as? NSSearchFieldCell)?.cancelButtonCell)
            }
        }
    }

    func testSettingsRecorderRejectsNestedMenuConflictAndRetainsTheSavedShortcut() throws {
        let shortcut = KeyboardShortcuts.Shortcut(.v, modifiers: [.command, .shift])
        try withShortcutSettings(shortcut) { window, recorder in
            let originalMenu = NSApp.mainMenu
            defer { NSApp.mainMenu = originalMenu }
            let menu = NSMenu()
            let parent = NSMenuItem(title: "Recorder fixture", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            let command = NSMenuItem(title: "Fixture command", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "q")
            command.target = window
            command.keyEquivalentModifierMask = .command
            submenu.addItem(command)
            parent.submenu = submenu
            menu.addItem(parent)
            NSApp.mainMenu = menu
            XCTAssertTrue(window.makeFirstResponder(recorder))
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                                       timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                                       characters: "q", charactersIgnoringModifiers: "q", isARepeat: false, keyCode: 12))

            let message = captureShortcutConflict(for: event, in: window, expectedButtons: 1)

            XCTAssertTrue(message.contains(command.title), "the warning must identify the conflicting menu command")
            XCTAssertEqual(recorder.stringValue, "⇧⌘V")
            XCTAssertEqual(KeyboardShortcuts.getShortcut(for: .togglePopup), shortcut)
            XCTAssertNil(window.attachedSheet)
            XCTAssertNil(NSApp.modalWindow)
        }
    }

    func testDismissingSystemShortcutConflictDoesNotReplaceTheSavedShortcut() throws {
        try IsolatedTestHost.require()
        var rawShortcuts: Unmanaged<CFArray>?
        XCTAssertEqual(CopySymbolicHotKeys(&rawShortcuts), noErr)
        let system = try XCTUnwrap(rawShortcuts?.takeRetainedValue() as? [[String: Any]])
        let candidates = system.compactMap { entry -> KeyboardShortcuts.Shortcut? in
            guard entry[kHISymbolicHotKeyEnabled] as? Bool == true,
                  let key = entry[kHISymbolicHotKeyCode] as? Int,
                  let modifiers = entry[kHISymbolicHotKeyModifiers] as? Int,
                  (0...Int(UInt16.max)).contains(key), key != kVK_F12 else { return nil }
            let shortcut = KeyboardShortcuts.Shortcut(carbonKeyCode: key, carbonModifiers: modifiers)
            return shortcut.modifiers.intersection([.command, .control, .option]).isEmpty ? nil : shortcut
        }
        guard let reserved = candidates.first else {
            throw XCTSkip("This Mac has no enabled system shortcut with a command, control or option modifier")
        }
        let saved = KeyboardShortcuts.Shortcut(.v, modifiers: [.command, .shift])
        try withShortcutSettings(saved) { window, recorder in
            let originalMenu = NSApp.mainMenu
            NSApp.mainMenu = NSMenu()
            defer { NSApp.mainMenu = originalMenu }
            XCTAssertTrue(window.makeFirstResponder(recorder))
            // Deliver only to this test application's local event monitor. The
            // system never receives the reserved key, and nothing is registered.
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: reserved.modifiers,
                                                       timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                                       characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                                                       keyCode: UInt16(reserved.carbonKeyCode)))

            let message = captureShortcutConflict(for: event, in: window, expectedButtons: 2)

            XCTAssertFalse(message.isEmpty, "the system conflict must include a warning")
            XCTAssertEqual(recorder.stringValue, "⇧⌘V")
            XCTAssertEqual(KeyboardShortcuts.getShortcut(for: .togglePopup), saved,
                           "dismissing the warning must preserve the saved binding rather than force the reserved key")
            XCTAssertNotNil(recorder.currentEditor(), "recording must regain focus after dismissing the conflict")
        }
    }

    private func captureShortcutConflict(for event: NSEvent, in window: NSWindow, expectedButtons: Int) -> String {
        var messages: [String] = []
        let resources = Bundle.main.url(forResource: "KeyboardShortcuts_KeyboardShortcuts", withExtension: "bundle")
            .flatMap { Bundle(url: $0) }
        let dismissTitle = resources?.localizedString(forKey: "ok", value: nil, table: nil)
        if expectedButtons == 2 { XCTAssertNotNil(dismissTitle) }
        let deadline = Date().addingTimeInterval(3)
        let timer = Timer(timeInterval: 0.01, repeats: true) { timer in
            MainActor.assumeIsolated {
                if let sheet = window.attachedSheet, let content = sheet.contentView {
                    let views = self.descendants(of: content)
                    messages.append(views.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: "\n"))
                    let buttons = views.compactMap { $0 as? NSButton }
                    XCTAssertEqual(buttons.count, expectedButtons)
                    // The system warning's localized OK action dismisses it.
                    // Never press Use Anyway, which would register a system key.
                    let dismiss = expectedButtons == 1 ? buttons.first : buttons.first { $0.title == dismissTitle }
                    XCTAssertNotNil(dismiss)
                    timer.invalidate()
                    if let dismiss { dismiss.performClick(nil) }
                    else {
                        window.endSheet(sheet, returnCode: .cancel)
                        sheet.orderOut(nil)
                        NSApp.abortModal()
                    }
                } else if Date() >= deadline {
                    timer.invalidate()
                    XCTFail("the recorder did not show its shortcut-conflict alert")
                    NSApp.abortModal()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .modalPanel)
        defer { timer.invalidate() }

        NSApp.sendEvent(event)

        XCTAssertEqual(messages.count, 1)
        XCTAssertNil(window.attachedSheet)
        XCTAssertNil(NSApp.modalWindow)
        return messages.first ?? ""
    }

    private func withShortcutSettings(_ shortcut: KeyboardShortcuts.Shortcut,
                                      _ body: (NSWindow, KeyboardShortcuts.RecorderCocoa) throws -> Void) throws {
        try IsolatedTestHost.require()
        let defaults = UserDefaults.standard
        let key = "KeyboardShortcuts_togglePopup"
        let bundleID = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let originalValue = defaults.persistentDomain(forName: bundleID)?[key]
        let originalArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        var arguments = originalArguments
        arguments.removeValue(forKey: key)
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        defer {
            // Also release a binding if a future validation regression saves it.
            KeyboardShortcuts.setShortcut(nil, for: .togglePopup)
            if let originalValue { defaults.set(originalValue, forKey: key) }
            else { defaults.removeObject(forKey: key) }
            defaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain)
        }
        // Seed the serialized preference directly. Calling setShortcut here
        // would register a global key; displaying an existing value does not.
        defaults.set(String(decoding: try JSONEncoder().encode(shortcut), as: UTF8.self), forKey: key)

        let hosting = NSHostingView(rootView: SettingsView())
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 600)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer {
            window.makeFirstResponder(nil)
            window.contentView = nil
            window.close()
        }
        hosting.layoutSubtreeIfNeeded()
        let recorder = try XCTUnwrap(descendants(of: hosting).compactMap { $0 as? KeyboardShortcuts.RecorderCocoa }.first)
        try body(window, recorder)
    }

    func testSavedSnippetsRenderTheirEditableContentWithoutChangingPreferences() throws {
        let snippets = [Snippet(title: "Signature", content: "Best regards\nCopybara"),
                        Snippet(title: "Empty template", content: "")]
        let defaults = UserDefaults.standard
        let originalArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        let bundleID = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let originalPreferences = defaults.persistentDomain(forName: bundleID) as NSDictionary?
        var arguments = originalArguments
        arguments["snippets"] = try JSONEncoder().encode(snippets)
        arguments["blockedBundleIDs"] = ["com.apple.finder", "dev.copybara.missing-app"]
        // The recorder must not install its default global shortcut on a fresh
        // test host. The package treats this in-memory value as disabled.
        arguments["KeyboardShortcuts_togglePopup"] = false
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        defer { defaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain) }

        let hosting = NSHostingView(rootView: SettingsView())
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 600)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.contentView = hosting
        defer { window.close() }
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)

        var editors = descendants(of: hosting).compactMap { $0 as? NSTextView }
        for scroll in descendants(of: hosting).compactMap({ $0 as? NSScrollView }) {
            guard let document = scroll.documentView else { continue }
            for y in stride(from: CGFloat.zero, through: document.bounds.height, by: 200) {
                scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
                scroll.reflectScrolledClipView(scroll.contentView)
                hosting.layoutSubtreeIfNeeded()
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                editors.append(contentsOf: descendants(of: hosting).compactMap { $0 as? NSTextView })
            }
        }
        XCTAssertTrue(editors.contains { $0.string == snippets[0].content },
                      "the saved template content must appear in a native text editor")
        XCTAssertEqual(SnippetStore.shared.all(), snippets)
        XCTAssertEqual(defaults.persistentDomain(forName: bundleID) as NSDictionary?, originalPreferences,
                       "rendering the form must not change persisted preferences")
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
