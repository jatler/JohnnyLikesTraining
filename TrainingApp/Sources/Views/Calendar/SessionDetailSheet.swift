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
    @State private var editAthleteNotes = ""
    @State private var selectedStrengthDay: StrengthDaySelection?
    @State private var selectedHeatSession: HeatSession?

    private var isSkipped: Bool {
        planStore.isSkipped(session.id)
    }

    private var isOverridden: Bool {
        planStore.isOverridden(session.id)
    }

    private var isManuallyComplete: Bool {
        planStore.isManuallyComplete(session.id)
    }

    /// True when the user has either matched a Strava activity to this session
    /// or manually pressed Mark Done. The two sources both light up the same
    /// green check in the trailing slot.
    private var isComplete: Bool {
        !dayRunActivities.isEmpty || isManuallyComplete
    }

    private var matchedActivity: StravaActivity? {
        strava.activity(for: session.id)
    }

    private var dayRunActivities: [StravaActivity] {
        strava.runActivities(on: session.scheduledDate)
    }

    private var dayTotalMiles: Double {
        dayRunActivities.reduce(0.0) { $0 + $1.distanceMi }
    }

    private var dayRecovery: OuraDaily? {
        oura.data(for: session.scheduledDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if isEditing {
                    editHeader
                    editForm
                } else {
                    readOnlyContent
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .presentationDetents([.custom(BannerGapDetent.self)])
        .presentationDragIndicator(.visible)
        .sheet(item: $selectedStrengthDay) { selection in
            StrengthDayDetailView(weekNumber: selection.weekNumber, dayOfWeek: selection.dayOfWeek)
        }
        .sheet(item: $selectedHeatSession) { session in
            HeatLogSheet(session: session)
        }
    }

    // MARK: - Header row (edit mode only)

    private var editHeader: some View {
        HStack {
            Button("Cancel") { isEditing = false }
                .font(TrailFont.data).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Save") { saveOverride() }
                .font(TrailFont.data).fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.trailGreen, in: Capsule())
        }
    }

    // MARK: - Read-Only Content

    private var readOnlyContent: some View {
        let coachText = session.verbatimCoachNotesForDisplay
        let pace = session.targetPaceDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        let paceRedundant = pace.map { coachText.lowercased().contains($0.lowercased()) } ?? true

        return VStack(alignment: .leading, spacing: 12) {
            summaryCard(pace: (pace != nil && !pace!.isEmpty && !paceRedundant) ? pace : nil)

            if !coachText.isEmpty {
                notesSection(coachText)
            }

            athleteNotesReadonly

            strengthSection

            heatSection

            if let recovery = dayRecovery {
                SessionComponents.recoveryRow(recovery)
            }

            // If multiple runs on this date, list them all. Single-run days still flow
            // through the plan-vs-actual card for the matched activity.
            if dayRunActivities.count > 1 {
                activitiesListCard(dayRunActivities)
            } else if let activity = matchedActivity {
                SessionComponents.planVsActualSection(session: session, activity: activity)
            }

            actionsSection

            if showingSwapTargets {
                swapTargetsSection
            }
        }
    }

    private func activitiesListCard(_ acts: [StravaActivity]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ACTIVITIES")
                    .font(TrailFont.data).tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f mi total", dayTotalMiles))
                    .font(TrailFont.data)
                    .foregroundStyle(.secondary)
            }
            ForEach(acts) { act in
                activityRow(act)
                if act.id != acts.last?.id {
                    Divider()
                }
            }

            // Strava brand attribution — required by Strava's brand guidelines
            // whenever activity data is displayed. Mirrors the single-activity
            // card in `SessionComponents.planVsActualSection`.
            HStack {
                Spacer()
                Image("PoweredByStrava")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 12)
            }
            .padding(.top, 4)
        }
        .unifiedCard()
    }

    @ViewBuilder
    private func activityRow(_ activity: StravaActivity) -> some View {
        let startTime = activity.startDateLocal ?? activity.activityDate
        let pace: Double? = activity.distanceMi > 0
            ? (Double(activity.movingTimeSeconds) / 60.0) / activity.distanceMi
            : nil
        let url = URL(string: "https://www.strava.com/activities/\(activity.stravaId)")!

        Link(destination: url) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "figure.run")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.trailGreen)
                    .frame(width: 32, height: 32)
                    .background(Color.trailGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(activity.name)
                            .font(TrailFont.body)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Text(String(format: "%.1f mi", activity.distanceMi))
                            .font(TrailFont.data)
                            .foregroundStyle(.primary)
                        Text("·").foregroundStyle(.secondary)
                        Text(formatDuration(activity.movingTimeSeconds))
                            .font(TrailFont.data).foregroundStyle(.secondary)
                        if let pace {
                            Text("·").foregroundStyle(.secondary)
                            Text(formatPace(pace))
                                .font(TrailFont.data).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Text(startTime.formatted(.dateTime.hour().minute()))
                    .font(TrailFont.data)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func formatPace(_ minutesPerMile: Double) -> String {
        let m = Int(minutesPerMile)
        let s = Int((minutesPerMile - Double(m)) * 60)
        return String(format: "%d:%02d/mi", m, s)
    }

    /// Summary-card meta line: "WK 11 D1 · 8–14 MI" (range omitted when plan has none).
    private var metaLine: String {
        var parts = ["WK \(session.weekNumber) D\(session.dayOfWeek)"]
        if let range = session.displayTargetRange {
            parts.append(range.uppercased())
        }
        return parts.joined(separator: " · ")
    }

    private func summaryCard(pace: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            workoutHeader
            if let pace {
                HStack(spacing: 6) {
                    Image(systemName: "gauge.with.needle")
                        .foregroundStyle(.secondary)
                    Text(pace).font(TrailFont.data).foregroundStyle(.secondary)
                }
                .opacity(isSkipped ? 0.5 : 1)
            }
        }
        .unifiedCard()
    }

    private var workoutHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: session.workoutType.iconName)
                .font(.system(size: 20))
                .foregroundStyle(session.workoutType.swiftUIColor)
                .frame(width: 43, height: 43)
                .background(session.workoutType.swiftUIColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.workoutType.displayName)
                        .font(.system(size: 18))
                        .strikethrough(isSkipped)
                        .opacity(isSkipped ? 0.5 : 1)

                    if isOverridden {
                        Image(systemName: "pencil.circle.fill")
                            .font(TrailFont.meta)
                            .foregroundStyle(.orange)
                    }
                }
                Text(metaLine)
                    .font(TrailFont.data).tracking(0.5)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSkipped {
                Text("SKIPPED")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.8), in: Capsule())
            } else if !dayRunActivities.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.trailGreen)
                        .font(.title3)
                        .completionPulse(true)
                    Text(String(format: "%.1f mi", dayTotalMiles))
                        .font(TrailFont.data)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.trailGreen)
                }
            } else if isManuallyComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.trailGreen)
                    .font(.title3)
                    .completionPulse(true)
            }
        }
    }

    // MARK: - Edit Form

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Workout Type")
                    .font(TrailFont.body)
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
                    .font(TrailFont.body)
                    .foregroundStyle(.secondary)

                TextField("e.g. 8.0", text: $editDistanceMi)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Effort / Pace")
                    .font(TrailFont.body)
                    .foregroundStyle(.secondary)

                TextField("e.g. Easy effort, Z1/Z2", text: $editPace)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Coach notes")
                    .font(TrailFont.coach)
                    .foregroundStyle(.secondary)

                TextField("Optional — full text from your plan is kept here",
                          text: $editNotes, axis: .vertical)
                    .font(TrailFont.body)
                    .frame(minHeight: 80, alignment: .top)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(.separator), lineWidth: 1)
                    )
            }

            athleteNotesEditor

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

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coach notes")
                .font(TrailFont.coach)
                .foregroundStyle(.secondary)
            Text(notes)
                .font(TrailFont.body)
                .foregroundStyle(isSkipped ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .unifiedCard()
    }

    /// Read-only athlete-notes card. Surfaces the journal entry alongside the
    /// coach card so the user doesn't have to re-enter Edit to see what they
    /// wrote. Hidden when there's nothing to show.
    @ViewBuilder
    private var athleteNotesReadonly: some View {
        if let text = session.athleteNotes?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Athlete notes")
                    .font(TrailFont.coach)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(TrailFont.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .unifiedCard()
        }
    }

    /// Edit-mode athlete-notes input. Saves through `updateAthleteNotes` (not
    /// `overrideSession`), so adding a journal entry never marks the session
    /// as overridden — it's a parallel field, not a deviation from the plan.
    /// Auto-grows as the user types via `TextField(axis: .vertical)`, with a
    /// 60pt min so the empty state reads as "quick journal" rather than
    /// "homework assignment."
    private var athleteNotesEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Athlete notes")
                .font(TrailFont.coach)
                .foregroundStyle(.secondary)

            TextField("How did it go?", text: $editAthleteNotes, axis: .vertical)
                .font(TrailFont.body)
                .frame(minHeight: 60, alignment: .top)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(.separator), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var strengthSection: some View {
        let daySessions = strengthStore.sessions(for: session.scheduledDate)

        if !daySessions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.trailGreen)
                        .frame(width: 24, height: 24)
                        .background(Color.trailGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 15))
                    Text("STRENGTH")
                        .font(TrailFont.data).tracking(0.5)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        selectedStrengthDay = StrengthDaySelection(
                            weekNumber: session.weekNumber,
                            dayOfWeek: session.dayOfWeek
                        )
                    } label: {
                        HStack(spacing: 2) {
                            Text("Details").font(TrailFont.data)
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Color.trailGreen)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(daySessions) { s in
                    HStack(alignment: .top, spacing: 10) {
                        Button {
                            strengthStore.toggleComplete(s.id)
                        } label: {
                            Image(systemName: s.isComplete ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundStyle(s.isComplete ? AnyShapeStyle(Color.trailGreen) : AnyShapeStyle(Color.secondary.opacity(0.4)))
                                .completionPulse(s.isComplete)
                        }
                        .buttonStyle(.plain)

                        Text(s.coachNotes.isEmpty ? "Strength" : s.coachNotes)
                            .font(TrailFont.body)
                            .foregroundStyle(s.isComplete ? .secondary : .primary)
                            .strikethrough(s.isComplete)
                    }
                }
            }
            .unifiedCard()
            .opacity(isSkipped ? 0.5 : 1)
        }
    }

    @ViewBuilder
    private var heatSection: some View {
        let heatSessions = heatStore.sessions(for: session.scheduledDate)

        if !heatSessions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                        .frame(width: 24, height: 24)
                        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 15))
                    Text("HEAT")
                        .font(TrailFont.data).tracking(0.5)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ForEach(heatSessions) { hs in
                    let complete = heatStore.isComplete(hs.id)
                    let log = heatStore.log(for: hs.id)

                    Button {
                        selectedHeatSession = hs
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundStyle(complete ? Color.trailGreen : Color.secondary.opacity(0.4))

                            Text(hs.sessionType.displayName)
                                .font(TrailFont.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            if let log {
                                Text("\(log.actualDurationMinutes) min")
                                    .font(TrailFont.data)
                                    .foregroundStyle(Color.trailGreen)
                            } else {
                                Text("\(hs.targetDurationMinutes) min")
                                    .font(TrailFont.data)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .unifiedCard()
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
                markDoneButton

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
                        editAthleteNotes = session.athleteNotes ?? ""
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

    /// Primary completion CTA. Disabled when a Strava activity is matched —
    /// completion is then implicit and the user shouldn't double-record.
    @ViewBuilder
    private var markDoneButton: some View {
        if !dayRunActivities.isEmpty {
            EmptyView()
        } else if isManuallyComplete {
            Button {
                planStore.unmarkComplete(session.id)
            } label: {
                Label("Mark Incomplete", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        } else {
            Button {
                planStore.markComplete(session.id)
            } label: {
                Label("Mark Done", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.trailGreen)
        }
    }

    private var swapTargetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select a day to swap with:")
                .font(TrailFont.body)
                .foregroundStyle(.secondary)

            let targets = planStore.sessions(for: session.weekNumber)
                .filter { $0.id != session.id && $0.workoutType != .strength }

            ForEach(targets) { target in
                Button {
                    planStore.swapSessions(session, with: target)
                    if let planId = planStore.activePlan?.id {
                        strengthStore.refreshFromPlannedSessions(planStore.sessions, planId: planId)
                    }
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: target.workoutType.iconName)
                            .foregroundStyle(target.workoutType.swiftUIColor)
                            .frame(width: 28)

                        VStack(alignment: .leading) {
                            Text(target.scheduledDate.formatted(.dateTime.weekday(.wide)))
                                .font(TrailFont.body)
                            Text(target.workoutType.displayName)
                                .font(TrailFont.meta)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let mi = target.targetDistanceMi {
                            Text(String(format: "%.1f mi", mi))
                                .font(TrailFont.meta)
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

    private func saveOverride() {
        let distanceKm = Double(editDistanceMi).map { $0 / 0.621371 }

        planStore.overrideSession(
            session.id,
            workoutType: editWorkoutType,
            distanceKm: distanceKm,
            paceDescription: editPace.isEmpty ? nil : editPace,
            notes: editNotes.isEmpty ? nil : editNotes,
            reason: nil
        )
        // Athlete notes save via a separate path so adding a journal entry
        // never trips the override system or the "edited" Reset button.
        planStore.updateAthleteNotes(session.id, notes: editAthleteNotes)
        isEditing = false
        dismiss()
    }
}

// MARK: - Custom Detent

/// PreferenceKey used by the host tab (WeekView) to measure its green banner's content-area
/// height. The measurement is written into `BannerGapDetent.bannerHeight` so the day sheet
/// sizes to leave the banner fully visible with no fudge factor.
struct BannerHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 70  // conservative fallback before first layout
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Pops the day sheet so its top edge aligns with the bottom of the Week tab's green banner.
/// Banner height is measured at runtime by `WeekView` via `BannerHeightKey` and written here
/// before the sheet presents, so the sheet clears the banner exactly — no font-metric guesses.
struct BannerGapDetent: CustomPresentationDetent {
    /// Set by the host view on preference change; read by `height(in:)` when the sheet presents.
    nonisolated(unsafe) static var bannerHeight: CGFloat = 70

    static func height(in context: Context) -> CGFloat? {
        context.maxDetentValue - bannerHeight
    }
}
