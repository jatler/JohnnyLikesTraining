import Foundation

struct SessionSwap: Codable, Identifiable {
    let id: UUID
    let planId: UUID
    let sessionAId: UUID
    let sessionBId: UUID
    var reason: String?
    let swappedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case sessionAId = "session_a_id"
        case sessionBId = "session_b_id"
        case reason
        case swappedAt = "swapped_at"
    }
}
