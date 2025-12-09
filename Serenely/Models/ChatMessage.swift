import Foundation

enum Sender: String, Codable { case user, assistant, system }

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let sender: Sender
    var text: String
    var timestamp: Date

    init(id: UUID = UUID(), sender: Sender, text: String, timestamp: Date = .now) {
        self.id = id; self.sender = sender; self.text = text; self.timestamp = timestamp
    }
}
