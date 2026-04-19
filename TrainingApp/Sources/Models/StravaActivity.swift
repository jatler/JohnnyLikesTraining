import Foundation

struct StravaActivity: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let stravaId: Int64
    var activityDate: Date
    /// Wall-clock start time in the activity's own timezone, decoded from Strava's
    /// `start_date_local` (which they emit as a UTC-marked ISO-8601 string even though
    /// the hours/minutes are local). Always interpret this `Date` with a **UTC calendar**
    /// to recover the local-to-the-activity day and time. Nil for rows imported before
    /// this field was added; callers should fall back to `activityDate`.
    var startDateLocal: Date?
    /// IANA timezone id where the activity was recorded (e.g. "America/Los_Angeles"),
    /// extracted from Strava's `timezone` string like "(GMT-08:00) America/Los_Angeles".
    var timeZoneIdentifier: String?
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
        case startDateLocal = "start_date_local"
        case timeZoneIdentifier = "time_zone_identifier"
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

    /// Calendar day the activity was recorded on, in the activity's own timezone.
    /// Falls back to `activityDate` (UTC) for legacy rows with no `startDateLocal`.
    var localCalendarDay: Date {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return utcCalendar.startOfDay(for: startDateLocal ?? activityDate)
    }

    var isRun: Bool {
        ["Run", "TrailRun", "VirtualRun"].contains(activityType)
    }

    var isCrossTraining: Bool {
        [
            "Ride", "MountainBikeRide", "GravelRide", "EBikeRide", "VirtualRide",
            "CrossCountrySkiing", "BackcountrySki", "NordicSki", "AlpineSki", "Snowboard",
            "Elliptical", "Hike", "RockClimbing", "Rowing", "StairStepper", "Swim", "Walk"
        ].contains(activityType)
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
        case "Ride": return "Ride"
        case "MountainBikeRide": return "MTB"
        case "GravelRide": return "Gravel"
        case "EBikeRide": return "E-Bike"
        case "VirtualRide": return "Virtual Ride"
        case "CrossCountrySkiing": return "XC Ski"
        case "BackcountrySki": return "Backcountry Ski"
        case "NordicSki": return "Nordic Ski"
        case "AlpineSki": return "Alpine Ski"
        case "Snowboard": return "Snowboard"
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
