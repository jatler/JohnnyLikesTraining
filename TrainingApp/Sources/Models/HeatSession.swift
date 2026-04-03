import Foundation
import SwiftUI

struct HeatSession: Codable, Identifiable {
    let id: UUID
    let planId: UUID
    var scheduledDate: Date
    var weekNumber: Int
    var dayOfWeek: Int
    var sessionType: HeatType
    var targetDurationMinutes: Int
    var notes: String?
    var isTemplateOverride: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case scheduledDate = "scheduled_date"
        case weekNumber = "week_number"
        case dayOfWeek = "day_of_week"
        case sessionType = "session_type"
        case targetDurationMinutes = "target_duration_minutes"
        case notes
        case isTemplateOverride = "is_template_override"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        planId = try container.decode(UUID.self, forKey: .planId)
        scheduledDate = try container.decode(Date.self, forKey: .scheduledDate)
        weekNumber = try container.decode(Int.self, forKey: .weekNumber)
        dayOfWeek = try container.decode(Int.self, forKey: .dayOfWeek)
        sessionType = try container.decode(HeatType.self, forKey: .sessionType)
        targetDurationMinutes = try container.decode(Int.self, forKey: .targetDurationMinutes)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isTemplateOverride = try container.decodeIfPresent(Bool.self, forKey: .isTemplateOverride) ?? false
    }

    init(id: UUID, planId: UUID, scheduledDate: Date, weekNumber: Int, dayOfWeek: Int, sessionType: HeatType, targetDurationMinutes: Int, notes: String? = nil, isTemplateOverride: Bool = false) {
        self.id = id
        self.planId = planId
        self.scheduledDate = scheduledDate
        self.weekNumber = weekNumber
        self.dayOfWeek = dayOfWeek
        self.sessionType = sessionType
        self.targetDurationMinutes = targetDurationMinutes
        self.notes = notes
        self.isTemplateOverride = isTemplateOverride
    }
}

enum HeatType: String, Codable, CaseIterable, Identifiable {
    case sauna
    case hotTub = "hot_tub"
    case heatSuit = "heat_suit"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sauna: "Sauna"
        case .hotTub: "Hot Tub"
        case .heatSuit: "Heat Suit"
        }
    }

    var iconName: String {
        switch self {
        case .sauna: "flame.fill"
        case .hotTub: "drop.fill"
        case .heatSuit: "figure.run"
        }
    }

    var color: Color {
        switch self {
        case .sauna: .orange
        case .hotTub: .cyan
        case .heatSuit: .red
        }
    }
}
