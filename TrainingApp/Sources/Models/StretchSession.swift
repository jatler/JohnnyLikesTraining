import Foundation
import SwiftUI

struct StretchTemplate: Codable, Identifiable {
    let id: UUID
    let planId: UUID
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct StretchTemplateExercise: Codable, Identifiable {
    let id: UUID
    var templateId: UUID
    var dayOfWeek: Int
    var stretchName: String
    var holdSeconds: Int
    var sets: Int
    var isBilateral: Bool
    var sortOrder: Int
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case dayOfWeek = "day_of_week"
        case stretchName = "stretch_name"
        case holdSeconds = "hold_seconds"
        case sets
        case isBilateral = "is_bilateral"
        case sortOrder = "sort_order"
        case notes
    }

    var displayDuration: String {
        let perSide = isBilateral ? " each side" : ""
        return "\(sets)×\(holdSeconds)s\(perSide)"
    }
}

struct StretchSession: Codable, Identifiable {
    let id: UUID
    let planId: UUID
    var templateExerciseId: UUID?
    var scheduledDate: Date
    var weekNumber: Int
    var dayOfWeek: Int
    var stretchName: String
    var prescribedHoldSeconds: Int
    var prescribedSets: Int
    var isBilateral: Bool
    /// Skip is tracked per-session, but the UI applies it day-wide via
    /// `StretchStore.skipDay` so all stretches on a given day share the flag.
    var isSkipped: Bool = false
    var skipReason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case templateExerciseId = "template_exercise_id"
        case scheduledDate = "scheduled_date"
        case weekNumber = "week_number"
        case dayOfWeek = "day_of_week"
        case stretchName = "stretch_name"
        case prescribedHoldSeconds = "prescribed_hold_seconds"
        case prescribedSets = "prescribed_sets"
        case isBilateral = "is_bilateral"
        case isSkipped = "is_skipped"
        case skipReason = "skip_reason"
    }

    init(id: UUID, planId: UUID, templateExerciseId: UUID?, scheduledDate: Date,
         weekNumber: Int, dayOfWeek: Int, stretchName: String, prescribedHoldSeconds: Int,
         prescribedSets: Int, isBilateral: Bool, isSkipped: Bool = false, skipReason: String? = nil) {
        self.id = id
        self.planId = planId
        self.templateExerciseId = templateExerciseId
        self.scheduledDate = scheduledDate
        self.weekNumber = weekNumber
        self.dayOfWeek = dayOfWeek
        self.stretchName = stretchName
        self.prescribedHoldSeconds = prescribedHoldSeconds
        self.prescribedSets = prescribedSets
        self.isBilateral = isBilateral
        self.isSkipped = isSkipped
        self.skipReason = skipReason
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        planId = try c.decode(UUID.self, forKey: .planId)
        templateExerciseId = try c.decodeIfPresent(UUID.self, forKey: .templateExerciseId)
        scheduledDate = try c.decode(Date.self, forKey: .scheduledDate)
        weekNumber = try c.decode(Int.self, forKey: .weekNumber)
        dayOfWeek = try c.decode(Int.self, forKey: .dayOfWeek)
        stretchName = try c.decode(String.self, forKey: .stretchName)
        prescribedHoldSeconds = try c.decode(Int.self, forKey: .prescribedHoldSeconds)
        prescribedSets = try c.decode(Int.self, forKey: .prescribedSets)
        isBilateral = try c.decode(Bool.self, forKey: .isBilateral)
        isSkipped = try c.decodeIfPresent(Bool.self, forKey: .isSkipped) ?? false
        skipReason = try c.decodeIfPresent(String.self, forKey: .skipReason)
    }
}

enum StretchRoutineType: String, Codable, CaseIterable, Identifiable {
    case preRun = "pre_run"
    case postRun = "post_run"
    case recovery
    case mobility

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .preRun: "Pre-Run"
        case .postRun: "Post-Run"
        case .recovery: "Recovery"
        case .mobility: "Mobility"
        }
    }

    var iconName: String {
        switch self {
        case .preRun: "figure.walk"
        case .postRun: "figure.cooldown"
        case .recovery: "figure.mind.and.body"
        case .mobility: "figure.flexibility"
        }
    }

    var color: Color {
        switch self {
        case .preRun: Color.trailGreen
        case .postRun: .mint
        case .recovery: .cyan
        case .mobility: .blue
        }
    }
}
