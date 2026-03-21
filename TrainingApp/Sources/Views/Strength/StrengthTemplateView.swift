import SwiftUI

struct StrengthTemplateView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(OuraService.self) private var oura

    @State private var showingAddExercise = false
    @State private var addDay: Int = 1
    @State private var selectedSession: StrengthDaySelection?
    @State private var editingExercise: StrengthTemplateExercise?
    @State private var showingAddHeatDay = false

    private let dayNames = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        NavigationStack {
            Group {
                if strengthStore.hasTemplate {
                    templateContent
                } else {
                    emptyState
                }
            }
            .navigationTitle("Strength & Heat")
            .sheet(item: $selectedSession) { selection in
                StrengthDayDetailView(weekNumber: selection.weekNumber, dayOfWeek: selection.dayOfWeek)
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseSheet(dayOfWeek: addDay)
            }
            .sheet(item: $editingExercise) { exercise in
                EditExerciseSheet(exercise: exercise)
            }
            .sheet(isPresented: $showingAddHeatDay) {
                AddHeatDaySheet()
            }
        }
    }

    // MARK: - Template Content

    private var templateContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                suggestionsSection

                ForEach(strengthStore.daysWithExercises, id: \.self) { day in
                    daySection(day)
                }

                addDayButton

                heatTemplateSection
            }
            .padding()
            .padding(.bottom, 20)
        }
    }

    // MARK: - Suggestions

    @ViewBuilder
    private var suggestionsSection: some View {
        if !strengthStore.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Progression Suggestions", systemImage: "arrow.up.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)

                ForEach(strengthStore.suggestions) { suggestion in
                    suggestionCard(suggestion)
                }
            }
        }
    }

    private func suggestionCard(_ suggestion: ProgressionSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(suggestion.exerciseName)
                .font(.subheadline.bold())

            Text(suggestion.reason)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("Current")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatPrescription(
                        sets: suggestion.currentSets,
                        reps: suggestion.currentReps,
                        weightKg: suggestion.currentWeightKg
                    ))
                    .font(.caption.bold())
                }

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.green)

                VStack(spacing: 2) {
                    Text("Suggested")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatPrescription(
                        sets: suggestion.suggestedSets,
                        reps: suggestion.suggestedReps,
                        weightKg: suggestion.suggestedWeightKg
                    ))
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                }

                Spacer()

                Button("Accept") {
                    strengthStore.acceptSuggestion(suggestion)
                }
                .buttonStyle(.bordered)
                .tint(.green)
                .controlSize(.small)

                Button("Dismiss") {
                    strengthStore.dismissSuggestion(suggestion)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.green.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Day Section

    private func daySection(_ day: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayNames[day])
                    .font(.headline)

                Spacer()

                Button {
                    addDay = day
                    showingAddExercise = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.indigo)
                }

                if let week = planStore.currentWeekNumber {
                    Button {
                        selectedSession = StrengthDaySelection(weekNumber: week, dayOfWeek: day)
                    } label: {
                        Label("Log", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.indigo)
                }
            }

            ForEach(strengthStore.exercises(for: day)) { exercise in
                exerciseRow(exercise)
                    .onTapGesture { editingExercise = exercise }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func exerciseRow(_ exercise: StrengthTemplateExercise) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(.indigo)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exerciseName)
                    .font(.subheadline.bold())

                Text(formatPrescription(
                    sets: exercise.targetSets,
                    reps: exercise.targetReps,
                    weightKg: exercise.targetWeightKg
                ))
                .font(.caption)
                .foregroundStyle(.secondary)

                if let notes = exercise.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if exercise.isBodyweight {
                Text("BW")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Add Day

    private var addDayButton: some View {
        Menu {
            ForEach(1...7, id: \.self) { day in
                if !strengthStore.daysWithExercises.contains(day) {
                    Button(dayNames[day]) {
                        addDay = day
                        showingAddExercise = true
                    }
                }
            }
        } label: {
            Label("Add Exercises on Another Day", systemImage: "plus.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.indigo)
        .disabled(strengthStore.daysWithExercises.count >= 7)
    }

    // MARK: - Heat Template Section

    private var heatTemplateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Heat", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)

                Spacer()

                Button {
                    showingAddHeatDay = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.orange)
                }
            }

            if heatStore.hasSessions {
                let heatDays = heatDaysFromSessions()

                ForEach(heatDays, id: \.day) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(dayNames[entry.day])
                                .font(.subheadline.bold())

                            Text("\(entry.session.sessionType.displayName) • \(entry.session.targetDurationMinutes) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            heatStore.removeDay(entry.day)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.6))
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("No heat sessions scheduled")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.orange.opacity(0.15), lineWidth: 1)
        )
    }

    private struct HeatDayEntry {
        let day: Int
        let session: HeatSession
    }

    private func heatDaysFromSessions() -> [HeatDayEntry] {
        var seen = Set<Int>()
        var entries: [HeatDayEntry] = []
        for session in heatStore.sessions.sorted(by: { $0.dayOfWeek < $1.dayOfWeek }) {
            if seen.insert(session.dayOfWeek).inserted {
                entries.append(HeatDayEntry(day: session.dayOfWeek, session: session))
            }
        }
        return entries
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.indigo)

                Text("No strength program yet")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Create a training plan to automatically load your strength program.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                heatTemplateSection
            }
            .padding()
            .padding(.top, 40)
        }
    }

    // MARK: - Helpers

    private func formatPrescription(sets: Int, reps: Int, weightKg: Double?) -> String {
        if let kg = weightKg {
            let lbs = kg * 2.205
            return "\(sets)×\(reps) @ \(Int(lbs)) lbs"
        }
        return "\(sets)×\(reps)"
    }
}

// MARK: - Day Selection for Sheet

struct StrengthDaySelection: Identifiable {
    let id = UUID()
    let weekNumber: Int
    let dayOfWeek: Int
}

// MARK: - Add Exercise Sheet

struct AddExerciseSheet: View {
    let dayOfWeek: Int
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var sets = 3
    @State private var reps = 10
    @State private var weightLbs = ""
    @State private var isBodyweight = true
    @State private var rpe = ""
    @State private var notes = ""

    private let dayNames = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Exercise name", text: $name)
                }

                Section("Prescription") {
                    Stepper("Sets: \(sets)", value: $sets, in: 1...10)
                    Stepper("Reps: \(reps)", value: $reps, in: 1...50)

                    Toggle("Bodyweight", isOn: $isBodyweight)

                    if !isBodyweight {
                        TextField("Weight (lbs)", text: $weightLbs)
                            .keyboardType(.decimalPad)
                    }

                    TextField("Target RPE (optional)", text: $rpe)
                        .keyboardType(.decimalPad)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add to \(dayNames[dayOfWeek])")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addExercise() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addExercise() {
        let weightKg = Double(weightLbs).map { $0 / 2.205 }
        let targetRpe = Double(rpe)

        strengthStore.addExercise(
            dayOfWeek: dayOfWeek,
            name: name.trimmingCharacters(in: .whitespaces),
            sets: sets,
            reps: reps,
            weightKg: isBodyweight ? nil : weightKg,
            isBodyweight: isBodyweight,
            rpe: targetRpe,
            notes: notes.isEmpty ? nil : notes
        )
        dismiss()
    }
}

// MARK: - Edit Exercise Sheet

struct EditExerciseSheet: View {
    @State var exercise: StrengthTemplateExercise
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var sets: Int = 3
    @State private var reps: Int = 10
    @State private var weightLbs: String = ""
    @State private var isBodyweight: Bool = true
    @State private var rpe: String = ""
    @State private var notes: String = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingHistory = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Exercise name", text: $name)
                }

                Section("Prescription") {
                    Stepper("Sets: \(sets)", value: $sets, in: 1...10)
                    Stepper("Reps: \(reps)", value: $reps, in: 1...50)

                    Toggle("Bodyweight", isOn: $isBodyweight)

                    if !isBodyweight {
                        TextField("Weight (lbs)", text: $weightLbs)
                            .keyboardType(.decimalPad)
                    }

                    TextField("Target RPE (optional)", text: $rpe)
                        .keyboardType(.decimalPad)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Button {
                        showingHistory = true
                    } label: {
                        Label("View History", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Remove Exercise", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExercise() }
                }
            }
            .alert("Remove Exercise?", isPresented: $showingDeleteConfirmation) {
                Button("Remove", role: .destructive) {
                    strengthStore.removeExercise(exercise)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove \(exercise.exerciseName) from your template and all future weeks.")
            }
            .sheet(isPresented: $showingHistory) {
                ExerciseHistoryView(exerciseName: exercise.exerciseName)
            }
            .onAppear {
                name = exercise.exerciseName
                sets = exercise.targetSets
                reps = exercise.targetReps
                isBodyweight = exercise.isBodyweight
                if let kg = exercise.targetWeightKg {
                    weightLbs = String(format: "%.0f", kg * 2.205)
                }
                if let r = exercise.targetRpe {
                    rpe = String(format: "%.1f", r)
                }
                notes = exercise.notes ?? ""
            }
        }
    }

    private func saveExercise() {
        var updated = exercise
        updated.exerciseName = name.trimmingCharacters(in: .whitespaces)
        updated.targetSets = sets
        updated.targetReps = reps
        updated.isBodyweight = isBodyweight
        updated.targetWeightKg = isBodyweight ? nil : Double(weightLbs).map { $0 / 2.205 }
        updated.targetRpe = Double(rpe)
        updated.notes = notes.isEmpty ? nil : notes

        strengthStore.updateExercise(updated)
        dismiss()
    }
}

private struct AddHeatDaySheet: View {
    @Environment(HeatStore.self) private var heatStore
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDay: Int = 1
    @State private var sessionType: HeatType = .sauna
    @State private var duration: Double = 25

    private let dayNames = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var availableDays: [Int] {
        let usedDays = Set(heatStore.sessions.map(\.dayOfWeek))
        return (1...7).filter { !usedDays.contains($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Day", selection: $selectedDay) {
                    ForEach(availableDays, id: \.self) { day in
                        Text(dayNames[day]).tag(day)
                    }
                }

                Picker("Type", selection: $sessionType) {
                    ForEach(HeatType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration: \(Int(duration)) min")
                    Slider(value: $duration, in: 10...60, step: 5)
                }
            }
            .navigationTitle("Add Heat Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addHeatDay() }
                        .disabled(availableDays.isEmpty)
                }
            }
            .onAppear {
                if let first = availableDays.first {
                    selectedDay = first
                }
            }
        }
    }

    private func addHeatDay() {
        guard let plan = planStore.activePlan else { return }
        let totalWeeks = planStore.sessions.map(\.weekNumber).max() ?? 1

        heatStore.addDay(
            dayOfWeek: selectedDay,
            sessionType: sessionType,
            durationMinutes: Int(duration),
            notes: nil,
            planId: plan.id,
            planStartDate: plan.planStartDate,
            totalWeeks: totalWeeks
        )
        dismiss()
    }
}

#Preview {
    StrengthTemplateView()
        .environment(TrainingPlanStore())
        .environment(StrengthStore())
        .environment(HeatStore())
        .environment(OuraService())
}
