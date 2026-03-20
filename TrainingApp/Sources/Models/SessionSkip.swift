import Foundation

struct SessionSkip: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    var reason: String?
    let skippedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case reason
        case skippedAt = "skipped_at"
    }
}
