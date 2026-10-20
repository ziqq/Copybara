// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import Darwin
import Sparkle
import XCTest
@testable import Copybara

@MainActor
final class UpdaterFeedIntegrationTests: XCTestCase {
    private final class LocalFeedServer {
        private let descriptor: Int32
        private let lock = NSLock()
        private var feed = Data()
        private var paths: [String] = []
        private var stopped = false
        let url: URL

        init() throws {
            let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
            descriptor = socketDescriptor
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_addr.s_addr = inet_addr("127.0.0.1")
            let bound = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(socketDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let named = withUnsafeMutablePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(socketDescriptor, $0, &length) }
            }
            guard descriptor >= 0, bound == 0, named == 0, listen(descriptor, 4) == 0 else {
                Darwin.close(descriptor)
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
            url = URL(string: "http://127.0.0.1:\(UInt16(bigEndian: address.sin_port))/appcast.xml")!
            DispatchQueue.global().async { [self] in
                while true {
                    let client = accept(descriptor, nil, nil)
                    guard client >= 0 else { return }
                    lock.lock()
                    let isStopped = stopped
                    lock.unlock()
                    if isStopped { Darwin.close(client); return }
                    serve(client)
                }
            }
        }

        func setFeed(_ data: Data) {
            lock.lock()
            defer { lock.unlock() }
            feed = data
        }

        var requestPaths: [String] {
            lock.lock()
            defer { lock.unlock() }
            return paths
        }

        func stop() {
            lock.lock()
            stopped = true
            lock.unlock()
            shutdown(descriptor, SHUT_RDWR)
            Darwin.close(descriptor)
        }

        private func serve(_ client: Int32) {
            defer { Darwin.close(client) }
            var timeout = timeval(tv_sec: 3, tv_usec: 0)
            setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            var noSignal: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
            var bytes = [UInt8](repeating: 0, count: 4096)
            let count = recv(client, &bytes, bytes.count, 0)
            guard count > 0 else { return }
            let path = String(decoding: bytes.prefix(count), as: UTF8.self).split(separator: " ").dropFirst().first.map(String.init) ?? ""
            lock.lock()
            paths.append(path)
            let body = path == "/appcast.xml" ? feed : Data()
            lock.unlock()
            let status = path == "/appcast.xml" ? "200 OK" : "404 Not Found"
            var response = Data("HTTP/1.1 \(status)\r\nContent-Type: application/xml\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
            response.append(body)
            response.withUnsafeBytes { buffer in
                var sent = 0
                while sent < buffer.count {
                    let count = send(client, buffer.baseAddress!.advanced(by: sent), buffer.count - sent, 0)
                    guard count > 0 else { return }
                    sent += count
                }
            }
        }
    }

    func testSimpleFeedUsesCompactPromptAndSkippingFinishesWithoutDownloading() throws {
        try withFeed(releaseNotes: nil) { host in
            var versions: [String] = []
            let driver = CompactUpdateUserDriver(hostBundle: host) { alert in
                versions.append((alert.accessoryView as? NSTextField)?.stringValue ?? "")
                alert.window.close()
                return .alertSecondButtonReturn
            }
            let updater = SPUUpdater(hostBundle: host, applicationBundle: host, userDriver: driver, delegate: nil)
            try updater.start()
            updater.checkForUpdates()
            let presentation = finishSession(updater)

            XCTAssertFalse(updater.sessionInProgress)
            XCTAssertEqual(versions, [L10n.format("Copybara %@ is available — you have %@.", "42.0", UpdateChecker.current())])
            XCTAssertEqual(presentation.errors, 0)
            XCTAssertEqual(presentation.standardPrompts, 0)
            XCTAssertEqual(UserDefaults(suiteName: try XCTUnwrap(host.bundleIdentifier))?.string(forKey: "SUSkippedVersion"), "999")
        }
    }

    func testFeedWithReleaseNotesKeepsStandardSparklePromptAndCanBeDismissed() throws {
        try withFeed(releaseNotes: "<p>Changes that must remain visible to the user.</p>") { host in
            var compactPrompts = 0
            let driver = CompactUpdateUserDriver(hostBundle: host) { _ in
                compactPrompts += 1
                return .alertSecondButtonReturn
            }
            let updater = SPUUpdater(hostBundle: host, applicationBundle: host, userDriver: driver, delegate: nil)
            try updater.start()
            updater.checkForUpdates()
            let presentation = finishSession(updater)

            XCTAssertFalse(updater.sessionInProgress)
            XCTAssertEqual(compactPrompts, 0, "release notes must not be discarded by the compact prompt")
            XCTAssertEqual(presentation.errors, 0)
            XCTAssertEqual(presentation.standardPrompts, 1)
            XCTAssertNil(UserDefaults(suiteName: try XCTUnwrap(host.bundleIdentifier))?.object(forKey: "SUSkippedVersion"),
                         "closing the standard prompt must dismiss rather than skip the release")
        }
    }

    private func withFeed(releaseNotes: String?, _ body: (Bundle) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CopybaraFeed-\(UUID())", isDirectory: true)
        let contents = root.appendingPathComponent("Fixture.app/Contents", isDirectory: true)
        let identifier = "dev.ustinoff.copybara.feed-fixture.\(UUID().uuidString)"
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        defer {
            UserDefaults.standard.removePersistentDomain(forName: identifier)
            try? FileManager.default.removeItem(at: root)
        }
        let server = try LocalFeedServer()
        defer { server.stop() }
        let notes = releaseNotes.map { "<description><![CDATA[\($0)]]></description>" } ?? ""
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel><title>Local Copybara test feed</title><item>
            <title>Copybara 42.0</title>
            <sparkle:version>999</sparkle:version>
            <sparkle:shortVersionString>42.0</sparkle:shortVersionString>
            \(notes)
            <enclosure url="\(server.url.deletingLastPathComponent().appendingPathComponent("never-download.zip").absoluteString)" length="128" type="application/octet-stream"/>
          </item></channel>
        </rss>
        """
        server.setFeed(Data(xml.utf8))
        // This bundle exists only for the local unsigned XML fixture. The real
        // application's signed-feed and archive verification remain untouched.
        let info: [String: Any] = [
            "CFBundleIdentifier": identifier, "CFBundleName": "Copybara Feed Fixture",
            "CFBundleVersion": "1", "CFBundleShortVersionString": "1.0", "CFBundlePackageType": "APPL",
            "SUFeedURL": server.url.absoluteString, "SUEnableAutomaticChecks": false,
            "SUPublicEDKey": try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey"))
        ]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        let host = try XCTUnwrap(Bundle(url: contents.deletingLastPathComponent()))
        try body(host)
        XCTAssertEqual(server.requestPaths, ["/appcast.xml"], "skipping or dismissing must never download an archive")
    }

    private func finishSession(_ updater: SPUUpdater) -> (errors: Int, standardPrompts: Int) {
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        let sparkle = Bundle(for: SPUStandardUserDriver.self)
        let skip = sparkle.localizedString(forKey: "Skip This Version", value: nil, table: "Sparkle")
        var errors = 0
        var standardPrompts = 0
        let timer = Timer(timeInterval: 0.02, repeats: true) { _ in
            MainActor.assumeIsolated {
                for window in NSApp.windows where !existing.contains(ObjectIdentifier(window)) {
                    window.alphaValue = 0
                    if window === NSApp.modalWindow {
                        errors += 1
                        NSApp.abortModal()
                        window.close()
                    } else if window.isVisible, Self.buttons(in: window.contentView).contains(where: { $0.title == skip }) {
                        standardPrompts += 1
                        window.performClose(nil)
                    }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .modalPanel)
        defer {
            timer.invalidate()
            for window in NSApp.windows where !existing.contains(ObjectIdentifier(window)) { window.close() }
        }
        let deadline = Date().addingTimeInterval(5)
        while updater.sessionInProgress && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return (errors, standardPrompts)
    }

    private static func buttons(in view: NSView?) -> [NSButton] {
        guard let view else { return [] }
        return (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { buttons(in: $0) }
    }
}
