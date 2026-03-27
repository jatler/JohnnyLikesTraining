import SwiftUI

struct SessionDetailSheet: View {
    let session: PlannedSession
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(OuraService.self) private var oura
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingSwapTargets = false
    @State private var showingSkipOptions = false
    @State private var isEditing = false
    @State private var editWorkoutType: WorkoutType = .easy
    @State private var editDistanceMi = ""
    @State private var editPace = ""
    @State private var editNotes = ""
    @State private var propagateToSameDay = false
    @State private var selectedStrengthDay: StrengthDaySelection?
    @State private var selectedHeatSession: HeatSession?
    @State private var sheetDetent: PresentationDetent = .large

    private var isSkipped: Bool {
        planStore.isSkipped(session.id)
    }

    private var isOverridden: Bool {
        planStore.isOverridden(session.id)
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
                    if isEditing {
                        editForm
                    } else {
                        readOnlyContent
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button("Cancel") {
                            isEditing = false
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isEditing {
                        Button("Save") { saveOverride() }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .presentationDetents([.large, .medium], selection: $sheetDetent)
        .sheet(item: $selectedStrengthDay) { selection in
            StrengthDayDetailView(weekNumber: selection.weekNumber, dayOfWeek: selection.dayOfWeek)
        }
        .sheet(item: $selectedHeatSession) { session in
            HeatLogSheet(session: session)
        }
    }

    // MARK: - Read-Only Content

    private var readOnlyContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            workoutHeader

            if let recovery = dayRecovery {
                recoveryRow(recovery)
            }

            if let distance = session.targetDistanceKm {
                distanceRow(distance)
            }

            let coachText = session.verbatimCoachNotesForDisplay
            let pace = session.targetPaceDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
            let paceRedundant = pace.map { coachText.lowercased().contains($0.lowercased()) } ?? true

            if let pace, !pace.isEmpty, !paceRedundant {
                paceRow(pace)
            }

            if !coachText.isEmpty {
                notesSection(coachText)
            }

            strengthSection

            heatSection

            if let activity = matchedActivity {
                Divider()
                planVsActualSection(activity)
            }

            Divider()

            actionsSection
            editButton

            if showingSwapTargets {
                swapTargetsSection
            }
        }
    }

    // MARK: - Edit Form

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Section {
                Text("Edit Workout")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Workout Type")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Picker("Type", selection: $editWorkoutType) {
                    ForEach(WorkoutType.allCases.filter { $0 != .strength }) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Distance (miles)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                TextField("e.g. 8.0", text: $editDistanceMi)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Effort / Pace")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                TextField("e.g. Easy effort, Z1/Z2", text: $editPace)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Coach notes")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    if editNotes.isEmpty {
                        Text("Optional — full text from your plan is kept here")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $editNotes)
                        .font(.body)
                        .frame(minHeight: 260)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(.separator), lineWidth: 1)
                )
            }

            Toggle("Apply to all \(dayOfWeekName)s", isOn: $propagateToSameDay)
                .font(.subheadline)

            if isOverridden {
                Button {
                    planStore.resetToOriginal(session.id)
                    isEditing = false
                } label: {
                    Label("Reset to Original Plan", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
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
                HStack(spacing: 6) {
                    Text(session.workoutType.displayName)
                        .font(.title3.bold())
                        .strikethrough(isSkipped)
                        .opacity(isSkipped ? 0.5 : 1)

                    if isOverridden {
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
                    if score >= 85 {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    } else {
                        Circle()
                            .fill(readinessColor(recovery.readinessLevel))
                            .frame(width: 8, height: 8)
                    }
                    Text("Readiness \(score)")
                        .font(.caption)
                }
            }
            if let sleep = recovery.sleepScore {
                HStack(spacing: 4) {
                    if sleep >= 85 {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    } else {
                        Image(systemName: "moon.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
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
            if let rhr = recovery.restingHr {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text("RHR \(rhr)")
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
            Text("Coach notes")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Text(notes)
                .font(.body)
                .foregroundStyle(isSkipped ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var strengthSection: some View {
        let daySessions = strengthStore.sessions(for: session.scheduledDate)

        if !daySessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Strength", systemImage: "dumbbell.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.swapAccent)

                    Spacer()

                    Button {
                        selectedStrengthDay = StrengthDaySelection(
                            weekNumber: session.weekNumber,
                            dayOfWeek: session.dayOfWeek
                        )
                    } label: {
                        Label("Log", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(Color.swapAccent)
                }

                ForEach(daySessions) { s in
                    HStack(spacing: 8) {
                        let complete = strengthStore.isSessionComplete(s.id)

                        if complete {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "circle")
                                .font(.caption)
                                .foregroundStyle(.quaternary)
                        }

                        Text(s.exerciseName)
                            .font(.caption)
                            .foregroundStyle(complete ? .secondary : .primary)

                        Spacer()

                        Text(formatPrescription(s))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.swapAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .opacity(isSkipped ? 0.5 : 1)
        }
    }

    private func formatPrescription(_ session: StrengthSession) -> String {
        let repsLabel = session.isTimed ? "\(session.prescribedReps)s" : "\(session.prescribedReps)"
        var text = "\(session.prescribedSets)×\(repsLabel)"
        if let kg = session.prescribedWeightKg {
            text += " @ \(Int(kg * 2.205)) lbs"
        }
        return text
    }

    @ViewBuilder
    private var heatSection: some View {
        let heatSessions = heatStore.sessions(for: session.scheduledDate)

        if !heatSessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Heat", systemImage: "flame.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)

                    Spacer()
                }

                ForEach(heatSessions) { hs in
                    let complete = heatStore.isComplete(hs.id)
                    let log = heatStore.log(for: hs.id)

                    Button {
                        selectedHeatSession = hs
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: complete ? "checkmark.circle.fill" : "flame")
                                .font(.caption)
                                .foregroundStyle(complete ? .green : .orange)

                            Text(hs.sessionType.displayName)
                                .font(.caption)

                            Spacer()

                            if let log {
                                Text("\(log.actualDurationMinutes) min")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Text("\(hs.targetDurationMinutes) min")
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
            .opacity(isSkipped ? 0.5 : 1)
        }
    }

    // MARK: - Plan vs Actual

    private func planVsActualSection(_ activity: StravaActivity) -> some View {
        return Link(destination: URL(string: "https://www.strava.com/activities/\(activity.stravaId)")!) {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Completed: \(activity.name)")
                    .font(.subheadline.bold())
                Spacer()
                if !activity.isRun {
                    Text(activity.activityTypeDisplay)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue, in: Capsule())
                }
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if activity.isRun || activity.distanceKm > 0.1 {
                    comparisonCell(
                        title: "Distance",
                        actual: String(format: "%.1f mi", activity.distanceMi),
                        planned: session.targetDistanceMi.map { String(format: "%.1f mi", $0) },
                        delta: session.targetDistanceMi.map { ((activity.distanceMi - $0) / $0) * 100 }
                    )
                }

                if activity.isRun {
                    comparisonCell(
                        title: "Pace",
                        actual: activity.formattedPace,
                        planned: nil,
                        delta: nil
                    )
                }

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

                if let elev = activity.elevationGainM, activity.isRun {
                    Label(String(format: "%.0f ft", elev * 3.281), systemImage: "mountain.2.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
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

    private var editButton: some View {
        Button {
            editWorkoutType = session.workoutType
            editDistanceMi = session.targetDistanceMi.map { String(format: "%.1f", $0) } ?? ""
            editPace = session.targetPaceDescription ?? ""
            editNotes = session.notes ?? ""
            propagateToSameDay = false
            isEditing = true
        } label: {
            Label("Edit Workout", systemImage: "pencil")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Color.swapAccent)
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

    private var dayOfWeekName: String {
        session.scheduledDate.formatted(.dateTime.weekday(.wide))
    }

    private func skipWithReason(_ reason: String?) {
        planStore.skipSession(session.id, reason: reason)
    }

    private func saveOverride() {
        let distanceKm = Double(editDistanceMi).map { $0 * 1.609 }

        planStore.overrideSession(
            session.id,
            workoutType: editWorkoutType,
            distanceKm: distanceKm,
            paceDescription: editPace.isEmpty ? nil : editPace,
            notes: editNotes.isEmpty ? nil : editNotes,
            reason: nil,
            propagateToSameDay: propagateToSameDay
        )
        isEditing = false
        dismiss()
    }
}
