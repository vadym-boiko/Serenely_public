import Foundation

enum TaskStatus: String, Codable { case pending, done, skipped, notSet }
enum TaskUsefulness: String, Codable { case notSet, low, medium, high }

struct ActionTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var details: String?
    var createdAt: Date
    var status: TaskStatus
    var usefulness: TaskUsefulness

    init(id: UUID = UUID(),
         title: String,
         details: String? = nil,
         createdAt: Date = .now,
         status: TaskStatus = .notSet,
         usefulness: TaskUsefulness = .notSet) {
        self.id = id; self.title = title; self.details = details
        self.createdAt = createdAt; self.status = status; self.usefulness = usefulness
    }
}
