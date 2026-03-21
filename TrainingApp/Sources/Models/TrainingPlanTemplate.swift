import Foundation

struct TrainingPlanTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let author: String
    let source: String
    let description: String
    let durationWeeks: Int
    let targetDistances: [String]
    let sessions: [SessionTemplate]
    let strengthExercises: [StrengthExerciseTemplate]?
    let heatSessions: [HeatSessionTemplate]?

    enum CodingKeys: String, CodingKey {
        case id, name, author, source, description
        case durationWeeks = "duration_weeks"
        case targetDistances = "target_distances"
        case sessions
        case strengthExercises = "strength_exercises"
        case heatSessions = "heat_sessions"
    }
}

struct SessionTemplate: Codable {
    let week: Int
    let day: Int
    let workoutType: WorkoutType
    let targetDistanceKm: Double?
    let paceDescription: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case week, day, notes
        case workoutType = "workout_type"
        case targetDistanceKm = "target_distance_km"
        case paceDescription = "pace_description"
    }
}

struct StrengthExerciseTemplate: Codable {
    let day: Int
    let exerciseName: String
    let targetSets: Int
    let targetReps: Int
    let targetWeightKg: Double?
    let isBodyweight: Bool
    let targetRpe: Double?
    let notes: String?
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case day, notes
        case exerciseName = "exercise_name"
        case targetSets = "target_sets"
        case targetReps = "target_reps"
        case targetWeightKg = "target_weight_kg"
        case isBodyweight = "is_bodyweight"
        case targetRpe = "target_rpe"
        case sortOrder = "sort_order"
    }
}

struct HeatSessionTemplate: Codable {
    let day: Int
    let sessionType: String
    let targetDurationMinutes: Int
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case day, notes
        case sessionType = "session_type"
        case targetDurationMinutes = "target_duration_minutes"
    }
}
