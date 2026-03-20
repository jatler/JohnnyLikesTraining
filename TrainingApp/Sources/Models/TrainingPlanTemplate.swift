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

    enum CodingKeys: String, CodingKey {
        case id, name, author, source, description
        case durationWeeks = "duration_weeks"
        case targetDistances = "target_distances"
        case sessions
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
