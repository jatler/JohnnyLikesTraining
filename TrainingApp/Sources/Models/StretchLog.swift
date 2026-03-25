import Foundation

struct StretchLog: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    let completedAt: Date
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case completedAt = "completed_at"
        case notes
    }
}
