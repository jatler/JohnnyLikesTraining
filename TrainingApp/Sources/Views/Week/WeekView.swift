import SwiftUI

struct WeekView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(StretchStore.self) private var stretchStore

    @State private var selectedWeek: Int = 1
    @State private var selectedSession: PlannedSession?
    @State private var hasInitialized = false
    @State private var selectedStrengthDay: StrengthDaySelection?
    @State private var selectedHeatSession: HeatSession?
    @State private var selectedStretchDay: StretchDaySelection?
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
                LazyVStack(spacing: 12) {
                    let sessions = planStore.sessions(for: selectedWeek)
                        .filter { $0.workoutType != .strength }
                    ForEach(sessions) { session in
                        sessionRow(session)
                            .onTapGesture { selectedSession = session }
                    }
                }
                .padding()
                .padding(.bottom, 20)
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
        .sheet(item: $selectedStrengthDay) { selection in
            StrengthDayDetailView(weekNumber: selection.weekNumber, dayOfWeek: selection.dayOfWeek)
        }
        .sheet(item: $selectedHeatSession) { session in
            HeatLogSheet(session: session)
        }
        .sheet(item: $selectedStretchDay) { selection in
            StretchDayDetailView(weekNumber: selection.weekNumber, dayOfWeek: selection.dayOfWeek)
        }
    }

    // MARK: - Week Navigator

    private var weekNavigator: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Week \(selectedWeek)")
                    .font(TrailFont.dataLarge)

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
                    .foregroundStyle(.secondary)

                if planStore.currentWeekNumber == selectedWeek {
                    Text("Current Week")
                        .font(TrailFont.meta)
                        .foregroundStyle(Color.trailGreen)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(.bar)
    }

    private var weekDateRange: String {
        let sessions = planStore.sessions(for: selectedWeek)
        guard let first = sessions.first, let last = sessions.last else { return "" }
        let start = first.scheduledDate.formatted(.dateTime.month(.abbreviated).day())
        let end = last.scheduledDate.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) \u{2013} \(end)"
    }

    // MARK: - Week Summary Bar

    private var weekSummaryBar: some View {
        let calendar = Calendar.current
        let weekSessions = planStore.sessions(for: selectedWeek)
        let sessions = weekSessions.filter { $0.workoutType != .strength }
        let trackableRuns = sessions.filter { $0.workoutType != .rest }
        let plannedMi = trackableRuns.compactMap(\.targetDistanceMi).reduce(0, +)
        let skipped = trackableRuns.filter { planStore.isSkipped($0.id) }.count

        // Count ALL running activities: matched + unmatched in week date range (matches Progress tab)
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

        // Cross-training hours
        var crossTrainSeconds = 0
        for session in weekSessions {
            if let activity = strava.activity(for: session.id), activity.isCrossTraining {
                crossTrainSeconds += activity.movingTimeSeconds
            }
        }
        let crossTrainHours = Double(crossTrainSeconds) / 3600.0

        let weekStrengthDates = Set(
            strengthStore.sessions
                .filter { $0.weekNumber == selectedWeek }
                .map { calendar.startOfDay(for: $0.scheduledDate) }
        )
        let strengthDone = weekStrengthDates.filter { date in
            strengthStore.isDayComplete(on: date, stravaActivities: strava.activities)
        }.count

        let weekStretchDates = Set(
            stretchStore.sessions
                .filter { $0.weekNumber == selectedWeek }
                .map { calendar.startOfDay(for: $0.scheduledDate) }
        )
        let stretchDone = weekStretchDates.filter { stretchStore.isAllComplete(on: $0) }.count

        let weekHeat = heatStore.sessions(for: selectedWeek)
        let heatDone = weekHeat.filter { heatStore.isComplete($0.id) }.count

        let totalItems = trackableRuns.count + weekStrengthDates.count + weekStretchDates.count + weekHeat.count
        let totalDone = runsDone + strengthDone + stretchDone + heatDone

        return HStack(spacing: 12) {
            Label(String(format: "%.1f mi planned", plannedMi), systemImage: "target")
                .font(TrailFont.data)

            if actualMi > 0 {
                Label(String(format: "%.1f mi done", actualMi), systemImage: "checkmark.circle")
                    .font(TrailFont.data)
                    .foregroundStyle(.green)
            }

            if crossTrainHours > 0 {
                Label(String(format: "%.1fh XT", crossTrainHours), systemImage: "figure.mixed.cardio")
                    .font(TrailFont.data)
                    .foregroundStyle(.orange)
            }

            Spacer()

            if totalDone > 0 {
                Text("\(totalDone)/\(totalItems) done")
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
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Session Row

    private func sessionRow(_ session: PlannedSession) -> some View {
        let skipped = planStore.isSkipped(session.id)
        let isToday = Calendar.current.isDateInToday(session.scheduledDate)
        let activity = strava.activity(for: session.id)
        let overridden = planStore.isOverridden(session.id)
        let daySessions = strengthStore.sessions(for: session.scheduledDate)
        let dayHeat = heatStore.sessions(for: session.scheduledDate)
        let dayStretch = stretchStore.sessions(for: session.scheduledDate)

        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(session.scheduledDate.formatted(.dateTime.weekday(.abbreviated)))
                    .font(TrailFont.meta)
                    .foregroundStyle(.secondary)
                Text("\(Calendar.current.component(.day, from: session.scheduledDate))")
                    .font(TrailFont.title)
            }
            .frame(width: 40)

            Image(systemName: session.workoutType.iconName)
                .font(TrailFont.body)
                .foregroundStyle(session.workoutType.swiftUIColor)
                .frame(width: 32, height: 32)
                .background(session.workoutType.swiftUIColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.workoutType.displayName)
                        .font(TrailFont.title)
                        .strikethrough(skipped)

                    if overridden {
                        Image(systemName: "pencil.circle.fill")
                            .font(TrailFont.meta)
                            .foregroundStyle(.orange)
                    }
                }

                if let mi = session.targetDistanceMi {
                    Text(String(format: "%.1f mi", mi))
                        .font(TrailFont.data)
                        .foregroundStyle(.secondary)
                }

                if let pace = session.targetPaceDescription, !pace.isEmpty {
                    Text(pace)
                        .font(TrailFont.data)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if !daySessions.isEmpty || !dayHeat.isEmpty || !dayStretch.isEmpty {
                    HStack(spacing: 8) {
                        if !daySessions.isEmpty {
                            let completed = strengthStore.completedExerciseCount(for: session.scheduledDate)
                            let total = daySessions.count
                            let allDone = completed == total

                            HStack(spacing: 3) {
                                Image(systemName: "dumbbell.fill")
                                if allDone {
                                    Image(systemName: "checkmark.circle.fill")
                                } else {
                                    Text("\(completed)/\(total)")
                                }
                            }
                            .font(TrailFont.meta)
                            .foregroundStyle(allDone ? .green : Color.trailGreen)
                        }

                        if let heat = dayHeat.first {
                            Button {
                                selectedHeatSession = heat
                            } label: {
                                let done = heatStore.isComplete(heat.id)
                                HStack(spacing: 3) {
                                    Image(systemName: "flame.fill")
                                    if done {
                                        Image(systemName: "checkmark.circle.fill")
                                    } else {
                                        Text("\(heat.targetDurationMinutes)m")
                                    }
                                }
                                .font(TrailFont.meta)
                                .foregroundStyle(done ? .green : .orange)
                            }
                            .buttonStyle(.plain)
                        }

                        if !dayStretch.isEmpty {
                            Button {
                                selectedStretchDay = StretchDaySelection(
                                    weekNumber: session.weekNumber,
                                    dayOfWeek: session.dayOfWeek
                                )
                            } label: {
                                let completed = stretchStore.completedCount(for: session.scheduledDate)
                                let total = dayStretch.count
                                let allDone = completed == total

                                HStack(spacing: 3) {
                                    Image(systemName: "figure.flexibility")
                                    if allDone {
                                        Image(systemName: "checkmark.circle.fill")
                                    } else {
                                        Text("\(completed)/\(total)")
                                    }
                                }
                                .font(TrailFont.meta)
                                .foregroundStyle(allDone ? .green : Color.trailGreen)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .lineLimit(1)
                    .padding(.top, 2)
                }
            }

            Spacer()

            if let activity {
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    if activity.isRun {
                        Text(String(format: "%.1f mi", activity.distanceMi))
                            .font(TrailFont.data)
                            .foregroundStyle(.green)
                    } else {
                        Text(activity.activityTypeDisplay)
                            .font(TrailFont.data)
                            .foregroundStyle(.green)
                    }
                }
            } else if skipped {
                Text("Skipped")
                    .font(TrailFont.meta)
                    .foregroundStyle(.red)
                    .fontWeight(.semibold)
            }

            Image(systemName: "chevron.right")
                .font(TrailFont.meta)
                .foregroundStyle(.quaternary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isToday ? session.workoutType.swiftUIColor.opacity(0.08) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isToday ? session.workoutType.swiftUIColor.opacity(0.3) : .clear, lineWidth: 1)
        )
        .opacity(skipped ? 0.6 : 1.0)
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
                .font(TrailFont.detail)
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
        .environment(HeatStore())
        .environment(StretchStore())
}
