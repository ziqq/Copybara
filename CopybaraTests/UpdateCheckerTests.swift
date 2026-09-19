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
}
