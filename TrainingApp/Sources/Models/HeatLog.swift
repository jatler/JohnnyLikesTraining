import Foundation

struct HeatLog: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    var actualDurationMinutes: Int
    var sessionType: HeatType
    let completedAt: Date
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case actualDurationMinutes = "actual_duration_minutes"
        case sessionType = "session_type"
        case completedAt = "completed_at"
        case notes
    }
}
