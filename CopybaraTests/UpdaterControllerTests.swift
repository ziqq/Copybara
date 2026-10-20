// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import XCTest
@testable import Copybara

@MainActor
final class UpdaterControllerTests: XCTestCase {
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
