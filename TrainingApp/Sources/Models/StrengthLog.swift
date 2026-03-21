import Foundation

struct StrengthLog: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    var setNumber: Int
    var actualReps: Int
    var actualWeightKg: Double?
    var rpe: Double?
    let completedAt: Date
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case setNumber = "set_number"
        case actualReps = "actual_reps"
        case actualWeightKg = "actual_weight_kg"
        case rpe
        case completedAt = "completed_at"
        case notes
    }

    var actualWeightLbs: Double? {
        actualWeightKg.map { $0 * 2.205 }
    }
}
