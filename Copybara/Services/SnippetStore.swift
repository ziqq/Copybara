import Foundation

/// Persists user snippets as JSON in `UserDefaults` (snippets are few) and
/// exposes them to the popup as `ClipItemDO`s so they paste like any clip.
final class SnippetStore {
    static let shared = SnippetStore()

    private let defaults: UserDefaults
    private let key = "snippets"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func all() -> [Snippet] {
        guard let data = defaults.data(forKey: key),
              let snippets = try? JSONDecoder().decode([Snippet].self, from: data) else { return [] }
        return snippets
    }

    func save(_ snippets: [Snippet]) {
        if let data = try? JSONEncoder().encode(snippets) {
            defaults.set(data, forKey: key)
        }
    }

    func add(_ snippet: Snippet) {
        var snippets = all()
        snippets.append(snippet)
        save(snippets)
    }

    func delete(id: UUID) {
        save(all().filter { $0.id != id })
    }

    /// Non-empty snippets as clip items (display the title, paste the content).
    func asClipItems() -> [ClipItemDO] {
        all()
            .filter { !$0.content.isEmpty }
            .map { snippet in
                ClipItemDO(
                    id: snippet.id,
                    kind: .snippet,
                    preview: snippet.title.isEmpty ? snippet.content : snippet.title,
                    pasteText: snippet.content
                )
            }
    }
}
