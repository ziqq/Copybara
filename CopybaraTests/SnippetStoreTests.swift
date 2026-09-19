import XCTest
@testable import Copybara

final class SnippetStoreTests: XCTestCase {
    private func makeStore() -> SnippetStore {
        SnippetStore(defaults: UserDefaults(suiteName: "snip-\(UUID().uuidString)")!)
    }

    func testAddSaveAndLoad() {
        let store = makeStore()
        XCTAssertTrue(store.all().isEmpty)
        store.add(Snippet(title: "Sig", content: "Best regards"))
        XCTAssertEqual(store.all().map(\.title), ["Sig"])
    }

    func testDelete() {
        let store = makeStore()
        let snippet = Snippet(title: "A", content: "a")
        store.add(snippet)
        store.add(Snippet(title: "B", content: "b"))
        store.delete(id: snippet.id)
        XCTAssertEqual(store.all().map(\.title), ["B"])
    }

    func testAsClipItemsDisplaysTitleAndPastesContent() {
        let store = makeStore()
        store.add(Snippet(title: "Email", content: "me@example.com"))
        store.add(Snippet(title: "", content: "no title"))
        store.add(Snippet(title: "Empty", content: "")) // dropped

        let items = store.asClipItems()
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.map(\.kind), [.snippet, .snippet])
        XCTAssertEqual(items[0].preview, "Email")
        XCTAssertEqual(items[0].textToPaste, "me@example.com")
        XCTAssertEqual(items[1].preview, "no title") // falls back to content
    }
}
