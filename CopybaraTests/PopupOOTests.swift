import XCTest
@testable import Copybara

@MainActor
final class PopupOOTests: XCTestCase {
    private func makeOO(_ texts: [String]) -> PopupOO {
        let store = HistoryStore(stack: CoreDataStack(inMemory: true))
        for text in texts { store.insertTextSynchronously(text) }
        let settings = AppSettings(defaults: UserDefaults(suiteName: "oo-\(UUID().uuidString)")!)
        let oo = PopupOO(store: store, settings: settings)
        oo.reload()
        return oo
    }

    func testReloadOrdersNewestFirst() {
        let oo = makeOO(["a", "b", "c"])
        XCTAssertEqual(oo.results.map(\.preview), ["c", "b", "a"])
    }

    func testQueryFilters() {
        let oo = makeOO(["hello", "world", "help"])
        oo.query = "hel"
        XCTAssertEqual(Set(oo.results.map(\.preview)), ["hello", "help"])
    }

    func testMoveSelectionClamps() {
        let oo = makeOO(["a", "b"])
        oo.moveSelection(by: -1)
        XCTAssertEqual(oo.selectedIndex, 0)
        oo.moveSelection(by: 5)
        XCTAssertEqual(oo.selectedIndex, 1)
    }

    func testSelectFirstAndLast() {
        let oo = makeOO(["a", "b", "c"])
        oo.selectLast()
        XCTAssertEqual(oo.selectedIndex, 2)
        oo.selectFirst()
        XCTAssertEqual(oo.selectedIndex, 0)
    }

    func testItemAtNumber() {
        let oo = makeOO(["a", "b", "c"]) // results: c, b, a
        XCTAssertEqual(oo.item(atNumber: 1)?.preview, "c")
        XCTAssertEqual(oo.item(atNumber: 3)?.preview, "a")
        XCTAssertNil(oo.item(atNumber: 4))
    }

    func testTogglePinThenDeleteSelected() {
        let oo = makeOO(["a", "b"]) // results: b, a; selection at b
        oo.togglePinSelected()
        XCTAssertEqual(oo.results.first(where: { $0.preview == "b" })?.isPinned, true)
        oo.deleteSelected()
        XCTAssertFalse(oo.results.contains { $0.preview == "b" })
    }
}
