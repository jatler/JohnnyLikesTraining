import Charts
import SwiftUI

struct ProgressDashboardView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(OuraService.self) private var oura

    @State private var showingPlanSetup = false

    var body: some View {
        NavigationStack {
            Group {
                if planStore.hasPlan {
                    ScrollView {
                        VStack(spacing: 24) {
                            completionCard
                            weeklyMileageChart
                            weeklyDetailList
                            raceReadinessCard
                        }
                        .padding()
                        .padding(.bottom, 20)
                    }
                } else {
                    emptyState
                }
            }
            .navigationTitle("Progress")
        }
    }

    // MARK: - Completion Card

    private var completionCard: some View {
        let stats = computeCompletionStats()

        return VStack(spacing: 16) {
            Text("Plan Completion")
                .font(.headline)

            HStack(spacing: 20) {
                statCircle(
                    value: stats.completionRate,
                    label: "Completed",
                    color: .green
                )
                statCircle(
                    value: stats.skipRate,
                    label: "Skipped",
                    color: .red
                )
                statCircle(
                    value: stats.remainingRate,
                    label: "Remaining",
                    color: .blue
                )
            }

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(stats.completedSessions)")
                        .font(.title3.bold())
                    Text("Done")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text("\(stats.skippedSessions)")
                        .font(.title3.bold())
                        .foregroundStyle(.red)
                    Text("Skipped")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text("\(stats.remainingSessions)")
                        .font(.title3.bold())
                        .foregroundStyle(.blue)
                    Text("Left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text("\(stats.totalSessions)")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                    Text("Total")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statCircle(value: Double, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(String(format: "%.0f%%", value * 100))
                    .font(.caption.bold())
            }
            .frame(width: 60, height: 60)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Weekly Mileage Chart

    private var weeklyMileageChart: some View {
        let data = computeWeeklyMileage()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Mileage")
                .font(.headline)

            if data.isEmpty {
                Text("No data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart {
                    ForEach(data) { entry in
                        BarMark(
                            x: .value("Week", "W\(entry.week)"),
                            y: .value("Distance", entry.plannedMi)
                        )
                        .foregroundStyle(Color.swapAccent.opacity(0.25))
                        .position(by: .value("Type", "Planned"))

                        if entry.actualMi > 0 {
                            BarMark(
                                x: .value("Week", "W\(entry.week)"),
                                y: .value("Distance", entry.actualMi)
                            )
                            .foregroundStyle(Color.swapAccent)
                            .position(by: .value("Type", "Actual"))
                        }
                    }

                    if let currentWeek = planStore.currentWeekNumber,
                       let entry = data.first(where: { $0.week == currentWeek }) {
                        RuleMark(x: .value("Week", "W\(entry.week)"))
                            .foregroundStyle(.orange.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .annotation(position: .top, alignment: .center) {
                                Text("Now")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
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

    // MARK: - Weekly Detail List

    private var weeklyDetailList: some View {
        let data = computeWeeklyMileage()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Week-by-Week")
                .font(.headline)

            ForEach(data) { entry in
                weekDetailRow(entry)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func weekDetailRow(_ entry: WeekMileageEntry) -> some View {
        let isCurrent = planStore.currentWeekNumber == entry.week

        return HStack {
            Text("W\(entry.week)")
                .font(.caption.bold())
                .foregroundStyle(isCurrent ? Color.swapAccent : .secondary)
                .frame(width: 30, alignment: .leading)

            ProgressView(value: min(entry.actualMi, entry.plannedMi), total: max(entry.plannedMi, 1)) {
            }
            .tint(progressColor(actual: entry.actualMi, planned: entry.plannedMi))

            Text(String(format: "%.0f", entry.actualMi))
                .font(.caption.bold())
                .frame(width: 35, alignment: .trailing)

            Text("/")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(String(format: "%.0f mi", entry.plannedMi))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            Text("\(entry.sessionsCompleted)/\(entry.totalSessions)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .background(isCurrent ? Color.swapAccentSubtle : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func progressColor(actual: Double, planned: Double) -> Color {
        guard planned > 0 else { return .gray }
        let ratio = actual / planned
        if ratio >= 0.9 { return .green }
        if ratio >= 0.7 { return .orange }
        return .red
    }

    // MARK: - Race Readiness

    private var raceReadinessCard: some View {
        let stats = computeCompletionStats()
        let readiness = computeRaceReadiness(stats: stats)

        return VStack(spacing: 16) {
            HStack {
                Text("Race Readiness")
                    .font(.headline)
                Spacer()
                readinessBadge(readiness.level)
            }

            if let plan = planStore.activePlan {
                let daysUntilRace = Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: Date()),
                    to: Calendar.current.startOfDay(for: plan.raceDate)
                ).day ?? 0

                HStack(spacing: 24) {
                    VStack(spacing: 2) {
                        Text("\(max(daysUntilRace, 0))")
                            .font(.title.bold())
                        Text("Days to Race")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 2) {
                        Text(String(format: "%.0f%%", stats.completionRate * 100))
                            .font(.title.bold())
                            .foregroundStyle(stats.completionRate >= 0.8 ? .green : .orange)
                        Text("Completion")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let weekNum = planStore.currentWeekNumber {
                        VStack(spacing: 2) {
                            Text("\(weekNum)/\(planStore.totalWeeks)")
                                .font(.title.bold())
                            Text("Weeks")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text(readiness.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func readinessBadge(_ level: RaceReadinessLevel) -> some View {
        Text(level.label)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(level.color, in: Capsule())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.swapAccent)

            Text("No data yet")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Create a training plan and complete some runs to see your progress.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Create a Training Plan") {
                showingPlanSetup = true
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .sheet(isPresented: $showingPlanSetup) {
            PlanSetupView()
        }
    }

    // MARK: - Computation Helpers

    private func computeCompletionStats() -> CompletionStats {
        let today = Calendar.current.startOfDay(for: Date())
        let trackable: (PlannedSession) -> Bool = { $0.workoutType != .rest && $0.workoutType != .strength }
        let pastSessions = planStore.sessions.filter {
            $0.scheduledDate <= today && trackable($0)
        }

        let totalNonRest = planStore.sessions.filter { trackable($0) }.count
        let skippedIds = Set(planStore.skips.map(\.sessionId))
        let skippedCount = pastSessions.filter { skippedIds.contains($0.id) }.count

        let matchedIds = Set(strava.activities.compactMap(\.matchedSessionId))
        let completedCount = pastSessions.filter { matchedIds.contains($0.id) && !skippedIds.contains($0.id) }.count

        let pastTotal = pastSessions.count
        let completionRate: Double = pastTotal > 0 ? Double(completedCount) / Double(pastTotal) : 0
        let skipRate: Double = pastTotal > 0 ? Double(skippedCount) / Double(pastTotal) : 0
        let remaining = totalNonRest - completedCount - skippedCount
        let remainingRate: Double = totalNonRest > 0 ? Double(max(remaining, 0)) / Double(totalNonRest) : 1

        return CompletionStats(
            totalSessions: totalNonRest,
            completedSessions: completedCount,
            skippedSessions: skippedCount,
            remainingSessions: max(remaining, 0),
            completionRate: completionRate,
            skipRate: skipRate,
            remainingRate: remainingRate
        )
    }

    private func computeWeeklyMileage() -> [WeekMileageEntry] {
        planStore.allWeekNumbers.map { weekNum in
            let weekSessions = planStore.sessions(for: weekNum)
            let plannedKm = weekSessions.compactMap(\.targetDistanceKm).reduce(0, +)

            var actualKm: Double = 0
            var sessionsCompleted = 0
            for session in weekSessions {
                if let activity = strava.activity(for: session.id) {
                    actualKm += activity.distanceKm
                    sessionsCompleted += 1
                }
            }

            return WeekMileageEntry(
                week: weekNum,
                plannedKm: plannedKm,
                actualKm: actualKm,
                sessionsCompleted: sessionsCompleted,
                totalSessions: weekSessions.filter { $0.workoutType != .rest && $0.workoutType != .strength }.count
            )
        }
    }

    private func computeRaceReadiness(stats: CompletionStats) -> RaceReadiness {
        let rate = stats.completionRate

        if stats.completedSessions == 0 && stats.skippedSessions == 0 {
            return RaceReadiness(
                level: .tooEarly,
                message: "Your plan is just starting. Keep at it!"
            )
        }

        if rate >= 0.85 {
            return RaceReadiness(
                level: .onTrack,
                message: "You're nailing your plan. Keep up the great work!"
            )
        }
        if rate >= 0.65 {
            return RaceReadiness(
                level: .moderate,
                message: "Good progress, but try to stay consistent to hit your goals."
            )
        }
        return RaceReadiness(
            level: .behind,
            message: "You've missed some sessions. Consider adjusting your plan or focusing on key workouts."
        )
    }
}

// MARK: - Supporting Types

private struct CompletionStats {
    let totalSessions: Int
    let completedSessions: Int
    let skippedSessions: Int
    let remainingSessions: Int
    let completionRate: Double
    let skipRate: Double
    let remainingRate: Double
}

struct WeekMileageEntry: Identifiable {
    let week: Int
    let plannedKm: Double
    let actualKm: Double
    let sessionsCompleted: Int
    let totalSessions: Int

    var id: Int { week }

    var plannedMi: Double { DistanceFormatter.miles(from: plannedKm) }
    var actualMi: Double { DistanceFormatter.miles(from: actualKm) }
}

private struct RaceReadiness {
    let level: RaceReadinessLevel
    let message: String
}

enum RaceReadinessLevel {
    case onTrack, moderate, behind, tooEarly

    var label: String {
        switch self {
        case .onTrack: "On Track"
        case .moderate: "Fair"
        case .behind: "Behind"
        case .tooEarly: "Starting"
        }
    }

    var color: Color {
        switch self {
        case .onTrack: .green
        case .moderate: .orange
        case .behind: .red
        case .tooEarly: .blue
        }
    }
}

#Preview {
    ProgressDashboardView()
        .environment(TrainingPlanStore())
        .environment(StravaService())
        .environment(OuraService())
}
