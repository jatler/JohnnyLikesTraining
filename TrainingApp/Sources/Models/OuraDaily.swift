import Foundation

struct OuraDaily: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var date: Date
    var readinessScore: Int?
    var sleepScore: Int?
    var hrvAverage: Double?
    var restingHr: Int?
    var temperatureDeviation: Double?
    let syncedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case readinessScore = "readiness_score"
        case sleepScore = "sleep_score"
        case hrvAverage = "hrv_average"
        case restingHr = "resting_hr"
        case temperatureDeviation = "temperature_deviation"
        case syncedAt = "synced_at"
    }

    var readinessLevel: ReadinessLevel {
        guard let score = readinessScore else { return .unknown }
        switch score {
        case 80...100: return .good
        case 60..<80: return .moderate
        default: return .low
        }
    }
}

enum ReadinessLevel {
    case good, moderate, low, unknown

    var label: String {
        switch self {
        case .good: "Good"
        case .moderate: "Fair"
        case .low: "Low"
        case .unknown: "—"
        }
    }

    var systemColor: String {
        switch self {
        case .good: "green"
        case .moderate: "yellow"
        case .low: "red"
        case .unknown: "gray"
        }
    }
}
