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
