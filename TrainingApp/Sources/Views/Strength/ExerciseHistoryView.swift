import SwiftUI
import Charts

struct ExerciseHistoryView: View {
    let exerciseName: String

    @Environment(StrengthStore.self) private var strengthStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let allLogs = strengthStore.allLogs(for: exerciseName)

                    if allLogs.isEmpty {
                        emptyState
                    } else {
                        weightChart(allLogs)
                        repsChart(allLogs)
                        logTable(allLogs)
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Weight Chart

    @ViewBuilder
    private func weightChart(_ logs: [StrengthLog]) -> some View {
        let weightLogs = logs.filter { $0.actualWeightKg != nil }

        if !weightLogs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Weight Over Time")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Chart(weightLogs) { log in
                    LineMark(
                        x: .value("Date", log.completedAt),
                        y: .value("Weight (lbs)", (log.actualWeightKg ?? 0) * 2.205)
                    )
                    .foregroundStyle(Color.swapAccent)

                    PointMark(
                        x: .value("Date", log.completedAt),
                        y: .value("Weight (lbs)", (log.actualWeightKg ?? 0) * 2.205)
                    )
                    .foregroundStyle(Color.swapAccent)
                }
                .frame(height: 180)
                .chartYAxisLabel("lbs")
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Reps Chart

    private func repsChart(_ logs: [StrengthLog]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reps Over Time")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Chart(logs) { log in
                BarMark(
                    x: .value("Date", log.completedAt),
                    y: .value("Reps", log.actualReps)
                )
                .foregroundStyle(Color.swapAccent.opacity(0.6))
            }
            .frame(height: 140)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Log Table

    private func logTable(_ logs: [StrengthLog]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Logs")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            let recentLogs = Array(logs.suffix(20).reversed())

            ForEach(recentLogs) { log in
                HStack {
                    Text(log.completedAt.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)

                    Text("Set \(log.setNumber)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 40)

                    Text("\(log.actualReps) reps")
                        .font(.caption.bold())

                    if let kg = log.actualWeightKg {
                        Text("@ \(Int(kg * 2.205)) lbs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let rpe = log.rpe {
                        Text("RPE \(String(format: "%.0f", rpe))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)

                if log.id != recentLogs.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(Color.swapAccent.opacity(0.5))

            Text("No history yet")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Log sets to start tracking progression for \(exerciseName).")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}

#Preview {
    ExerciseHistoryView(exerciseName: "Goblet Squats")
        .environment(StrengthStore())
}
