import Foundation

struct PlannedSession: Codable, Identifiable {
    let id: UUID
    let planId: UUID
    var weekNumber: Int
    var dayOfWeek: Int
    var scheduledDate: Date
    var workoutType: WorkoutType
    var targetDistanceKm: Double?
    var targetPaceDescription: String?
    var notes: String?
    var sortOrder: Int

    var targetDistanceMi: Double? {
        targetDistanceKm.map { DistanceFormatter.miles(from: $0) }
    }

    /// Full coaching text for display: session `notes` plus `targetPaceDescription` when that line is not already contained in the notes (templates often split them across JSON fields).
    var verbatimCoachNotesForDisplay: String {
        let paceTrimmed = targetPaceDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bodyTrimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let pace = paceTrimmed.isEmpty ? nil : paceTrimmed
        let body = bodyTrimmed.isEmpty ? nil : bodyTrimmed
        switch (pace, body) {
        case (nil, nil):
            return ""
        case let (p?, nil):
            return p
        case let (nil, b?):
            return b
        case let (p?, b?):
            if b.lowercased().contains(p.lowercased()) {
                return b
            }
            return "\(p)\n\n\(b)"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case weekNumber = "week_number"
        case dayOfWeek = "day_of_week"
        case scheduledDate = "scheduled_date"
        case workoutType = "workout_type"
        case targetDistanceKm = "target_distance_km"
        case targetPaceDescription = "target_pace_description"
        case notes
        case sortOrder = "sort_order"
    }
}
