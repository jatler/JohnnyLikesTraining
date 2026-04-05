import SwiftUI

struct TodayView: View {
    @Environment(AuthService.self) private var auth
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(OuraService.self) private var oura
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(StretchStore.self) private var stretchStore

    @State private var showingPlanSetup = false
    @State private var showingPlanEdit = false
    @State private var showingSwapConfirmation = false
    @State private var showingSkipOptions = false
    @State private var showingSwapPicker = false
    @State private var showingStrengthDay = false
    @State private var selectedHeatSession: HeatSession?
    @State private var showingStretchDay = false
    @State private var selectedSession: PlannedSession?

    var body: some View {
        NavigationStack {
            Group {
                if planStore.hasPlan {
                    todayContent
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
            .sheet(isPresented: $showingPlanSetup) {
                PlanSetupView()
            }
            .sheet(isPresented: $showingPlanEdit) {
                if let plan = planStore.activePlan {
                    PlanEditView(plan: plan, template: planStore.currentTemplate)
                }
            }
        }
    }

    // MARK: - Today's Content

    private var todayHeader: some View {
        let todaySessions = planStore.todaySessions.filter { $0.workoutType != .strength }
        let firstSession = todaySessions.first
        let skipped = firstSession.map { planStore.isSkipped($0.id) } ?? false
        let hasMatch = firstSession.flatMap { strava.activity(for: $0.id) } != nil

        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(firstSession?.workoutType.displayName ?? "Rest Day")
                    .font(TrailFont.dataLarge)
                    .strikethrough(skipped)
                    .opacity(skipped ? 0.5 : 1)
                HStack(spacing: 8) {
                    if let mi = firstSession?.targetDistanceMi {
                        Text(String(format: "%.1f mi", mi))
                            .font(TrailFont.data)
                            .foregroundStyle(.secondary)
                    }
                    if let s = firstSession {
                        Text("Week \(s.weekNumber) \u{2022} Day \(s.dayOfWeek)")
                            .font(TrailFont.meta)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if skipped {
                Text("Skipped")
                    .font(TrailFont.meta)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.8), in: Capsule())
            } else if hasMatch {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(TrailFont.title)
            }
        }
        .padding()
        .background(.bar)
    }

    private var todayContent: some View {
        VStack(spacing: 0) {
            todayHeader

            ScrollView {
                VStack(spacing: 20) {
                    let todaySessions = planStore.todaySessions
                        .filter { $0.workoutType != .strength }

                    if todaySessions.isEmpty {
                    if oura.isConnected, let recovery = oura.todayReadiness() {
                        SessionComponents.recoveryRow(recovery)
                    }
                    noSessionToday
                } else {
                    ForEach(Array(todaySessions.enumerated()), id: \.element.id) { index, session in
                        sessionBlock(session, isFirst: index == 0)
                    }
                }

                tuesdayBanner

                if let plan = planStore.activePlan {
                    planInfoBar(plan)
                }
            }
            .padding()
        }
        .refreshable {
            guard let userId = auth.currentUserId else { return }
            var mondayCal = Calendar.current
            mondayCal.firstWeekday = 2 // Monday
            let weekStart = mondayCal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            if strava.isConnected {
                try? await strava.syncActivities(userId: userId, after: weekStart, merge: true)
                strava.autoMatchActivities(sessions: planStore.sessions)
            }
            if oura.isConnected {
                try? await oura.syncDaily(userId: userId, days: 7, merge: true)
            }
        }
        .sheet(item: $selectedHeatSession) { session in
            HeatLogSheet(session: session)
        }
        .sheet(isPresented: $showingStretchDay) {
            if let week = planStore.currentWeekNumber {
                let dayOfWeek = Calendar.current.component(.weekday, from: Date())
                let adjustedDay = dayOfWeek == 1 ? 7 : dayOfWeek - 1
                StretchDayDetailView(weekNumber: week, dayOfWeek: adjustedDay)
            }
        }
        .sheet(isPresented: $showingStrengthDay) {
            if let week = planStore.currentWeekNumber {
                let dayOfWeek = Calendar.current.component(.weekday, from: Date())
                let adjustedDay = dayOfWeek == 1 ? 7 : dayOfWeek - 1
                StrengthDayDetailView(weekNumber: week, dayOfWeek: adjustedDay)
            }
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailSheet(session: session)
        }
        }
    }

    // MARK: - Per-Session Block

    @ViewBuilder
    private func sessionBlock(_ session: PlannedSession, isFirst: Bool) -> some View {
        let skipped = planStore.isSkipped(session.id)
        let overridden = planStore.isOverridden(session.id)
        let activity = strava.activity(for: session.id)
        let hasStravaMatch = activity != nil

        VStack(alignment: .leading, spacing: 20) {
            let coachText = session.verbatimCoachNotesForDisplay
            let pace = session.targetPaceDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
            let paceRedundant = pace.map { coachText.lowercased().contains($0.lowercased()) } ?? true

            if let pace, !pace.isEmpty, !paceRedundant {
                Label(pace, systemImage: "gauge.with.needle")
                    .font(TrailFont.data)
                    .foregroundStyle(.secondary)
                    .opacity(skipped ? 0.5 : 1)
            }

            if !coachText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Coach notes")
                        .font(TrailFont.title)
                        .foregroundStyle(.secondary)
                    Text(coachText)
                        .font(TrailFont.coach)
                        .foregroundStyle(skipped ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            // Strava activity (directly after coach notes)
            if let activity {
                SessionComponents.planVsActualSection(session: session, activity: activity)
            }

            // Ancillary sections (first session only)
            if isFirst {
                inlineHeatSection
                inlineStrengthSection
                inlineStretchSection
            }

            readinessSwapSuggestion(for: session)

            // Oura recovery
            if isFirst, oura.isConnected, let recovery = oura.todayReadiness() {
                SessionComponents.recoveryRow(recovery)
            }

            if !hasStravaMatch {
                Divider()
                sessionActions(session)
            }
        }
    }

    // MARK: - Tuesday Banner

    @ViewBuilder
    private var tuesdayBanner: some View {
        if Calendar.current.component(.weekday, from: Date()) == 3 {
            Link(destination: URL(string: "https://open.spotify.com/show/3AaJYZngimocFf8aztKTcO")!) {
                HStack(spacing: 12) {
                    Image(systemName: "headphones")
                        .font(.title2)
                        .foregroundStyle(Color.trailGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Happy Tuesday! It's Tuesday!!!")
                            .font(TrailFont.title)
                            .foregroundStyle(.primary)
                        Text("Listen to the latest SWAP podcast ↗")
                            .font(TrailFont.detail)
                            .foregroundStyle(Color.trailGreen)
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color.trailGreenLight, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Readiness-Based Swap Suggestion

    @ViewBuilder
    private func readinessSwapSuggestion(for session: PlannedSession) -> some View {
        if let today = oura.todayReadiness(),
           today.readinessLevel == .low,
           session.workoutType != .easy && session.workoutType != .rest && session.workoutType != .recovery,
           !planStore.isSkipped(session.id),
           let easyDay = planStore.nearestEasyDay(for: session) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Low Readiness (\(today.readinessScore ?? 0))")
                        .font(TrailFont.detailBold)
                }

                Text("Consider swapping today's \(session.workoutType.displayName) for \(easyDay.scheduledDate.formatted(.dateTime.weekday(.wide)))'s \(easyDay.workoutType.displayName).")
                    .font(TrailFont.detail)
                    .foregroundStyle(.secondary)

                Button {
                    planStore.swapSessions(session, with: easyDay, reason: "Low readiness (\(today.readinessScore ?? 0))")
                } label: {
                    Label("Swap to \(easyDay.workoutType.displayName)", systemImage: "arrow.left.arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                        .font(TrailFont.detailBold)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
            .padding()
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Inline Strength Section

    @ViewBuilder
    private var inlineStrengthSection: some View {
        let today = Date()
        let daySessions = strengthStore.sessions(for: today)

        if !daySessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Strength", systemImage: "dumbbell.fill")
                        .font(TrailFont.detailBold)
                        .foregroundStyle(Color.trailGreen)

                    Spacer()

                    let completed = strengthStore.completedExerciseCount(for: today)
                    let total = daySessions.count

                    if completed > 0 {
                        Text("\(completed)/\(total) done")
                            .font(TrailFont.meta)
                            .foregroundStyle(.green)
                    }

                    Button {
                        showingStrengthDay = true
                    } label: {
                        Label("Log", systemImage: "checkmark.circle")
                            .font(TrailFont.meta)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(Color.trailGreen)
                }

                ForEach(daySessions) { session in
                    HStack(spacing: 8) {
                        let complete = strengthStore.isSessionComplete(session.id)

                        Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                            .font(TrailFont.meta)
                            .foregroundStyle(complete ? .green : Color.secondary.opacity(0.3))

                        Text(session.exerciseName)
                            .font(TrailFont.meta)
                            .foregroundStyle(complete ? .secondary : .primary)

                        Spacer()

                        Text(strengthPrescription(session))
                            .font(TrailFont.data)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.trailGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Inline Stretch Section

    @ViewBuilder
    private var inlineStretchSection: some View {
        let today = Date()
        let daySessions = stretchStore.sessions(for: today)

        if !daySessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Stretches", systemImage: "figure.flexibility")
                        .font(TrailFont.detailBold)
                        .foregroundStyle(Color.trailGreen)

                    Spacer()

                    let completed = stretchStore.completedCount(for: today)
                    let total = daySessions.count

                    if completed > 0 {
                        Text("\(completed)/\(total) done")
                            .font(TrailFont.meta)
                            .foregroundStyle(.green)
                    }

                    Button {
                        showingStretchDay = true
                    } label: {
                        Label("Log", systemImage: "checkmark.circle")
                            .font(TrailFont.meta)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(Color.trailGreen)
                }

                ForEach(daySessions) { session in
                    HStack(spacing: 8) {
                        let complete = stretchStore.isComplete(session.id)

                        Button {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            if complete {
                                stretchStore.removeLog(sessionId: session.id)
                            } else {
                                stretchStore.logCompletion(sessionId: session.id)
                            }
                        } label: {
                            Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                                .font(TrailFont.meta)
                                .foregroundStyle(complete ? .green : Color.secondary.opacity(0.3))
                        }
                        .buttonStyle(.plain)

                        Text(session.stretchName)
                            .font(TrailFont.meta)
                            .foregroundStyle(complete ? .secondary : .primary)

                        Spacer()

                        if session.isBilateral {
                            Text("L+R")
                                .font(TrailFont.metaBold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                        }

                        Text(stretchPrescription(session))
                            .font(TrailFont.data)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.trailGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Inline Heat Section

    @ViewBuilder
    private var inlineHeatSection: some View {
        let today = Date()
        let heatSessions = heatStore.sessions(for: today)

        if !heatSessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Heat", systemImage: "flame.fill")
                        .font(TrailFont.detailBold)
                        .foregroundStyle(.orange)

                    Spacer()
                }

                ForEach(heatSessions) { session in
                    let complete = heatStore.isComplete(session.id)
                    let log = heatStore.log(for: session.id)

                    Button {
                        selectedHeatSession = session
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: complete ? "checkmark.circle.fill" : "flame")
                                .font(TrailFont.meta)
                                .foregroundStyle(complete ? .green : .orange)

                            Text(session.sessionType.displayName)
                                .font(TrailFont.meta)

                            Spacer()

                            if let log {
                                Text("\(log.actualDurationMinutes) min")
                                    .font(TrailFont.data)
                                    .foregroundStyle(.green)
                            } else {
                                Text("\(session.targetDurationMinutes) min")
                                    .font(TrailFont.data)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Helpers

    private func strengthPrescription(_ session: StrengthSession) -> String {
        let repsLabel = session.isTimed ? "\(session.prescribedReps)s" : "\(session.prescribedReps)"
        var text = "\(session.prescribedSets)×\(repsLabel)"
        if let kg = session.prescribedWeightKg {
            text += " @ \(Int(kg * 2.205)) lbs"
        }
        return text
    }

    private func stretchPrescription(_ session: StretchSession) -> String {
        let perSide = session.isBilateral ? " each side" : ""
        return "\(session.prescribedSets)×\(session.prescribedHoldSeconds)s\(perSide)"
    }

    // MARK: - Session Actions

    private func sessionActions(_ session: PlannedSession) -> some View {
        let skipped = planStore.isSkipped(session.id)

        return VStack(spacing: 10) {
            if skipped {
                Button {
                    planStore.unskipSession(session.id)
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            } else {
                HStack(spacing: 8) {
                    Button {
                        showingSkipOptions = true
                    } label: {
                        Label("Skip", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .confirmationDialog("Skip this workout?", isPresented: $showingSkipOptions) {
                        Button("Injury") { planStore.skipSession(session.id, reason: "Injury") }
                        Button("Illness") { planStore.skipSession(session.id, reason: "Illness") }
                        Button("Life / Schedule") { planStore.skipSession(session.id, reason: "Life") }
                        Button("Skip (no reason)") { planStore.skipSession(session.id, reason: nil) }
                        Button("Cancel", role: .cancel) {}
                    }

                    Button {
                        showingSwapPicker = true
                    } label: {
                        Label("Swap", systemImage: "arrow.left.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .sheet(isPresented: $showingSwapPicker) {
                        swapPickerSheet(for: session)
                    }

                    Button {
                        selectedSession = session
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                }
            }
        }
    }

    // MARK: - Swap Picker Sheet

    private func swapPickerSheet(for session: PlannedSession) -> some View {
        NavigationStack {
            List {
                let targets = planStore.sessions(for: session.weekNumber)
                    .filter { $0.id != session.id && $0.workoutType != .strength }

                ForEach(targets) { target in
                    Button {
                        planStore.swapSessions(session, with: target)
                        showingSwapPicker = false
                    } label: {
                        HStack {
                            Image(systemName: target.workoutType.iconName)
                                .foregroundStyle(target.workoutType.swiftUIColor)
                                .frame(width: 28)

                            VStack(alignment: .leading) {
                                Text(target.scheduledDate.formatted(.dateTime.weekday(.wide)))
                                    .font(TrailFont.detailBold)
                                Text(target.workoutType.displayName)
                                    .font(TrailFont.meta)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let mi = target.targetDistanceMi {
                                Text(String(format: "%.1f mi", mi))
                                    .font(TrailFont.data)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Swap With")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingSwapPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - No Session Today

    private var noSessionToday: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("No workout scheduled today")
                .font(TrailFont.title)
                .foregroundStyle(.secondary)
            if let plan = planStore.activePlan {
                let today = Calendar.current.startOfDay(for: Date())
                let planStart = Calendar.current.startOfDay(for: plan.planStartDate)
                if today < planStart {
                    Text("Your plan starts \(plan.planStartDate.formatted(date: .long, time: .omitted))")
                        .font(TrailFont.detail)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 40)
    }

    // MARK: - Plan Info Bar

    private func planInfoBar(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(plan.name)
                    .font(TrailFont.title)

                Spacer()

                Button {
                    showingPlanEdit = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(TrailFont.title)
                }
            }

            HStack {
                Label("Race: \(plan.raceDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "flag.fill")
                Spacer()
                if let week = planStore.currentWeekNumber {
                    Text("Week \(week)")
                        .fontWeight(.medium)
                }
            }
            .font(TrailFont.detail)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.run")
                .font(.system(size: 48))
                .foregroundStyle(Color.trailGreen)

            Text("No training plan yet")
                .font(TrailFont.title)
                .foregroundStyle(.secondary)

            Text("Set up a plan for your next race to see daily workouts.")
                .font(TrailFont.detail)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingPlanSetup = true
            } label: {
                Label("Add Training Plan", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }
}

#Preview("No Plan") {
    TodayView()
        .environment(AuthService())
        .environment(TrainingPlanStore())
        .environment(StravaService())
        .environment(OuraService())
        .environment(StrengthStore())
        .environment(HeatStore())
        .environment(StretchStore())
}
