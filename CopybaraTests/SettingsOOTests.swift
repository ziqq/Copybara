import XCTest
@testable import Copybara

@MainActor
final class SettingsOOTests: XCTestCase {
    private func make() -> (SettingsOO, AppSettings) {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "soo-\(UUID().uuidString)")!)
        return (SettingsOO(settings: settings), settings)
    }

    func testWritesThroughToSettings() {
        let (oo, settings) = make()
        oo.historySize = 42
        oo.historyRetentionDays = 7
        oo.searchMode = .exact
        oo.sortMode = .firstCopied
        oo.popupPosition = .center
        oo.useLiquidGlass = false
        oo.ignoreAllCopies = true
        oo.blockedBundleIDs = ["com.z"]

        XCTAssertEqual(settings.historySize, 42)
        XCTAssertEqual(settings.historyRetentionDays, 7)
        XCTAssertEqual(settings.searchMode, .exact)
        XCTAssertEqual(settings.sortMode, .firstCopied)
        XCTAssertEqual(settings.popupPosition, .center)
        XCTAssertFalse(settings.useLiquidGlass)
        XCTAssertTrue(settings.ignoreAllCopies)
        XCTAssertEqual(settings.blockedBundleIDs, ["com.z"])
    }

    func testIconVisibilityPostsNotification() {
        let (oo, _) = make()
        let expectation = expectation(forNotification: .copybaraIconVisibilityChanged, object: nil)
        oo.iconVisibility = .dock
        wait(for: [expectation], timeout: 1)
    }
}
