import SwiftData
import Foundation

@Model final class Conversation {
    var title: String
    var mode: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var messages: [PersistedMessage] = []

    init(title: String, mode: String) {
        self.title = title
        self.mode = mode
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model final class PersistedMessage {
    var role: String   // "user" | "assistant"
    var content: String
    var timestamp: Date

    init(role: String, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}
