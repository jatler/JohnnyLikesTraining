import Foundation

struct StrengthTemplate: Codable, Identifiable {
    let id: UUID
    let planId: UUID
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct StrengthTemplateExercise: Codable, Identifiable {
    let id: UUID
    var templateId: UUID
    var dayOfWeek: Int
    var exerciseName: String
    var targetSets: Int
    var targetReps: Int
    var targetWeightKg: Double?
    var targetRpe: Double?
    var isBodyweight: Bool
    var isTimed: Bool
    var sortOrder: Int
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case dayOfWeek = "day_of_week"
        case exerciseName = "exercise_name"
        case targetSets = "target_sets"
        case targetReps = "target_reps"
        case targetWeightKg = "target_weight_kg"
        case targetRpe = "target_rpe"
        case isBodyweight = "is_bodyweight"
        case isTimed = "is_timed"
        case sortOrder = "sort_order"
        case notes
    }

    var targetWeightLbs: Double? {
        targetWeightKg.map { $0 * 2.205 }
    }
}
