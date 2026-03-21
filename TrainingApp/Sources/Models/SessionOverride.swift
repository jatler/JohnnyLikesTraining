import Foundation

struct SessionOverride: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID
    var originalWorkoutType: WorkoutType?
    var originalTargetDistanceKm: Double?
    var originalTargetPaceDescription: String?
    var originalNotes: String?
    var overrideReason: String?
    let overriddenAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case originalWorkoutType = "original_workout_type"
        case originalTargetDistanceKm = "original_target_distance_km"
        case originalTargetPaceDescription = "original_target_pace_description"
        case originalNotes = "original_notes"
        case overrideReason = "override_reason"
        case overriddenAt = "overridden_at"
    }
}
