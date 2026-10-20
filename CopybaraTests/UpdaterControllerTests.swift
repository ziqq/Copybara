// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import Sparkle
import XCTest
@testable import Copybara

@MainActor
final class UpdaterControllerTests: XCTestCase {
    func testMissingHostVersionIsReportedOnEachDeferredManualCheck() throws {
        try withInvalidHost { host in
            try assertCachedStartupError(host: host, containing: "valid version")
        }
    }

    func testInvalidHostPublicKeyIsRejectedBeforeCheckingTheFeed() throws {
        try withInvalidHost(version: "1", publicKey: "invalid-public-key") { host in
            try assertCachedStartupError(host: host, containing: "EdDSA public key")
        }
    }

    func testReleasedFailedUpdaterDoesNotShowItsCachedErrorOrWritePreferences() throws {
        try withInvalidHost { host in
            let identifier = try XCTUnwrap(host.bundleIdentifier)
            let before = UserDefaults.standard.persistentDomain(forName: identifier) as NSDictionary?
            let visible = Set(NSApp.windows.filter(\.isVisible).map(\.windowNumber))
            var controller: UpdaterController? = UpdaterController(hostBundle: host)
            weak var released = controller
            controller?.checkForUpdates()
            controller?.checkForUpdates()

            controller = nil
            XCTAssertNil(released)
            let drained = expectation(description: "checks for the released failed updater are discarded")
            DispatchQueue.main.async { drained.fulfill() }
            wait(for: [drained], timeout: 2)

            XCTAssertEqual(Set(NSApp.windows.filter(\.isVisible).map(\.windowNumber)), visible)
            XCTAssertNil(NSApp.modalWindow)
            XCTAssertEqual(UserDefaults.standard.persistentDomain(forName: identifier) as NSDictionary?, before)
        }
    }

    private func withInvalidHost(version: String? = nil, publicKey: String? = nil,
                                  _ body: (Bundle) throws -> Void) throws {
        try IsolatedTestHost.require()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CopybaraInvalidHost-\(UUID())", isDirectory: true)
        let contents = root.appendingPathComponent("Fixture.app/Contents", isDirectory: true)
        let identifier = "dev.ustinoff.copybara.invalid-host.\(UUID().uuidString)"
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        defer {
            UserDefaults.standard.removePersistentDomain(forName: identifier)
            try? FileManager.default.removeItem(at: root)
        }
        var info: [String: Any] = [
            "CFBundleIdentifier": identifier, "CFBundleName": "Copybara Startup Failure Fixture",
            "CFBundlePackageType": "APPL", "SUEnableAutomaticChecks": false,
            "SUFeedURL": root.appendingPathComponent("never-read.xml").absoluteString,
            "SUPublicEDKey": try publicKey ?? XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)
        ]
        if let version { info["CFBundleVersion"] = version }
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        try body(XCTUnwrap(Bundle(url: contents.deletingLastPathComponent())))
    }

    private func assertCachedStartupError(host: Bundle, containing reason: String) throws {
        let controller = UpdaterController(hostBundle: host)
        let initialWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
        let sparkle = Bundle(for: SPUStandardUserDriver.self)
        let cancelTitle = sparkle.localizedString(forKey: "Cancel Update", value: nil, table: "Sparkle")
        let fixtureName = try XCTUnwrap(host.object(forInfoDictionaryKey: "CFBundleName") as? String)
        for _ in 0..<2 {
            var messages: [String] = []
            let deadline = Date().addingTimeInterval(3)
            let timer = Timer(timeInterval: 0.02, repeats: true) { timer in
                MainActor.assumeIsolated {
                    if let window = NSApp.modalWindow, !initialWindows.contains(ObjectIdentifier(window)),
                       let content = window.contentView {
                        window.alphaValue = 0
                        let views = self.descendants(of: content)
                        messages.append(views.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: "\n"))
                        let cancel = views.compactMap { $0 as? NSButton }.first { $0.title == cancelTitle }
                        XCTAssertNotNil(cancel, "a startup error must offer its native Cancel Update action")
                        timer.invalidate()
                        if let cancel { cancel.performClick(nil) } else { NSApp.abortModal() }
                    } else if Date() >= deadline {
                        timer.invalidate()
                        XCTFail("the cached startup error did not reach the native alert")
                        NSApp.abortModal()
                    }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            RunLoop.main.add(timer, forMode: .modalPanel)
            defer { timer.invalidate() }

            controller.checkForUpdates()
            XCTAssertTrue(messages.isEmpty, "the error must wait until the status menu finishes tracking")
            while messages.isEmpty && Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            }

            XCTAssertEqual(messages.count, 1)
            XCTAssertTrue(messages.first?.contains(reason) == true, "the actual Sparkle validation error must remain visible")
            XCTAssertTrue(messages.first?.contains(fixtureName) == true, "validation must use the supplied host bundle")
            XCTAssertNil(NSApp.modalWindow)
        }
        withExtendedLifetime(controller) {}
    }

    private func descendants(of view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants(of: $0) }
    }

    private final class NetworkTrap: URLProtocol {
        private static let lock = NSLock()
        private static var requests = 0

        static var requestCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return requests
        }

        static func reset() {
            lock.lock()
            defer { lock.unlock() }
            requests = 0
        }

        override class func canInit(with request: URLRequest) -> Bool {
            request.url?.scheme == "https" || request.url?.scheme == "http"
        }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            Self.lock.lock()
            Self.requests += 1
            Self.lock.unlock()
            client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
        }
        override func stopLoading() {}
    }

    func testRetainedUpdaterStartsOnlyOneDeferredCheckAndShowsUnsupportedFeedError() throws {
        try IsolatedTestHost.require()
        let defaults = UserDefaults.standard
        let bundleID = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let originalPreferences = defaults.persistentDomain(forName: bundleID)
        let originalArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        var arguments = originalArguments
        arguments["SUHasLaunchedBefore"] = true
        arguments["SUEnableAutomaticChecks"] = false
        arguments["SUAutomaticallyUpdate"] = false
        // Sparkle uses its own URLSession and rejects file feeds. This gives a
        // bounded failure without contacting the real feed or downloading an update.
        arguments["SUFeedURL"] = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-appcast-\(UUID()).xml").absoluteString
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        defer {
            if let originalPreferences { defaults.setPersistentDomain(originalPreferences, forName: bundleID) }
            else { defaults.removePersistentDomain(forName: bundleID) }
            defaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain)
        }
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        var errorWindows = 0
        let timer = Timer(timeInterval: 0.02, repeats: true) { _ in
            MainActor.assumeIsolated {
                guard let modal = NSApp.modalWindow, !existing.contains(ObjectIdentifier(modal)) else { return }
                modal.alphaValue = 0
                errorWindows += 1
                NSApp.abortModal()
                modal.close()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .modalPanel)
        defer {
            timer.invalidate()
            for window in NSApp.windows where !existing.contains(ObjectIdentifier(window)) { window.close() }
        }
        let updater = UpdaterController()
        updater.checkForUpdates()
        updater.checkForUpdates()
        XCTAssertEqual(errorWindows, 0, "menu tracking must finish before the check begins")
        let deadline = Date().addingTimeInterval(5)
        while errorWindows == 0 && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        withExtendedLifetime(updater) {
            XCTAssertEqual(errorWindows, 1, "the two queued checks must share one session and surface its failure once")
            XCTAssertNil(NSApp.modalWindow)
        }
    }

    func testReleasedUpdaterDiscardsQueuedChecksWithoutNetworkUIOrPreferenceWrites() async throws {
        let defaults = UserDefaults.standard
        let originalArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        let bundleID = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let originalPreferences = defaults.persistentDomain(forName: bundleID) as NSDictionary?
        var arguments = originalArguments
        // Sparkle must neither offer automatic checks nor record first launch
        // while this fixture exercises only the deferred controller lifetime.
        arguments["SUHasLaunchedBefore"] = true
        arguments["SUEnableAutomaticChecks"] = false
        arguments["SUAutomaticallyUpdate"] = false
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        defer { defaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain) }
        NetworkTrap.reset()
        XCTAssertTrue(URLProtocol.registerClass(NetworkTrap.self))
        defer { URLProtocol.unregisterClass(NetworkTrap.self) }
        let visibleWindows = Set(NSApp.windows.filter(\.isVisible).map(\.windowNumber))

        var updater: UpdaterController? = UpdaterController()
        weak var released: UpdaterController?
        released = updater
        updater?.checkForUpdates()
        updater?.checkForUpdates()
        updater = nil
        XCTAssertNil(released, "queued update checks must not retain their controller")
        let drained = expectation(description: "deferred update callbacks have run")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)

        XCTAssertEqual(NetworkTrap.requestCount, 0, "a released controller must not start a network session")
        XCTAssertEqual(Set(NSApp.windows.filter(\.isVisible).map(\.windowNumber)), visibleWindows,
                       "a stale update callback must not open a checking or error window")
        XCTAssertEqual(defaults.persistentDomain(forName: bundleID) as NSDictionary?, originalPreferences,
                       "constructing and releasing the updater must not change saved preferences")
    }
}
