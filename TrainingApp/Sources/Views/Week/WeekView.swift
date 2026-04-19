import SwiftUI

struct WeekView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(OuraService.self) private var oura

    @State private var selectedWeek: Int = 1
    @State private var selectedSession: PlannedSession?
    @State private var hasInitialized = false
    @State private var showingPlanSetup = false

    var body: some View {
        NavigationStack {
            Group {
                if planStore.hasPlan {
                    weekContent
                } else {
                    emptyState
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Error", isPresented: Binding(
                get: { planStore.lastError != nil },
                set: { if !$0 { planStore.lastError = nil } }
            )) {
                Button("OK") { planStore.lastError = nil }
            } message: {
                Text(planStore.lastError ?? "")
            }
        }
    }

    // MARK: - Week Content

    private var weekContent: some View {
        VStack(spacing: 0) {
            weekNavigator
            weekSummaryBar

            ScrollView {
                LazyVStack(spacing: 6) {
                    if let todaySession = todaySession {
                        readinessBanner(for: todaySession)
                    }

                    let sessions = planStore.sessions(for: selectedWeek)
                        .filter { $0.workoutType != .strength }
                    ForEach(sessions) { session in
                        sessionRow(session)
                            .onTapGesture { selectedSession = session }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            if !hasInitialized {
                selectedWeek = planStore.currentWeekNumber ?? 1
                hasInitialized = true
            }
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailSheet(session: session)
        }
    }

    // MARK: - Week Navigator

    private var weekNavigator: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Week \(selectedWeek)")
                    .font(TrailFont.title)
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        if selectedWeek > 1 { selectedWeek -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(selectedWeek <= 1)

                    Button {
                        if selectedWeek < planStore.totalWeeks { selectedWeek += 1 }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(selectedWeek >= planStore.totalWeeks)

                    NavigationLink {
                        PlanCalendarView()
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                    }
                }
            }

            HStack(spacing: 8) {
                Text(weekDateRange)
                    .font(TrailFont.meta)
                    .foregroundStyle(.white.opacity(0.85))

                if planStore.currentWeekNumber == selectedWeek {
                    Text("Current")
                        .font(TrailFont.meta)
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.trailGreen)
        .tint(.white)
    }

    private var weekDateRange: String {
        let sessions = planStore.sessions(for: selectedWeek)
        guard let first = sessions.first, let last = sessions.last else { return "" }
        let start = first.scheduledDate.formatted(.dateTime.month(.abbreviated).day())
        let end = last.scheduledDate.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) \u{2013} \(end)"
    }

    // MARK: - Week Summary Bar (runs-only)

    private var weekSummaryBar: some View {
        let calendar = Calendar.current
        let weekSessions = planStore.sessions(for: selectedWeek)
        let sessions = weekSessions.filter { $0.workoutType != .strength }
        let trackableRuns = sessions.filter { $0.workoutType != .rest }
        let plannedMi = trackableRuns.compactMap(\.targetDistanceMi).reduce(0, +)
        let skipped = trackableRuns.filter { planStore.isSkipped($0.id) }.count

        var actualMi: Double = 0
        var runsDone = 0
        var countedActivityIds: Set<Int64> = []

        for session in weekSessions {
            if let activity = strava.activity(for: session.id), activity.isRun {
                actualMi += activity.distanceMi
                runsDone += 1
                countedActivityIds.insert(activity.stravaId)
            }
        }

        if let firstDate = weekSessions.first?.scheduledDate,
           let lastDate = weekSessions.last?.scheduledDate {
            for activity in strava.activities where activity.isRun && !countedActivityIds.contains(activity.stravaId) {
                if activity.activityDate >= calendar.startOfDay(for: firstDate),
                   activity.activityDate < calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDate))! {
                    actualMi += activity.distanceMi
                    runsDone += 1
                    countedActivityIds.insert(activity.stravaId)
                }
            }
        }

        return HStack(spacing: 10) {
            Label(String(format: "%.1f planned", plannedMi), systemImage: "target")
                .font(TrailFont.data)

            if actualMi > 0 {
                Label(String(format: "%.1f done", actualMi), systemImage: "checkmark.circle")
                    .font(TrailFont.data)
                    .foregroundStyle(.green)
            }

            Spacer()

            if runsDone > 0 {
                Text("\(runsDone)/\(trackableRuns.count) runs")
                    .font(TrailFont.data)
                    .foregroundStyle(.green)
            }
            if skipped > 0 {
                Text("\(skipped) skipped")
                    .font(TrailFont.data)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Session Row (≤48pt tall)

    private func sessionRow(_ session: PlannedSession) -> some View {
        let skipped = planStore.isSkipped(session.id)
        let isToday = Calendar.current.isDateInToday(session.scheduledDate)
        let activity = strava.activity(for: session.id)

        return HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(session.scheduledDate.formatted(.dateTime.weekday(.abbreviated)))
                    .font(TrailFont.meta)
                    .foregroundStyle(.secondary)
                Text("\(Calendar.current.component(.day, from: session.scheduledDate))")
                    .font(TrailFont.title)
            }
            .frame(width: 36)

            Image(systemName: session.workoutType.iconName)
                .font(.system(size: 14))
                .foregroundStyle(session.workoutType.swiftUIColor)
                .frame(width: 28, height: 28)
                .background(session.workoutType.swiftUIColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 6) {
                Text(session.workoutType.displayName)
                    .font(TrailFont.title)
                    .strikethrough(skipped)
                    .lineLimit(1)

                if let mi = session.targetDistanceMi, session.workoutType != .rest {
                    Text("·")
                        .font(TrailFont.data)
                        .foregroundStyle(.tertiary)
                    Text(String(format: "%.1f mi", mi))
                        .font(TrailFont.data)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 4)

            trailingStatus(session: session, activity: activity, skipped: skipped)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isToday ? session.workoutType.swiftUIColor.opacity(0.10) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isToday ? session.workoutType.swiftUIColor.opacity(0.35) : .clear, lineWidth: 1)
        )
        .opacity(skipped ? 0.55 : 1.0)
    }

    @ViewBuilder
    private func trailingStatus(session: PlannedSession, activity: StravaActivity?, skipped: Bool) -> some View {
        if let activity {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
                if activity.isRun {
                    Text(String(format: "%.1f", activity.distanceMi))
                        .font(TrailFont.data)
                        .foregroundStyle(.green)
                }
            }
        } else if skipped {
            Text("Skipped")
                .font(TrailFont.meta)
                .foregroundStyle(.red)
                .fontWeight(.semibold)
        } else {
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - Readiness banner (ported from former Today tab)

    private var todaySession: PlannedSession? {
        let today = Calendar.current.startOfDay(for: Date())
        return planStore.sessions(for: selectedWeek)
            .first { Calendar.current.isDate($0.scheduledDate, inSameDayAs: today) }
    }

    @ViewBuilder
    private func readinessBanner(for session: PlannedSession) -> some View {
        if let today = oura.todayReadiness(),
           today.readinessLevel == .low,
           session.workoutType != .easy,
           session.workoutType != .rest,
           session.workoutType != .recovery,
           !planStore.isSkipped(session.id),
           let easyDay = planStore.nearestEasyDay(for: session) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Low readiness (\(today.readinessScore ?? 0))")
                        .font(TrailFont.body)
                        .fontWeight(.semibold)
                }

                Text("Swap today's \(session.workoutType.displayName) with \(easyDay.scheduledDate.formatted(.dateTime.weekday(.wide)))'s \(easyDay.workoutType.displayName)?")
                    .font(TrailFont.body)
                    .foregroundStyle(.secondary)

                Button {
                    planStore.swapSessions(session, with: easyDay, reason: "Low readiness (\(today.readinessScore ?? 0))")
                    if let planId = planStore.activePlan?.id {
                        strengthStore.refreshFromPlannedSessions(planStore.sessions, planId: planId)
                    }
                } label: {
                    Label("Swap to \(easyDay.workoutType.displayName)", systemImage: "arrow.left.arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .controlSize(.small)
            }
            .padding(10)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
            )
            .padding(.bottom, 4)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundStyle(Color.trailGreen)

            Text("No plan loaded yet")
                .font(TrailFont.title)
                .foregroundStyle(.secondary)

            Text("Create a training plan to see your weekly schedule.")
                .font(TrailFont.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Set Up Your Plan") {
                showingPlanSetup = true
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .sheet(isPresented: $showingPlanSetup) {
            PlanSetupView()
        }
    }
}

#Preview {
    WeekView()
        .environment(TrainingPlanStore())
        .environment(StravaService())
        .environment(StrengthStore())
        .environment(OuraService())
}
