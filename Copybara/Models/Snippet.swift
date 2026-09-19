import Foundation

/// A user-authored reusable text template, always available in the popup.
struct Snippet: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var content: String

    init(id: UUID = UUID(), title: String = "", content: String = "") {
        self.id = id
        self.title = title
        self.content = content
    }
}
