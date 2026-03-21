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

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case scheduledDate = "scheduled_date"
        case weekNumber = "week_number"
        case dayOfWeek = "day_of_week"
        case sessionType = "session_type"
        case targetDurationMinutes = "target_duration_minutes"
        case notes
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
