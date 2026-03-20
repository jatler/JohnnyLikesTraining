import SwiftUI

struct TodayView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(OuraService.self) private var oura

    @State private var showingPlanSetup = false
    @State private var showingPlanEdit = false
    @State private var showingSwapConfirmation = false
    @State private var showingSkipOptions = false
    @State private var showingSwapPicker = false

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
                recoveryCard

                let todaySessions = planStore.todaySessions
                    .filter { $0.workoutType != .strength }
                if todaySessions.isEmpty {
                    noSessionToday
                } else {
                    ForEach(todaySessions) { session in
                        sessionCard(session)

                        if let activity = strava.activity(for: session.id) {
                            stravaComparisonBanner(session: session, activity: activity)
                        }

                        readinessSwapSuggestion(for: session)
                        sessionActions(session)
                    }
                }

                if let plan = planStore.activePlan {
                    planInfoBar(plan)
                }
            }
            .padding()
        }
    }

    // MARK: - Recovery Card (Oura)

    @ViewBuilder
    private var recoveryCard: some View {
        if let today = oura.todayReadiness() {
            VStack(spacing: 12) {
                HStack {
                    Text("Recovery")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    readinessBadge(today.readinessLevel)
                }

                HStack(spacing: 20) {
                    recoveryMetric(
                        title: "Readiness",
                        value: today.readinessScore.map { "\($0)" } ?? "—",
                        color: readinessColor(today.readinessLevel)
                    )
                    recoveryMetric(
                        title: "Sleep",
                        value: today.sleepScore.map { "\($0)" } ?? "—",
                        color: .blue
                    )
                    recoveryMetric(
                        title: "HRV",
                        value: today.hrvAverage.map { String(format: "%.0f", $0) } ?? "—",
                        color: .purple
                    )
                    recoveryMetric(
                        title: "RHR",
                        value: today.restingHr.map { "\($0)" } ?? "—",
                        color: .red
                    )
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        } else if oura.isConnected {
            HStack {
                Image(systemName: "heart.circle")
                    .foregroundStyle(.purple)
                Text("No recovery data for today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func recoveryMetric(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func readinessBadge(_ level: ReadinessLevel) -> some View {
        Text(level.label)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(readinessColor(level), in: Capsule())
    }

    private func readinessColor(_ level: ReadinessLevel) -> Color {
        switch level {
        case .good: .green
        case .moderate: .orange
        case .low: .red
        case .unknown: .gray
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

    // MARK: - Strava Comparison Banner

    private func stravaComparisonBanner(session: PlannedSession, activity: StravaActivity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Completed")
                    .font(.subheadline.bold())
                Spacer()
                Text(activity.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(String(format: "%.1f", activity.distanceMi))
                            .font(.subheadline.bold())
                        if let target = session.targetDistanceMi {
                            Text("/ \(String(format: "%.1f", target)) mi")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            distanceDelta(actual: activity.distanceMi, target: target)
                        } else {
                            Text("mi")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider().frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pace")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(activity.formattedPace)
                        .font(.subheadline.bold())
                }

                Divider().frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(activity.formattedDuration)
                        .font(.subheadline.bold())
                }
            }
        }
        .padding()
        .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.green.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func distanceDelta(actual: Double, target: Double) -> some View {
        let delta = actual - target
        let pct = (delta / target) * 100
        if abs(pct) >= 1 {
            Text(String(format: "%+.0f%%", pct))
                .font(.caption2.bold())
                .foregroundStyle(delta >= 0 ? .green : .orange)
        }
    }

    // MARK: - Session Card

    private func sessionCard(_ session: PlannedSession) -> some View {
        let skipped = planStore.isSkipped(session.id)
        let strength = planStore.strengthSession(for: session)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(session.workoutType.displayName, systemImage: session.workoutType.iconName)
                    .font(.headline)
                    .foregroundStyle(session.workoutType.swiftUIColor)
                    .strikethrough(skipped)

                Spacer()

                if skipped {
                    Text("Skipped")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red.opacity(0.8), in: Capsule())
                } else {
                    Text("Week \(session.weekNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let distance = session.targetDistanceMi {
                HStack(spacing: 4) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f mi", distance))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .opacity(skipped ? 0.5 : 1)
            }

            if let pace = session.targetPaceDescription, !pace.isEmpty {
                Label(pace, systemImage: "gauge.with.needle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(skipped ? 0.5 : 1)
            }

            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .opacity(skipped ? 0.5 : 1)
            }

            if let strength, let strengthNotes = strength.notes, !strengthNotes.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(.indigo)
                    Text(strengthNotes)
                        .font(.subheadline)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .opacity(skipped ? 0.5 : 1)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Session Actions

    private func sessionActions(_ session: PlannedSession) -> some View {
        let skipped = planStore.isSkipped(session.id)

        return VStack(spacing: 10) {
            if skipped {
                Button {
                    planStore.unskipSession(session.id)
                } label: {
                    Label("Restore Session", systemImage: "arrow.uturn.backward.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            } else {
                quickSwapButton(for: session)

                HStack(spacing: 10) {
                    Button {
                        showingSkipOptions = true
                    } label: {
                        Label("Skip", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
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
                    .tint(.blue)
                    .sheet(isPresented: $showingSwapPicker) {
                        swapPickerSheet(for: session)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func quickSwapButton(for session: PlannedSession) -> some View {
        let isHardSession = session.workoutType != .easy
            && session.workoutType != .rest
            && session.workoutType != .recovery

        if isHardSession, let easyDay = planStore.nearestEasyDay(for: session) {
            Button {
                showingSwapConfirmation = true
            } label: {
                Label(
                    "Quick Swap \u{2192} \(easyDay.workoutType.displayName) (\(easyDay.scheduledDate.formatted(.dateTime.weekday(.abbreviated))))",
                    systemImage: "arrow.left.arrow.right.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .alert("Swap Workouts?", isPresented: $showingSwapConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Swap") {
                    planStore.swapSessions(session, with: easyDay, reason: "Quick swap")
                }
            } message: {
                Text("Swap today's \(session.workoutType.displayName) with \(easyDay.scheduledDate.formatted(.dateTime.weekday(.wide)))'s \(easyDay.workoutType.displayName)?")
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
                .foregroundStyle(.blue)

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
                Label("Create Training Plan", systemImage: "plus.circle.fill")
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
}
