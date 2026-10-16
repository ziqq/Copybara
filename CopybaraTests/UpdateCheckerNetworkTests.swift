// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import Foundation
import XCTest
@testable import Copybara

@MainActor
final class UpdateCheckerNetworkTests: XCTestCase {
    private final class StubProtocol: URLProtocol {
        enum Reply {
            case http(Int, Data)
            case nonHTTP
            case failure(URLError)
        }

        private static let lock = NSLock()
        private static var reply: Reply = .failure(URLError(.unknown))
        private static var capturedRequest: URLRequest?

        static func prepare(_ reply: Reply) {
            lock.lock()
            defer { lock.unlock() }
            self.reply = reply
            capturedRequest = nil
        }

        static var request: URLRequest? {
            lock.lock()
            defer { lock.unlock() }
            return capturedRequest
        }

        override class func canInit(with request: URLRequest) -> Bool {
            // Keep HTTP traffic local even if the production endpoint changes.
            request.url?.scheme == "https" || request.url?.scheme == "http"
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            Self.lock.lock()
            Self.capturedRequest = request
            let reply = Self.reply
            Self.lock.unlock()
            switch reply {
            case .failure(let error):
                client?.urlProtocol(self, didFailWithError: error)
            case .nonHTTP:
                let response = URLResponse(url: request.url!, mimeType: "application/json", expectedContentLength: 0, textEncodingName: nil)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocolDidFinishLoading(self)
            case .http(let status, let data):
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            }
        }

        override func stopLoading() {}
    }

    private func check(_ reply: StubProtocol.Reply) async -> UpdateChecker.Outcome {
        StubProtocol.prepare(reply)
        guard URLProtocol.registerClass(StubProtocol.self) else {
            XCTFail("Could not register the local HTTP fixture")
            return .failed("HTTP fixture unavailable")
        }
        defer { URLProtocol.unregisterClass(StubProtocol.self) }
        let outcome = await UpdateChecker.check()
        XCTAssertEqual(StubProtocol.request?.url?.absoluteString,
                       "https://api.github.com/repos/ziqq/Copybara/releases/latest")
        return outcome
    }

    func testNewReleaseIsAvailableAndRequestUsesGitHubHeaders() async throws {
        let data = Data("""
        {"tag_name":"v999.0.0","html_url":"https://example.com/release","assets":[
          {"name":"Copybara.dmg","browser_download_url":"https://example.com/Copybara.dmg"}
        ]}
        """.utf8)
        let outcome = await check(.http(200, data))
        XCTAssertEqual(outcome, .available(UpdateChecker.Release(version: "999.0.0",
            url: URL(string: "https://example.com/release")!, downloadURL: URL(string: "https://example.com/Copybara.dmg"))))
        let request = try XCTUnwrap(StubProtocol.request)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "Copybara")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testMissingReleaseIsUpToDateEvenWithNonJSONBody() async {
        let outcome = await check(.http(404, Data("not found".utf8)))
        XCTAssertEqual(outcome, .upToDate(current: UpdateChecker.current()))
    }

    func testCurrentAndOlderReleaseDoNotOfferDowngrade() async {
        for version in [UpdateChecker.current(), "0.0.0"] {
            let data = Data("{\"tag_name\":\"v\(version)\"}".utf8)
            let outcome = await check(.http(200, data))
            XCTAssertEqual(outcome, .upToDate(current: UpdateChecker.current()))
        }
    }

    func testNonnumericReleaseTagDoesNotOfferAnUpdate() async {
        let data = Data("{\"tag_name\":\"latest\"}".utf8)
        let outcome = await check(.http(200, data))
        XCTAssertEqual(outcome, .upToDate(current: UpdateChecker.current()))
    }

    func testHTTPFailuresReportStatusInsteadOfParsingReleaseBody() async {
        for status in [403, 429, 500] {
            let outcome = await check(.http(status, Data("{\"tag_name\":\"v999.0.0\"}".utf8)))
            XCTAssertEqual(outcome, .failed("HTTP \(status)"))
        }
    }

    func testMalformedSuccessfulResponseReportsUnreadableRelease() async {
        let outcome = await check(.http(200, Data("not JSON".utf8)))
        XCTAssertEqual(outcome, .failed(L10n.string("Couldn't read the release info")))
    }

    func testTransportFailureReportsLocalizedError() async {
        let error = URLError(.timedOut)
        let outcome = await check(.failure(error))
        XCTAssertEqual(outcome, .failed(error.localizedDescription))
    }

    func testNonHTTPResponseIsRejected() async {
        let outcome = await check(.nonHTTP)
        XCTAssertEqual(outcome, .failed("HTTP 0"))
    }
}
