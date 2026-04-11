import Foundation

/// A strength session derived from coach notes in the training plan.
/// Each session corresponds to a `PlannedSession` with `workoutType == .strength`.
struct StrengthSession: Codable, Identifiable {
    let id: UUID
    let planId: UUID
    var plannedSessionId: UUID
    var scheduledDate: Date
    var weekNumber: Int
    var dayOfWeek: Int
    var coachNotes: String
    var isComplete: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case plannedSessionId = "planned_session_id"
        case scheduledDate = "scheduled_date"
        case weekNumber = "week_number"
        case dayOfWeek = "day_of_week"
        case coachNotes = "coach_notes"
        case isComplete = "is_complete"
    }

    /// Short label extracted from the coach notes for display in compact views.
    var label: String {
        let text = coachNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "Strength" }

        // Use the first sentence or up to 60 chars as a label
        if let dotIndex = text.firstIndex(of: ".") {
            let firstSentence = String(text[text.startIndex...dotIndex])
            if firstSentence.count <= 80 { return firstSentence }
        }
        if text.count <= 60 { return text }
        let prefix = String(text.prefix(57))
        return prefix + "..."
    }
}
