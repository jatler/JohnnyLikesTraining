import Foundation

struct TrainingPlan: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var name: String
    var raceDate: Date
    var planStartDate: Date
    var sourceFileName: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case raceDate = "race_date"
        case planStartDate = "plan_start_date"
        case sourceFileName = "source_file_name"
        case createdAt = "created_at"
    }
}
