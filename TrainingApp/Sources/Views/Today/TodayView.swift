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
            .navigationTitle("Today")
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

    private var todayContent: some View {
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

                weeklyMileageSummary

                tuesdayBanner

                if let plan = planStore.activePlan {
                    planInfoBar(plan)
                }
            }
            .padding()
        }
        .refreshable {
            guard let userId = auth.currentUserId else { return }
            if strava.isConnected {
                try? await strava.syncActivities(userId: userId)
                strava.autoMatchActivities(sessions: planStore.sessions)
            }
            if oura.isConnected {
                try? await oura.syncDaily(userId: userId)
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

    // MARK: - Per-Session Block

    @ViewBuilder
    private func sessionBlock(_ session: PlannedSession, isFirst: Bool) -> some View {
        let skipped = planStore.isSkipped(session.id)
        let overridden = planStore.isOverridden(session.id)
        let activity = strava.activity(for: session.id)
        let hasStravaMatch = activity != nil

        VStack(alignment: .leading, spacing: 20) {
            // Workout header
            HStack {
                Image(systemName: session.workoutType.iconName)
                    .font(.title2)
                    .foregroundStyle(session.workoutType.swiftUIColor)
                    .frame(width: 44, height: 44)
                    .background(session.workoutType.swiftUIColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(session.workoutType.displayName)
                            .font(.title3.bold())
                            .strikethrough(skipped)
                            .opacity(skipped ? 0.5 : 1)

                        if overridden {
                            Image(systemName: "pencil.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Text("Week \(session.weekNumber) \u{2022} Day \(session.dayOfWeek)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if skipped {
                    Text("Skipped")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red.opacity(0.8), in: Capsule())
                } else if hasStravaMatch {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }

            if let distanceKm = session.targetDistanceKm {
                HStack(spacing: 6) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f mi", DistanceFormatter.miles(from: distanceKm)))
                        .font(.title2.bold())
                }
                .opacity(skipped ? 0.5 : 1)
            }

            let coachText = session.verbatimCoachNotesForDisplay
            let pace = session.targetPaceDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
            let paceRedundant = pace.map { coachText.lowercased().contains($0.lowercased()) } ?? true

            if let pace, !pace.isEmpty, !paceRedundant {
                Label(pace, systemImage: "gauge.with.needle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(skipped ? 0.5 : 1)
            }

            if !coachText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Coach notes")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text(coachText)
                        .font(.body)
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
                Divider()
                SessionComponents.recoveryRow(recovery)
            }

            if !hasStravaMatch {
                Divider()
                sessionActions(session)
            }
        }
    }

    // MARK: - Weekly Mileage Summary

    @ViewBuilder
    private var weeklyMileageSummary: some View {
        if let week = planStore.currentWeekNumber {
            let weekSessions = planStore.sessions(for: week)
                .filter { $0.workoutType != .strength && $0.workoutType != .rest }
            let plannedMi = weekSessions.compactMap(\.targetDistanceMi).reduce(0, +)
            let actualMi = weekSessions.compactMap { session -> Double? in
                guard let activity = strava.activity(for: session.id), activity.isRun else { return nil }
                return activity.distanceMi
            }.reduce(0, +)

            if plannedMi > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Week \(week) Mileage")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f / %.0f mi", actualMi, plannedMi))
                            .font(.subheadline)
                            .foregroundStyle(actualMi > 0 ? .primary : .secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.swapAccent)
                                .frame(width: geo.size.width * min(actualMi / plannedMi, 1.0), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
                        .foregroundStyle(Color.swapAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Happy Tuesday! It's Tuesday!!!")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Listen to the latest SWAP podcast ↗")
                            .font(.subheadline)
                            .foregroundStyle(Color.swapAccent)
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color.swapAccentLight, in: RoundedRectangle(cornerRadius: 12))
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
                        .font(.subheadline.bold())
                }

                Text("Consider swapping today's \(session.workoutType.displayName) for \(easyDay.scheduledDate.formatted(.dateTime.weekday(.wide)))'s \(easyDay.workoutType.displayName).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    planStore.swapSessions(session, with: easyDay, reason: "Low readiness (\(today.readinessScore ?? 0))")
                } label: {
                    Label("Swap to \(easyDay.workoutType.displayName)", systemImage: "arrow.left.arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                        .font(.subheadline.bold())
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
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.swapAccent)

                    Spacer()

                    let completed = strengthStore.completedExerciseCount(for: today)
                    let total = daySessions.count

                    if completed > 0 {
                        Text("\(completed)/\(total) done")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    Button {
                        showingStrengthDay = true
                    } label: {
                        Label("Log", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(Color.swapAccent)
                }

                ForEach(daySessions) { session in
                    HStack(spacing: 8) {
                        let complete = strengthStore.isSessionComplete(session.id)

                        Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(complete ? .green : Color.secondary.opacity(0.3))

                        Text(session.exerciseName)
                            .font(.caption)
                            .foregroundStyle(complete ? .secondary : .primary)

                        Spacer()

                        Text(strengthPrescription(session))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.swapAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
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
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.swapAccent)

                    Spacer()

                    let completed = stretchStore.completedCount(for: today)
                    let total = daySessions.count

                    if completed > 0 {
                        Text("\(completed)/\(total) done")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    Button {
                        showingStretchDay = true
                    } label: {
                        Label("Log", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(Color.swapAccent)
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
                                .font(.caption)
                                .foregroundStyle(complete ? .green : Color.secondary.opacity(0.3))
                        }
                        .buttonStyle(.plain)

                        Text(session.stretchName)
                            .font(.caption)
                            .foregroundStyle(complete ? .secondary : .primary)

                        Spacer()

                        if session.isBilateral {
                            Text("L+R")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                        }

                        Text(stretchPrescription(session))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.swapAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
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
                        .font(.subheadline.bold())
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
                                .font(.caption)
                                .foregroundStyle(complete ? .green : .orange)

                            Text(session.sessionType.displayName)
                                .font(.caption)

                            Spacer()

                            if let log {
                                Text("\(log.actualDurationMinutes) min")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Text("\(session.targetDurationMinutes) min")
                                    .font(.caption)
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
                                    .font(.subheadline.bold())
                                Text(target.workoutType.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let mi = target.targetDistanceMi {
                                Text(String(format: "%.1f mi", mi))
                                    .font(.caption)
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
                .font(.title3)
                .foregroundStyle(.secondary)
            if let plan = planStore.activePlan {
                let today = Calendar.current.startOfDay(for: Date())
                let planStart = Calendar.current.startOfDay(for: plan.planStartDate)
                if today < planStart {
                    Text("Your plan starts \(plan.planStartDate.formatted(date: .long, time: .omitted))")
                        .font(.subheadline)
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
                    .font(.headline)

                Spacer()

                Button {
                    showingPlanEdit = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.title3)
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
            .font(.subheadline)
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
                .foregroundStyle(Color.swapAccent)

            Text("No training plan yet")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Set up a plan for your next race to see daily workouts.")
                .font(.subheadline)
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
