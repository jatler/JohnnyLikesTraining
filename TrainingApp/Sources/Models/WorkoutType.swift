import Foundation
import SwiftUI

enum WorkoutType: String, Codable, CaseIterable, Identifiable {
    case easy
    case tempo
    case intervals
    case longRun = "long_run"
    case recovery
    case rest
    case race
    case crossTrain = "cross_train"
    case strength

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: "Easy"
        case .tempo: "Tempo"
        case .intervals: "Intervals"
        case .longRun: "Long Run"
        case .recovery: "Recovery"
        case .rest: "Rest"
        case .race: "Race"
        case .crossTrain: "Cross Train"
        case .strength: "Strength"
        }
    }

    var color: String {
        switch self {
        case .easy: "green"
        case .tempo: "orange"
        case .intervals: "red"
        case .longRun: "blue"
        case .recovery: "mint"
        case .rest: "gray"
        case .race: "purple"
        case .crossTrain: "yellow"
        case .strength: "indigo"
        }
    }

    var iconName: String {
        switch self {
        case .easy: "figure.walk"
        case .tempo: "gauge.with.needle.fill"
        case .intervals: "bolt.fill"
        case .longRun: "figure.run"
        case .recovery: "leaf.fill"
        case .rest: "bed.double.fill"
        case .race: "flag.checkered"
        case .crossTrain: "figure.mixed.cardio"
        case .strength: "dumbbell.fill"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .easy: .green
        case .tempo: .orange
        case .intervals: .red
        case .longRun: .blue
        case .recovery: .mint
        case .rest: .gray
        case .race: .purple
        case .crossTrain: .yellow
        case .strength: Color.swapAccent
        }
    }
}
