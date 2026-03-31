import Charts
import SwiftUI

struct LongRunProgressionChart: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Long Run Progression")
                .font(.headline)

            let data = longRunData()

            if data.isEmpty {
                Text("No long runs scheduled yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart {
                    ForEach(data) { entry in
                        // Planned line (dimmed)
                        LineMark(
                            x: .value("Week", entry.label),
                            y: .value("Distance", entry.plannedMi),
                            series: .value("Type", "Planned")
                        )
                        .foregroundStyle(Color.swapAccent.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))

                        PointMark(
                            x: .value("Week", entry.label),
                            y: .value("Distance", entry.plannedMi)
                        )
                        .foregroundStyle(Color.swapAccent.opacity(0.4))
                        .symbolSize(30)

                        // Actual line (full color, only if we have data)
                        if let actualMi = entry.actualMi {
                            LineMark(
                                x: .value("Week", entry.label),
                                y: .value("Distance", actualMi),
                                series: .value("Type", "Actual")
                            )
                            .foregroundStyle(Color.swapAccent)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            PointMark(
                                x: .value("Week", entry.label),
                                y: .value("Distance", actualMi)
                            )
                            .foregroundStyle(Color.swapAccent)
                            .symbolSize(40)
                        }
                    }
                }
                .chartYAxisLabel("mi")
                .chartLegend(position: .bottom)
                .frame(height: 220)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Data

    private func longRunData() -> [LongRunEntry] {
        planStore.sessions
            .filter { $0.workoutType == .longRun }
            .sorted { $0.scheduledDate < $1.scheduledDate }
            .map { session in
                let plannedMi = session.targetDistanceKm
                    .map { DistanceFormatter.miles(from: $0) } ?? 0

                let activity = strava.activity(for: session.id)
                let actualMi: Double? = activity.map { DistanceFormatter.miles(from: $0.distanceKm) }

                return LongRunEntry(
                    id: session.id,
                    label: "W\(session.weekNumber)",
                    plannedMi: plannedMi,
                    actualMi: actualMi
                )
            }
    }
}

// MARK: - Supporting Type

private struct LongRunEntry: Identifiable {
    let id: UUID
    let label: String
    let plannedMi: Double
    let actualMi: Double?
}
