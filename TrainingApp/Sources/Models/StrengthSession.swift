import Foundation

/// A strength session derived from coach notes in the training plan.
/// Each session corresponds to a `PlannedSession` with `workoutType == .strength`.
struct StrengthSession: Codable, Identifiable {
    let id: UUID
    let planId: UUID
    /// FK to `planned_sessions(id)`. Nullable: user-added strength days have no
    /// backing `PlannedSession`, and orphaned rows (whose planned_session was
    /// deleted) become null on the server via `on delete set null`. The column
    /// USED to be encoded as a non-optional UUID — sending a random placeholder
    /// for user-added sessions violated the FK constraint and made every
    /// `persistAllSessions` upsert fail with a "Failed to save strength
    /// sessions" alert.
    var plannedSessionId: UUID?
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

    init(id: UUID, planId: UUID, plannedSessionId: UUID?, scheduledDate: Date,
         weekNumber: Int, dayOfWeek: Int, coachNotes: String, isComplete: Bool) {
        self.id = id
        self.planId = planId
        self.plannedSessionId = plannedSessionId
        self.scheduledDate = scheduledDate
        self.weekNumber = weekNumber
        self.dayOfWeek = dayOfWeek
        self.coachNotes = coachNotes
        self.isComplete = isComplete
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        planId = try c.decode(UUID.self, forKey: .planId)
        plannedSessionId = try c.decodeIfPresent(UUID.self, forKey: .plannedSessionId)
        scheduledDate = try c.decode(Date.self, forKey: .scheduledDate)
        weekNumber = try c.decode(Int.self, forKey: .weekNumber)
        dayOfWeek = try c.decode(Int.self, forKey: .dayOfWeek)
        coachNotes = try c.decodeIfPresent(String.self, forKey: .coachNotes) ?? ""
        isComplete = try c.decodeIfPresent(Bool.self, forKey: .isComplete) ?? false
    }

    /// Custom encode to ALWAYS emit `planned_session_id` — as `null` when nil rather
    /// than omitting the key. PostgREST otherwise won't clear stale FK values on rows
    /// that already exist server-side, leaving the upsert FK constraint to keep failing.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(planId, forKey: .planId)
        try c.encode(plannedSessionId, forKey: .plannedSessionId)   // emits null for nil
        try c.encode(scheduledDate, forKey: .scheduledDate)
        try c.encode(weekNumber, forKey: .weekNumber)
        try c.encode(dayOfWeek, forKey: .dayOfWeek)
        try c.encode(coachNotes, forKey: .coachNotes)
        try c.encode(isComplete, forKey: .isComplete)
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
