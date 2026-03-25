import Foundation

struct StrengthSession: Codable, Identifiable {
    let id: UUID
    let planId: UUID
    var templateExerciseId: UUID?
    var scheduledDate: Date
    var weekNumber: Int
    var dayOfWeek: Int
    var exerciseName: String
    var prescribedSets: Int
    var prescribedReps: Int
    var prescribedWeightKg: Double?
    var prescribedRpe: Double?
    var isTimed: Bool
    var isDeload: Bool
    var isTemplateOverride: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case templateExerciseId = "template_exercise_id"
        case scheduledDate = "scheduled_date"
        case weekNumber = "week_number"
        case dayOfWeek = "day_of_week"
        case exerciseName = "exercise_name"
        case prescribedSets = "prescribed_sets"
        case prescribedReps = "prescribed_reps"
        case prescribedWeightKg = "prescribed_weight_kg"
        case prescribedRpe = "prescribed_rpe"
        case isTimed = "is_timed"
        case isDeload = "is_deload"
        case isTemplateOverride = "is_template_override"
    }

    var prescribedWeightLbs: Double? {
        prescribedWeightKg.map { $0 * 2.205 }
    }
}
