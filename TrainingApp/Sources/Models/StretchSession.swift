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
        case .preRun: .teal
        case .postRun: .mint
        case .recovery: .cyan
        case .mobility: .blue
        }
    }
}
