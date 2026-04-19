import SwiftUI

struct HeatLogSheet: View {
    let session: HeatSession
    @Environment(HeatStore.self) private var heatStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: HeatType
    @State private var duration: Int
    @State private var notes = ""
    @State private var applyToAll = false

    private var existingLog: HeatLog? {
        heatStore.log(for: session.id)
    }

    init(session: HeatSession) {
        self.session = session
        _selectedType = State(initialValue: session.sessionType)
        _duration = State(initialValue: session.targetDurationMinutes)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    typePickerSection

                    durationSection

                    if let notes = session.notes, !notes.isEmpty {
                        notesDisplay(notes)
                    }

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...3)

                    if selectedType != session.sessionType || duration != session.targetDurationMinutes {
                        Toggle("Apply to all weeks", isOn: $applyToAll)
                            .font(TrailFont.body)
                            .tint(.orange)
                    }

                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Heat Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let log = existingLog {
                    selectedType = log.sessionType
                    duration = log.actualDurationMinutes
                    notes = log.notes ?? ""
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 44, height: 44)
                .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("Heat")
                    .font(TrailFont.title)

                Text("Week \(session.weekNumber) \u{2022} \(session.scheduledDate.formatted(.dateTime.weekday(.wide)))")
                    .font(TrailFont.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if existingLog != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        }
    }

    private var typePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type")
                .font(TrailFont.body)
                .foregroundStyle(.secondary)

            Picker("Type", selection: $selectedType) {
                ForEach(HeatType.allCases) { type in
                    Label(type.displayName, systemImage: type.iconName)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration")
                .font(TrailFont.body)
                .foregroundStyle(.secondary)

            HStack {
                Text("\(duration) min")
                    .font(TrailFont.title)
                    .foregroundStyle(.orange)
                    .frame(width: 100, alignment: .leading)

                Slider(value: durationBinding, in: 5...60, step: 5)
                    .tint(.orange)
            }

            Text("Target: \(session.targetDurationMinutes) min")
                .font(TrailFont.data)
                .foregroundStyle(.tertiary)
        }
    }

    private func notesDisplay(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .font(TrailFont.meta)
            Text(text)
                .font(TrailFont.meta)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if existingLog != nil {
                Button {
                    heatStore.deleteLog(session.id)
                    dismiss()
                } label: {
                    Label("Remove Log", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            Button {
                // Update the session itself if type or duration changed
                if selectedType != session.sessionType || duration != session.targetDurationMinutes {
                    if applyToAll {
                        heatStore.updateAllSessions(
                            dayOfWeek: session.dayOfWeek,
                            sessionType: selectedType,
                            durationMinutes: duration
                        )
                    } else {
                        var updated = session
                        updated.sessionType = selectedType
                        updated.targetDurationMinutes = duration
                        heatStore.updateSession(updated)
                    }
                }

                // Log completion
                if existingLog != nil {
                    heatStore.deleteLog(session.id)
                }
                heatStore.logSession(
                    sessionId: session.id,
                    durationMinutes: duration,
                    sessionType: selectedType,
                    notes: notes.isEmpty ? nil : notes
                )
                dismiss()
            } label: {
                Label(
                    existingLog != nil ? "Update Log" : "Log Session",
                    systemImage: "checkmark.circle.fill"
                )
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }

    // MARK: - Helpers

    private var durationBinding: Binding<Double> {
        Binding(
            get: { Double(duration) },
            set: { duration = Int($0) }
        )
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
