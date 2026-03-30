import Charts
import SwiftUI

struct ProgressDashboardView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(OuraService.self) private var oura
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(StretchStore.self) private var stretchStore
    @Environment(HeatStore.self) private var heatStore

    @State private var showingPlanSetup = false

    var body: some View {
        NavigationStack {
            Group {
                if planStore.hasPlan {
                    ScrollView {
                        VStack(spacing: 24) {
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
                    color: .swapAccent
                )
                statCircle(
                    value: stats.missedRate,
                    label: "Missed",
                    color: .red.opacity(0.7)
                )
                statCircle(
                    value: stats.skipRate,
                    label: "Skipped",
                    color: .orange.opacity(0.7)
                )
            }

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(stats.completedSessions)")
                        .font(.title3.bold())
                        .foregroundStyle(Color.swapAccent)
                    Text("Done")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text("\(stats.missedSessions)")
                        .font(.title3.bold())
                        .foregroundStyle(.red.opacity(0.7))
                    Text("Missed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text("\(stats.skippedSessions)")
                        .font(.title3.bold())
                        .foregroundStyle(.orange.opacity(0.7))
                    Text("Skipped")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text("\(stats.upcomingSessions)")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                    Text("Upcoming")
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
                .chartYScale(domain: 0...(data.map(\.plannedMi).max().map { $0 + 10 } ?? 10))
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
        let globalMaxMi = data.map(\.plannedMi).max() ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            Text("Week-by-Week")
                .font(.headline)

            ForEach(data) { entry in
                weekDetailRow(entry, globalMaxMi: globalMaxMi)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func weekDetailRow(_ entry: WeekMileageEntry, globalMaxMi: Double) -> some View {
        let isCurrent = planStore.currentWeekNumber == entry.week
        let scale = globalMaxMi > 0 ? globalMaxMi : 1
        let plannedFraction = entry.plannedMi / scale
        let actualFraction = entry.actualMi / scale
        // XT bar width proportional to actual run hours
        let ctBarFraction = entry.runHours > 0
            ? (entry.crossTrainHours / entry.runHours) * actualFraction
            : 0

        return VStack(alignment: .leading, spacing: 3) {
            // Mileage bar: planned (light) with actual (dark) on top
            HStack(spacing: 6) {
                Text("W\(entry.week)")
                    .font(.caption.bold())
                    .foregroundStyle(isCurrent ? Color.swapAccent : .secondary)
                    .frame(width: 28, alignment: .leading)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.swapAccent.opacity(0.15))
                            .frame(width: geo.size.width * plannedFraction)
                        if entry.actualMi > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.swapAccent)
                                .frame(width: geo.size.width * actualFraction)
                        }
                    }
                }
                .frame(height: 10)

                // Stats to the right
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.0f/%.0f mi", entry.actualMi, entry.plannedMi))
                        .font(.caption2.bold())
                    if entry.runHours > 0 || entry.elevationGainFt > 0 {
                        HStack(spacing: 4) {
                            if entry.runHours > 0 {
                                Text(String(format: "%.1fh", entry.runHours))
                            }
                            if entry.elevationGainFt > 0 {
                                Text(String(format: "%.0f'", entry.elevationGainFt))
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 70, alignment: .trailing)
            }

            // Cross-training bar: proportional to actual run hours
            if entry.crossTrainHours > 0 {
                HStack(spacing: 6) {
                    Spacer().frame(width: 28)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange.opacity(0.4))
                            .frame(width: max(geo.size.width * ctBarFraction, 4))
                    }
                    .frame(height: 6)

                    Text(String(format: "%.1fh XT", entry.crossTrainHours))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 4)
        .background(isCurrent ? Color.swapAccentSubtle : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
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
                            .foregroundStyle(Color.swapAccent)
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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let skippedIds = Set(planStore.skips.map(\.sessionId))

        // --- Running / cross-train ---
        let trackableRuns = planStore.sessions.filter { $0.workoutType != .rest && $0.workoutType != .strength }
        let pastRuns = trackableRuns.filter { $0.scheduledDate <= today }
        let matchedIds = Set(strava.activities.compactMap(\.matchedSessionId))
        let completedRuns = pastRuns.filter { matchedIds.contains($0.id) && !skippedIds.contains($0.id) }.count
        let skippedCount = pastRuns.filter { skippedIds.contains($0.id) }.count

        // --- Strength days ---
        let allStrengthDates = Set(strengthStore.sessions.map { calendar.startOfDay(for: $0.scheduledDate) })
        let pastStrengthDates = allStrengthDates.filter { $0 <= today }
        let completedStrengthDays = pastStrengthDates.filter { date in
            strengthStore.isDayComplete(on: date, stravaActivities: strava.activities)
        }.count

        // --- Stretch days ---
        let allStretchDates = Set(stretchStore.sessions.map { calendar.startOfDay(for: $0.scheduledDate) })
        let pastStretchDates = allStretchDates.filter { $0 <= today }
        let completedStretchDays = pastStretchDates.filter { stretchStore.isAllComplete(on: $0) }.count

        // --- Heat sessions ---
        let allHeatSessions = heatStore.sessions
        let pastHeatSessions = allHeatSessions.filter { calendar.startOfDay(for: $0.scheduledDate) <= today }
        let completedHeatSessions = pastHeatSessions.filter { heatStore.isComplete($0.id) }.count

        // --- Unified totals ---
        let totalTrackable = trackableRuns.count + allStrengthDates.count + allStretchDates.count + allHeatSessions.count
        let totalPast = pastRuns.count + pastStrengthDates.count + pastStretchDates.count + pastHeatSessions.count
        let totalCompleted = completedRuns + completedStrengthDays + completedStretchDays + completedHeatSessions
        let missedCount = max(totalPast - totalCompleted - skippedCount, 0)
        let upcomingCount = totalTrackable - totalPast

        let completionRate: Double = totalPast > 0 ? Double(totalCompleted) / Double(totalPast) : 0
        let missedRate: Double = totalPast > 0 ? Double(missedCount) / Double(totalPast) : 0
        let skipRate: Double = totalPast > 0 ? Double(skippedCount) / Double(totalPast) : 0

        return CompletionStats(
            totalSessions: totalTrackable,
            completedSessions: totalCompleted,
            missedSessions: missedCount,
            skippedSessions: skippedCount,
            upcomingSessions: upcomingCount,
            completionRate: completionRate,
            missedRate: missedRate,
            skipRate: skipRate
        )
    }

    private func computeWeeklyMileage() -> [WeekMileageEntry] {
        let calendar = Calendar.current

        return planStore.allWeekNumbers.map { weekNum in
            let weekSessions = planStore.sessions(for: weekNum)
            let trackableRuns = weekSessions.filter { $0.workoutType != .rest && $0.workoutType != .strength }
            let plannedKm = trackableRuns.compactMap(\.targetDistanceKm).reduce(0, +)

            // Only count running activities for mileage, hours, and vert
            var actualKm: Double = 0
            var runsDone = 0
            var runSeconds = 0
            var elevationM: Double = 0
            for session in trackableRuns {
                if let activity = strava.activity(for: session.id), activity.isRun {
                    actualKm += activity.distanceKm
                    runSeconds += activity.movingTimeSeconds
                    elevationM += activity.elevationGainM ?? 0
                    runsDone += 1
                }
            }

            // Cross-training hours from Strava activities matched this week
            var crossTrainSeconds = 0
            for session in weekSessions {
                if let activity = strava.activity(for: session.id), activity.isCrossTraining {
                    crossTrainSeconds += activity.movingTimeSeconds
                }
            }

            let weekStrengthDates = Set(
                strengthStore.sessions
                    .filter { $0.weekNumber == weekNum }
                    .map { calendar.startOfDay(for: $0.scheduledDate) }
            )
            let strengthDone = weekStrengthDates.filter { date in
                strengthStore.isDayComplete(on: date, stravaActivities: strava.activities)
            }.count

            let weekStretchDates = Set(
                stretchStore.sessions
                    .filter { $0.weekNumber == weekNum }
                    .map { calendar.startOfDay(for: $0.scheduledDate) }
            )
            let stretchDone = weekStretchDates.filter { stretchStore.isAllComplete(on: $0) }.count

            let weekHeat = heatStore.sessions(for: weekNum)
            let heatDone = weekHeat.filter { heatStore.isComplete($0.id) }.count

            let totalItems = trackableRuns.count + weekStrengthDates.count + weekStretchDates.count + weekHeat.count
            let completedItems = runsDone + strengthDone + stretchDone + heatDone

            return WeekMileageEntry(
                week: weekNum,
                plannedKm: plannedKm,
                actualKm: actualKm,
                crossTrainSeconds: crossTrainSeconds,
                runSeconds: runSeconds,
                elevationGainM: elevationM,
                sessionsCompleted: completedItems,
                totalSessions: totalItems
            )
        }
    }

    private func computeRaceReadiness(stats: CompletionStats) -> RaceReadiness {
        let rate = stats.completionRate
        let hasPastSessions = stats.completedSessions + stats.missedSessions + stats.skippedSessions > 0

        if !hasPastSessions {
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
    let missedSessions: Int
    let skippedSessions: Int
    let upcomingSessions: Int
    let completionRate: Double
    let missedRate: Double
    let skipRate: Double
}

struct WeekMileageEntry: Identifiable {
    let week: Int
    let plannedKm: Double
    let actualKm: Double
    let crossTrainSeconds: Int
    let runSeconds: Int
    let elevationGainM: Double
    let sessionsCompleted: Int
    let totalSessions: Int

    var id: Int { week }

    var plannedMi: Double { DistanceFormatter.miles(from: plannedKm) }
    var actualMi: Double { DistanceFormatter.miles(from: actualKm) }
    var crossTrainHours: Double { Double(crossTrainSeconds) / 3600.0 }
    var runHours: Double { Double(runSeconds) / 3600.0 }
    var elevationGainFt: Double { elevationGainM * 3.28084 }
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
        .environment(StrengthStore())
        .environment(StretchStore())
        .environment(HeatStore())
}
