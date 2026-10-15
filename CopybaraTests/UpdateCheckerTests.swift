// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import XCTest
@testable import Copybara

final class UpdateCheckerTests: XCTestCase {
    func testNormalizeStripsVPrefix() {
        XCTAssertEqual(UpdateChecker.normalize("v1.2.0"), "1.2.0")
        XCTAssertEqual(UpdateChecker.normalize("V2.0.0"), "2.0.0")
        XCTAssertEqual(UpdateChecker.normalize("1.0.0"), "1.0.0")
    }

    func testIsNewerComparesNumerically() {
        XCTAssertTrue(UpdateChecker.isNewer("1.10.0", than: "1.9.9"))
        XCTAssertTrue(UpdateChecker.isNewer("2.0.0", than: "1.9.9"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0.0", than: "1.0.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0.0", than: "1.0.1"))
    }

    func testParseReadsTagAndDMGAsset() {
        let json = Data("""
        {
          "tag_name": "v0.2.0",
          "html_url": "https://github.com/ziqq/Copybara/releases/tag/v0.2.0",
          "assets": [
            {"name": "Copybara-0.2.0.dmg", "browser_download_url": "https://example.com/Copybara-0.2.0.dmg"},
            {"name": "SHA256SUMS.txt", "browser_download_url": "https://example.com/SHA256SUMS.txt"}
          ]
        }
        """.utf8)

        let release = UpdateChecker.parse(json)
        XCTAssertEqual(release?.version, "0.2.0")
        XCTAssertEqual(release?.downloadURL?.absoluteString, "https://example.com/Copybara-0.2.0.dmg")
    }

    func testParseRejectsGarbage() {
        XCTAssertNil(UpdateChecker.parse(Data("not json".utf8)))
    }

    func testParseRequiresNonemptyStringTag() {
        for json in ["[]", "{}", "{\"tag_name\":null}", "{\"tag_name\":12}", "{\"tag_name\":\"\"}"] {
            XCTAssertNil(UpdateChecker.parse(Data(json.utf8)), json)
        }
    }

    func testMissingReleasePageAndAssetsUseSafeDefaults() throws {
        let release = try XCTUnwrap(UpdateChecker.parse(Data("{\"tag_name\":\"v1.2.3\"}".utf8)))
        XCTAssertEqual(release.version, "1.2.3")
        XCTAssertEqual(release.url, UpdateChecker.releasesPage)
        XCTAssertNil(release.downloadURL)
    }

    func testMalformedAssetsAreSkippedUntilFirstDownloadableDMG() throws {
        let data = Data("""
        {"tag_name":"v1.2.3","assets":[
          {"name":"notes.txt","browser_download_url":"https://example.com/notes.txt"},
          {"browser_download_url":"https://example.com/unnamed.dmg"},
          {"name":"missing-url.dmg"},
          {"name":"wrong-url-type.dmg","browser_download_url":123},
          {"name":"Copybara.dmg","browser_download_url":"https://example.com/first.dmg"},
          {"name":"Other.dmg","browser_download_url":"https://example.com/second.dmg"}
        ]}
        """.utf8)
        let release = try XCTUnwrap(UpdateChecker.parse(data))
        XCTAssertEqual(release.downloadURL?.absoluteString, "https://example.com/first.dmg")
    }

    func testMissingVersionComponentsAreComparedAsZeros() {
        XCTAssertFalse(UpdateChecker.isNewer("1.2", than: "1.2.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1.2.0", than: "1.2"))
        XCTAssertFalse(UpdateChecker.isNewer("1", than: "1.0.1"))
        XCTAssertTrue(UpdateChecker.isNewer("1.0.1", than: "1"))
    }
}
