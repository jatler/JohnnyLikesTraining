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
    let heatSessions: [HeatSessionTemplate]?
    let stretchExercises: [StretchExerciseTemplate]?

    enum CodingKeys: String, CodingKey {
        case id, name, author, source, description
        case durationWeeks = "duration_weeks"
        case targetDistances = "target_distances"
        case sessions
        case heatSessions = "heat_sessions"
        case stretchExercises = "stretch_exercises"
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

struct StretchExerciseTemplate: Codable {
    let day: Int
    let stretchName: String
    let holdSeconds: Int
    let sets: Int
    let isBilateral: Bool
    let notes: String?
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case day, sets, notes
        case stretchName = "stretch_name"
        case holdSeconds = "hold_seconds"
        case isBilateral = "is_bilateral"
        case sortOrder = "sort_order"
    }
}
