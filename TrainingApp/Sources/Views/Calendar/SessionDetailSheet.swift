import SwiftUI

struct SessionDetailSheet: View {
    let session: PlannedSession
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(OuraService.self) private var oura
    @Environment(\.dismiss) private var dismiss

    @State private var showingSwapTargets = false
    @State private var showingSkipOptions = false

    private var isSkipped: Bool {
        planStore.isSkipped(session.id)
    }

    private var matchedActivity: StravaActivity? {
        strava.activity(for: session.id)
    }

    private var dayRecovery: OuraDaily? {
        oura.data(for: session.scheduledDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    workoutHeader

                    if let recovery = dayRecovery {
                        recoveryRow(recovery)
                    }

                    if let distance = session.targetDistanceKm {
                        distanceRow(distance)
                    }

                    if let pace = session.targetPaceDescription, !pace.isEmpty {
                        paceRow(pace)
                    }

                    if let notes = session.notes, !notes.isEmpty {
                        notesSection(notes)
                    }

                    strengthSection

                    if let activity = matchedActivity {
                        Divider()
                        planVsActualSection(activity)
                    }

                    Divider()

                    actionsSection

                    if showingSwapTargets {
                        swapTargetsSection
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Subviews

    private var workoutHeader: some View {
        HStack {
            Image(systemName: session.workoutType.iconName)
                .font(.title2)
                .foregroundStyle(session.workoutType.swiftUIColor)
                .frame(width: 44, height: 44)
                .background(session.workoutType.swiftUIColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.workoutType.displayName)
                    .font(.title3.bold())
                    .strikethrough(isSkipped)
                    .opacity(isSkipped ? 0.5 : 1)

                Text("Week \(session.weekNumber) \u{2022} Day \(session.dayOfWeek)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSkipped {
                Text("Skipped")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.8), in: Capsule())
            } else if matchedActivity != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        }
    }

    private func recoveryRow(_ recovery: OuraDaily) -> some View {
        HStack(spacing: 16) {
            if let score = recovery.readinessScore {
                HStack(spacing: 4) {
                    Circle()
                        .fill(readinessColor(recovery.readinessLevel))
                        .frame(width: 8, height: 8)
                    Text("Readiness \(score)")
                        .font(.caption)
                }
            }
            if let sleep = recovery.sleepScore {
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text("Sleep \(sleep)")
                        .font(.caption)
                }
            }
            if let hrv = recovery.hrvAverage {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text(String(format: "HRV %.0f", hrv))
                        .font(.caption)
                }
            }
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func readinessColor(_ level: ReadinessLevel) -> Color {
        switch level {
        case .good: .green
        case .moderate: .orange
        case .low: .red
        case .unknown: .gray
        }
    }

    private func distanceRow(_ km: Double) -> some View {
        let mi = km / 1.609
        return HStack(spacing: 6) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f mi", mi))
                .font(.title2.bold())
        }
        .opacity(isSkipped ? 0.5 : 1)
    }

    private func paceRow(_ pace: String) -> some View {
        Label(pace, systemImage: "gauge.with.needle")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .opacity(isSkipped ? 0.5 : 1)
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Coach Notes")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Text(notes)
                .font(.body)
                .foregroundStyle(isSkipped ? .secondary : .primary)
        }
    }

    @ViewBuilder
    private var strengthSection: some View {
        if let strength = planStore.strengthSession(for: session),
           let notes = strength.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("Strength", systemImage: "dumbbell.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)
                Text(notes)
                    .font(.body)
                    .foregroundStyle(isSkipped ? .secondary : .primary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .opacity(isSkipped ? 0.5 : 1)
        }
    }

    // MARK: - Plan vs Actual

    private func planVsActualSection(_ activity: StravaActivity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Completed: \(activity.name)")
                    .font(.subheadline.bold())
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                comparisonCell(
                    title: "Distance",
                    actual: String(format: "%.1f mi", activity.distanceMi),
                    planned: session.targetDistanceMi.map { String(format: "%.1f mi", $0) },
                    delta: session.targetDistanceMi.map { ((activity.distanceMi - $0) / $0) * 100 }
                )

                comparisonCell(
                    title: "Pace",
                    actual: activity.formattedPace,
                    planned: nil,
                    delta: nil
                )

                comparisonCell(
                    title: "Duration",
                    actual: activity.formattedDuration,
                    planned: nil,
                    delta: nil
                )
            }

            HStack(spacing: 16) {
                if let hr = activity.averageHr {
                    Label("\(hr) bpm", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let elev = activity.elevationGainM {
                    Label(String(format: "%.0f ft", elev * 3.281), systemImage: "mountain.2.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func comparisonCell(title: String, actual: String, planned: String?, delta: Double?) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(actual)
                .font(.subheadline.bold())

            if let planned {
                Text("Plan: \(planned)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let delta, abs(delta) >= 1 {
                Text(String(format: "%+.0f%%", delta))
                    .font(.caption2.bold())
                    .foregroundStyle(delta >= 0 ? .green : .orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if isSkipped {
                Button {
                    planStore.unskipSession(session.id)
                } label: {
                    Label("Restore Session", systemImage: "arrow.uturn.backward.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            } else {
                Button {
                    showingSkipOptions = true
                } label: {
                    Label("Skip This Session", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .confirmationDialog("Skip this workout?", isPresented: $showingSkipOptions) {
                    Button("Injury") { skipWithReason("Injury") }
                    Button("Illness") { skipWithReason("Illness") }
                    Button("Life / Schedule") { skipWithReason("Life") }
                    Button("Skip (no reason)") { skipWithReason(nil) }
                    Button("Cancel", role: .cancel) {}
                }

                Button {
                    withAnimation { showingSwapTargets.toggle() }
                } label: {
                    Label(
                        showingSwapTargets ? "Cancel Swap" : "Swap With Another Day",
                        systemImage: showingSwapTargets ? "xmark" : "arrow.left.arrow.right"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
    }

    private var swapTargetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select a day to swap with:")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            let targets = planStore.sessions(for: session.weekNumber)
                .filter { $0.id != session.id && $0.workoutType != .strength }

            ForEach(targets) { target in
                Button {
                    planStore.swapSessions(session, with: target)
                    dismiss()
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
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        session.scheduledDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func skipWithReason(_ reason: String?) {
        planStore.skipSession(session.id, reason: reason)
    }
}
