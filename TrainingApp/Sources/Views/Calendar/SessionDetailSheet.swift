import SwiftUI

struct SessionDetailSheet: View {
    let session: PlannedSession
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(OuraService.self) private var oura
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(StretchStore.self) private var stretchStore
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

            stretchSection

            heatSection

            if let recovery = dayRecovery {
                Divider()
                SessionComponents.recoveryRow(recovery)
            }

            if let activity = matchedActivity {
                Divider()
                SessionComponents.planVsActualSection(session: session, activity: activity)
            }

            Divider()

            actionsSection

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
                        .font(.headline)
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

    private func distanceRow(_ km: Double) -> some View {
        let mi = DistanceFormatter.miles(from: km)
        return HStack(spacing: 6) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f mi", mi))
                .font(.headline)
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
                            .font(.caption)
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
    private var stretchSection: some View {
        let daySessions = stretchStore.sessions(for: session.scheduledDate)

        if !daySessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Stretches", systemImage: "figure.flexibility")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.swapAccent)

                    Spacer()

                    let completed = stretchStore.completedCount(for: session.scheduledDate)
                    let total = daySessions.count

                    if completed > 0 {
                        Text("\(completed)/\(total) done")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                ForEach(daySessions) { s in
                    HStack(spacing: 8) {
                        let complete = stretchStore.isComplete(s.id)

                        Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(complete ? .green : Color.secondary.opacity(0.3))

                        Text(s.stretchName)
                            .font(.caption)
                            .foregroundStyle(complete ? .secondary : .primary)

                        Spacer()

                        if s.isBilateral {
                            Text("L+R")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }

                        Text("\(s.prescribedSets)×\(s.prescribedHoldSeconds)s")
                            .font(.caption)
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

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if isSkipped {
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
                        Button("Injury") { skipWithReason("Injury") }
                        Button("Illness") { skipWithReason("Illness") }
                        Button("Life / Schedule") { skipWithReason("Life") }
                        Button("Skip (no reason)") { skipWithReason(nil) }
                        Button("Cancel", role: .cancel) {}
                    }

                    Button {
                        withAnimation { showingSwapTargets.toggle() }
                    } label: {
                        Label("Swap", systemImage: "arrow.left.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)

                    Button {
                        editWorkoutType = session.workoutType
                        editDistanceMi = session.targetDistanceMi.map { String(format: "%.1f", $0) } ?? ""
                        editPace = session.targetPaceDescription ?? ""
                        editNotes = session.notes ?? ""
                        propagateToSameDay = false
                        isEditing = true
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
        let distanceKm = Double(editDistanceMi).map { $0 / 0.621371 }

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
