import Foundation

struct StravaActivity: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let stravaId: Int64
    var activityDate: Date
    var name: String
    var distanceKm: Double
    var movingTimeSeconds: Int
    var elapsedTimeSeconds: Int
    var averagePacePerKm: Double?
    var averageHr: Int?
    var elevationGainM: Double?
    var mapPolyline: String?
    var matchedSessionId: UUID?
    let syncedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case stravaId = "strava_id"
        case activityDate = "activity_date"
        case name
        case distanceKm = "distance_km"
        case movingTimeSeconds = "moving_time_seconds"
        case elapsedTimeSeconds = "elapsed_time_seconds"
        case averagePacePerKm = "average_pace_per_km"
        case averageHr = "average_hr"
        case elevationGainM = "elevation_gain_m"
        case mapPolyline = "map_polyline"
        case matchedSessionId = "matched_session_id"
        case syncedAt = "synced_at"
    }

    var distanceMi: Double {
        distanceKm / 1.609
    }

    var formattedPace: String {
        guard let pace = averagePacePerKm else { return "—" }
        let pacePerMi = pace * 1.609
        let minutes = Int(pacePerMi)
        let seconds = Int((pacePerMi - Double(minutes)) * 60)
        return String(format: "%d:%02d /mi", minutes, seconds)
    }

    var formattedDuration: String {
        let hours = movingTimeSeconds / 3600
        let minutes = (movingTimeSeconds % 3600) / 60
        let seconds = movingTimeSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
