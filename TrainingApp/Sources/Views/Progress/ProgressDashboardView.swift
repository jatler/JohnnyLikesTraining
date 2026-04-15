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
                    VStack(spacing: 0) {
                        Text("Progress")
                            .font(TrailFont.dataLarge)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.trailGreen)

                        ScrollView {
                            VStack(spacing: 12) {
                                weeklyDetailList
                                raceReadinessCard
                                if let plan = planStore.activePlan {
                                    planInfoBar(plan)
                                }
                            }
                            .padding()
                            .padding(.bottom, 20)
                        }
                    }
                } else {
                    emptyState
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Completion Card

    private var completionCard: some View {
        let stats = computeCompletionStats()

        return VStack(spacing: 16) {
            Text("Plan Completion")
                .font(TrailFont.title)

            HStack(spacing: 20) {
                statCircle(
                    value: stats.completionRate,
                    label: "Completed",
                    color: .trailGreen
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
                        .font(TrailFont.dataBold)
                        .foregroundStyle(Color.trailGreen)
                    Text("Done")
                        .font(TrailFont.meta)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text("\(stats.missedSessions)")
                        .font(TrailFont.dataBold)
                        .foregroundStyle(.red.opacity(0.7))
                    Text("Missed")
                        .font(TrailFont.meta)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text("\(stats.skippedSessions)")
                        .font(TrailFont.dataBold)
                        .foregroundStyle(.orange.opacity(0.7))
                    Text("Skipped")
                        .font(TrailFont.meta)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text("\(stats.upcomingSessions)")
                        .font(TrailFont.dataBold)
                        .foregroundStyle(.secondary)
                    Text("Upcoming")
                        .font(TrailFont.meta)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
                    .font(TrailFont.dataBold)
            }
            .frame(width: 60, height: 60)

            Text(label)
                .font(TrailFont.meta)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Weekly Mileage Chart

    private var weeklyMileageChart: some View {
        let data = computeWeeklyMileage()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Mileage")
                .font(TrailFont.title)

            if data.isEmpty {
                Text("No data yet")
                    .font(TrailFont.detail)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart {
                    ForEach(data) { entry in
                        BarMark(
                            x: .value("Week", "W\(entry.week)"),
                            y: .value("Distance", entry.plannedMi)
                        )
                        .foregroundStyle(Color.trailGreen.opacity(0.25))
                        .position(by: .value("Type", "Planned"))

                        if entry.actualMi > 0 {
                            BarMark(
                                x: .value("Week", "W\(entry.week)"),
                                y: .value("Distance", entry.actualMi)
                            )
                            .foregroundStyle(Color.trailGreen)
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
                                    .font(TrailFont.meta)
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Weekly Detail List

    private var weeklyDetailList: some View {
        let data = computeWeeklyMileage()
        let globalMaxMi = data.map(\.plannedMi).max() ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            Text("Week-by-Week")
                .font(TrailFont.title)

            ForEach(data) { entry in
                weekDetailRow(entry, globalMaxMi: globalMaxMi)
            }
        }
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
                    .font(TrailFont.metaBold)
                    .foregroundStyle(isCurrent ? Color.trailGreen : .secondary)
                    .frame(width: 28, alignment: .leading)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.trailGreen.opacity(0.15))
                            .frame(width: geo.size.width * plannedFraction)
                        if entry.actualMi > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.trailGreen)
                                .frame(width: geo.size.width * actualFraction)
                        }
                    }
                }
                .frame(height: 10)

                // Stats to the right
                VStack(alignment: .leading, spacing: 2) {
                    Label(String(format: "%.0f/%.0f mi", entry.actualMi, entry.plannedMi), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(TrailFont.dataBold)
                    if entry.elevationGainFt > 0 {
                        Label(String(format: "%.0f ft", entry.elevationGainFt), systemImage: "mountain.2.fill")
                            .font(TrailFont.data)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 90, alignment: .leading)
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
                    .frame(height: 10)

                    Label(String(format: "%.1fh", entry.crossTrainHours), systemImage: "bicycle")
                        .font(TrailFont.data)
                        .foregroundStyle(.orange)
                        .frame(width: 90, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 4)
        .background(isCurrent ? Color.trailGreenSubtle : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Race Readiness

    private var raceReadinessCard: some View {
        let stats = computeCompletionStats()
        let readiness = computeRaceReadiness(stats: stats)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Race Readiness")
                    .font(TrailFont.title)
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(max(daysUntilRace, 0))")
                            .font(TrailFont.dataLarge)
                        Text("Days to Race")
                            .font(TrailFont.meta)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.0f%%", stats.completionRate * 100))
                            .font(TrailFont.dataLarge)
                            .foregroundStyle(Color.trailGreen)
                        Text("Completion")
                            .font(TrailFont.meta)
                            .foregroundStyle(.secondary)
                    }

                    if let weekNum = planStore.currentWeekNumber {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(weekNum)/\(planStore.totalWeeks)")
                                .font(TrailFont.dataLarge)
                            Text("Weeks")
                                .font(TrailFont.meta)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text(readiness.message)
                    .font(TrailFont.detail)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 16)
    }

    private func readinessBadge(_ level: RaceReadinessLevel) -> some View {
        Text(level.label)
            .font(TrailFont.metaBold)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(level.color, in: Capsule())
    }

    // MARK: - Plan Info

    private func planInfoBar(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.name)
                .font(TrailFont.title)

            HStack {
                Label("Race: \(plan.raceDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "flag.fill")
                Spacer()
                if let week = planStore.currentWeekNumber {
                    Text("Week \(week) of \(planStore.totalWeeks)")
                        .fontWeight(.medium)
                }
            }
            .font(TrailFont.detail)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.trailGreen)

            Text("No data yet")
                .font(TrailFont.title)
                .foregroundStyle(.secondary)

            Text("Create a training plan and complete some runs to see your progress.")
                .font(TrailFont.detail)
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

        // --- Unified totals (runs + XT only for race readiness) ---
        let totalTrackable = trackableRuns.count
        let totalPast = pastRuns.count
        let totalCompleted = completedRuns
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

            // Count ALL running activities for the week — matched to any session type
            // (including rest days) plus unmatched activities in the week's date range.
            var actualKm: Double = 0
            var runsDone = 0
            var runSeconds = 0
            var elevationM: Double = 0
            var countedActivityIds: Set<Int64> = []

            // First: activities matched to any session this week
            for session in weekSessions {
                if let activity = strava.activity(for: session.id), activity.isRun {
                    actualKm += activity.distanceKm
                    runSeconds += activity.movingTimeSeconds
                    elevationM += activity.elevationGainM ?? 0
                    runsDone += 1
                    countedActivityIds.insert(activity.stravaId)
                }
            }

            // Second: unmatched Strava running activities in this week's date range
            if let firstDate = weekSessions.first?.scheduledDate,
               let lastDate = weekSessions.last?.scheduledDate {
                for activity in strava.activities where activity.isRun && !countedActivityIds.contains(activity.stravaId) {
                    if activity.activityDate >= calendar.startOfDay(for: firstDate),
                       activity.activityDate < calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDate))! {
                        actualKm += activity.distanceKm
                        runSeconds += activity.movingTimeSeconds
                        elevationM += activity.elevationGainM ?? 0
                        runsDone += 1
                        countedActivityIds.insert(activity.stravaId)
                    }
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
