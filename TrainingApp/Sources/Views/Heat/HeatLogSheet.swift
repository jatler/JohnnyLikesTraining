import SwiftUI

struct HeatLogSheet: View {
    let session: HeatSession
    @Environment(HeatStore.self) private var heatStore
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var showingSkipOptions = false
    @State private var showingSwapTargets = false
    @State private var editSelectedType: HeatType
    @State private var editDuration: Int
    @State private var editNotes: String = ""
    @State private var editApplyToAll = false

    private static let weekdayNames = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private static let dayNames = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    init(session: HeatSession) {
        self.session = session
        _editSelectedType = State(initialValue: session.sessionType)
        _editDuration = State(initialValue: session.targetDurationMinutes)
    }

    private var existingLog: HeatLog? { heatStore.log(for: session.id) }
    private var isLogged: Bool { existingLog != nil }
    private var isSkipped: Bool { heatStore.isSkipped(session.id) }
    private var currentSession: HeatSession {
        heatStore.sessions.first { $0.id == session.id } ?? session
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if isEditing {
                    editHeader
                    editForm
                } else {
                    summaryCard
                    if let notes = currentSession.notes, !notes.isEmpty {
                        notesSection(notes)
                    }
                    actionsSection
                    if showingSwapTargets {
                        swapTargetsSection
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .presentationDetents([.custom(BannerGapDetent.self)])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let log = existingLog {
                editSelectedType = log.sessionType
                editDuration = log.actualDurationMinutes
                editNotes = log.notes ?? ""
            }
        }
    }

    // MARK: Summary

    private var summaryCard: some View {
        let typeColor = currentSession.sessionType.color
        let typeIcon = currentSession.sessionType.iconName

        return HStack(spacing: 14) {
            Image(systemName: typeIcon)
                .font(.system(size: 20))
                .foregroundStyle(typeColor)
                .frame(width: 43, height: 43)
                .background(typeColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(currentSession.sessionType.displayName)
                        .font(.system(size: 18))
                        .strikethrough(isSkipped)
                        .opacity(isSkipped ? 0.5 : 1)
                    if currentSession.isTemplateOverride {
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

            trailingStatus
        }
        .unifiedCard()
    }

    @ViewBuilder
    private var trailingStatus: some View {
        if isSkipped {
            Text("SKIPPED")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.8), in: Capsule())
        } else if let log = existingLog {
            HStack(spacing: 6) {
                // Burst animation on first appearance — same one-shot pattern
                // as the Week tab. CompletionCelebrationStore prevents a
                // replay on subsequent sheet opens or row appearances.
                // magnitude = 20 → Week-tab-sized grow (~2.4×).
                CompleteStatus(
                    magnitude: 20,
                    label: "",
                    sessionId: session.id,
                    baseSize: 22
                )
                Text("\(log.actualDurationMinutes) min")
                    .font(TrailFont.data)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.trailGreen)
            }
        }
    }

    private var metaLine: String {
        "WK \(currentSession.weekNumber) D\(currentSession.dayOfWeek) · \(currentSession.targetDurationMinutes) MIN"
    }

    // MARK: Notes

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

    // MARK: Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if isSkipped {
                Button {
                    heatStore.unskipSession(session.id)
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
                    .confirmationDialog("Skip this heat session?", isPresented: $showingSkipOptions) {
                        Button("Injury") { heatStore.skipSession(session.id, reason: "Injury") }
                        Button("Illness") { heatStore.skipSession(session.id, reason: "Illness") }
                        Button("Life / Schedule") { heatStore.skipSession(session.id, reason: "Life") }
                        Button("Skip (no reason)") { heatStore.skipSession(session.id, reason: nil) }
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
                        editSelectedType = currentSession.sessionType
                        editDuration = existingLog?.actualDurationMinutes ?? currentSession.targetDurationMinutes
                        editNotes = existingLog?.notes ?? ""
                        editApplyToAll = false
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

    @ViewBuilder
    private var markDoneButton: some View {
        if isLogged {
            Button {
                heatStore.deleteLog(session.id)
            } label: {
                Label("Mark Incomplete", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        } else {
            Button {
                heatStore.logSession(
                    sessionId: session.id,
                    durationMinutes: currentSession.targetDurationMinutes,
                    sessionType: currentSession.sessionType,
                    notes: nil
                )
            } label: {
                Label("Mark Done", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.trailGreen)
        }
    }

    // MARK: Swap

    private var swapTargetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select a day to swap with:")
                .font(TrailFont.body)
                .foregroundStyle(.secondary)

            ForEach(1...7, id: \.self) { day in
                if day != currentSession.dayOfWeek {
                    Button {
                        heatStore.moveToDay(session.id, dayOfWeek: day)
                        showingSwapTargets = false
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(currentSession.sessionType.color)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Self.dayNames[day])
                                    .font(TrailFont.body)
                                Text(swapPreview(for: day))
                                    .font(TrailFont.meta)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(TrailFont.meta)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Edit

    private var editHeader: some View {
        HStack {
            Button("Cancel") { isEditing = false }
                .font(TrailFont.data).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Save") { saveEdit() }
                .font(TrailFont.data).fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.trailGreen, in: Capsule())
        }
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Heat")
                .font(TrailFont.title)

            VStack(alignment: .leading, spacing: 8) {
                Text("Type")
                    .font(TrailFont.body)
                    .foregroundStyle(.secondary)
                Picker("Type", selection: $editSelectedType) {
                    ForEach(HeatType.allCases) { type in
                        Label(type.displayName, systemImage: type.iconName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(TrailFont.body)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("\(editDuration) min")
                        .font(TrailFont.title)
                        .foregroundStyle(.orange)
                        .frame(width: 100, alignment: .leading)
                    Slider(value: durationBinding, in: 5...60, step: 5)
                        .tint(.orange)
                }
                Text("Target: \(currentSession.targetDurationMinutes) min")
                    .font(TrailFont.data)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(TrailFont.body)
                    .foregroundStyle(.secondary)
                TextField("Notes (optional)", text: $editNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            if editSelectedType != currentSession.sessionType || editDuration != currentSession.targetDurationMinutes {
                Toggle("Apply to all \(Self.dayNames[currentSession.dayOfWeek])s", isOn: $editApplyToAll)
                    .font(TrailFont.body)
                    .tint(.orange)
            }

            if isLogged {
                Button(role: .destructive) {
                    heatStore.deleteLog(session.id)
                    isEditing = false
                } label: {
                    Label("Remove Log", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    private func swapPreview(for day: Int) -> String {
        if let other = heatStore.sessions.first(where: {
            $0.weekNumber == currentSession.weekNumber && $0.dayOfWeek == day
        }) {
            return "Has \(other.targetDurationMinutes) min \(other.sessionType.displayName.lowercased())"
        }
        return "Empty"
    }

    private var durationBinding: Binding<Double> {
        Binding(
            get: { Double(editDuration) },
            set: { editDuration = Int($0) }
        )
    }

    private func saveEdit() {
        let typeChanged = editSelectedType != currentSession.sessionType
        let targetChanged = editDuration != currentSession.targetDurationMinutes

        if typeChanged || targetChanged {
            if editApplyToAll {
                heatStore.updateAllSessions(
                    dayOfWeek: currentSession.dayOfWeek,
                    sessionType: editSelectedType,
                    durationMinutes: editDuration
                )
            } else {
                var updated = currentSession
                updated.sessionType = editSelectedType
                updated.targetDurationMinutes = editDuration
                heatStore.updateSession(updated)
            }
        }

        // Replace any existing log with the freshly edited values.
        if isLogged { heatStore.deleteLog(session.id) }
        heatStore.logSession(
            sessionId: session.id,
            durationMinutes: editDuration,
            sessionType: editSelectedType,
            notes: editNotes.isEmpty ? nil : editNotes
        )
        isEditing = false
    }
}

#Preview {
    HeatLogSheet(session: HeatSession(
        id: UUID(),
        planId: UUID(),
        scheduledDate: Date(),
        weekNumber: 1,
        dayOfWeek: 1,
        sessionType: .sauna,
        targetDurationMinutes: 25,
        notes: "20-30 min sauna or hot tub."
    ))
    .environment(HeatStore())
}
