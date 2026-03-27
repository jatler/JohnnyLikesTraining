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
    var activityType: String
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
        case activityType = "activity_type"
        case matchedSessionId = "matched_session_id"
        case syncedAt = "synced_at"
    }

    var isRun: Bool {
        ["Run", "TrailRun", "VirtualRun"].contains(activityType)
    }

    var isCrossTraining: Bool {
        ["CrossCountrySkiing", "Elliptical", "Hike", "RockClimbing", "Rowing", "StairStepper", "Swim", "Walk"].contains(activityType)
    }

    var isStrength: Bool {
        ["WeightTraining", "Crossfit"].contains(activityType)
    }

    var isYoga: Bool {
        activityType == "Yoga"
    }

    var activityTypeDisplay: String {
        switch activityType {
        case "Run": return "Run"
        case "TrailRun": return "Trail Run"
        case "VirtualRun": return "Virtual Run"
        case "WeightTraining": return "Strength"
        case "Crossfit": return "CrossFit"
        case "Yoga": return "Yoga"
        case "CrossCountrySkiing": return "XC Ski"
        case "Elliptical": return "Elliptical"
        case "Hike": return "Hike"
        case "RockClimbing": return "Climbing"
        case "Rowing": return "Rowing"
        case "StairStepper": return "Stairs"
        case "Swim": return "Swim"
        case "Walk": return "Walk"
        default: return activityType
        }
    }

    var distanceMi: Double {
        DistanceFormatter.miles(from: distanceKm)
    }

    var formattedPace: String {
        guard let pace = averagePacePerKm else { return "—" }
        let pacePerMi = pace / 0.621371
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
