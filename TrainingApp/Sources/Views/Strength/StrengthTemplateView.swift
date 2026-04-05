import SwiftUI

struct StrengthTemplateView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(StretchStore.self) private var stretchStore
    @Environment(OuraService.self) private var oura

    @State private var showingAddExercise = false
    @State private var addDay: Int = 1
    @State private var selectedSession: StrengthDaySelection?
    @State private var editingExercise: StrengthTemplateExercise?
    @State private var showingHistory = false
    @State private var historyExerciseName: String = ""
    @State private var showingDeleteConfirmation = false
    @State private var exerciseToDelete: StrengthTemplateExercise?
    @State private var showingAddHeatDay = false
    @State private var selectedHeatSession: HeatSession?
    @State private var showingAddStretch = false
    @State private var addStretchDay: Int = 1
    @State private var editingStretch: StretchTemplateExercise?
    @State private var selectedStretchDay: StretchDaySelection?
    @State private var showingStretchDeleteConfirmation = false
    @State private var stretchToDelete: StretchTemplateExercise?
    @State private var selectedSegment: StrengthTabSegment = .strength

    private let dayNames = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    enum StrengthTabSegment: String, CaseIterable {
        case strength = "Strength"
        case stretch = "Stretch"
        case heat = "Heat"
    }

    var body: some View {
        NavigationStack {
            Group {
                if strengthStore.hasTemplate || stretchStore.hasTemplate {
                    templateContent
                } else {
                    emptyState
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Error", isPresented: Binding(
                get: { strengthStore.lastError != nil },
                set: { if !$0 { strengthStore.lastError = nil } }
            )) {
                Button("OK") { strengthStore.lastError = nil }
            } message: {
                Text(strengthStore.lastError ?? "")
            }
            .sheet(item: $selectedSession) { selection in
                StrengthDayDetailView(weekNumber: selection.weekNumber, dayOfWeek: selection.dayOfWeek)
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseSheet(dayOfWeek: addDay)
            }
            .sheet(item: $editingExercise) { exercise in
                EditExerciseSheet(exercise: exercise)
            }
            .sheet(isPresented: $showingHistory) {
                ExerciseHistoryView(exerciseName: historyExerciseName)
            }
            .alert("Remove Exercise?", isPresented: $showingDeleteConfirmation) {
                Button("Remove", role: .destructive) {
                    if let exercise = exerciseToDelete {
                        strengthStore.removeExercise(exercise)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove \(exerciseToDelete?.exerciseName ?? "") from your template and all future weeks.")
            }
            .sheet(isPresented: $showingAddHeatDay) {
                AddHeatDaySheet()
            }
            .sheet(item: $selectedHeatSession) { session in
                HeatLogSheet(session: session)
            }
            .sheet(isPresented: $showingAddStretch) {
                AddStretchExerciseSheet(dayOfWeek: addStretchDay)
            }
            .sheet(item: $editingStretch) { exercise in
                EditStretchExerciseSheet(exercise: exercise)
            }
            .sheet(item: $selectedStretchDay) { selection in
                StretchDayDetailView(weekNumber: selection.weekNumber, dayOfWeek: selection.dayOfWeek)
            }
            .alert("Remove Stretch?", isPresented: $showingStretchDeleteConfirmation) {
                Button("Remove", role: .destructive) {
                    if let exercise = stretchToDelete {
                        stretchStore.removeExercise(exercise)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove \(stretchToDelete?.stretchName ?? "") from your template and all future weeks.")
            }
        }
    }

    // MARK: - Template Content

    private var templateContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("Strength & More")
                    .font(TrailFont.dataLarge)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Section", selection: $selectedSegment) {
                    ForEach(StrengthTabSegment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding()
            .background(.bar)

            ScrollView {
                VStack(spacing: 20) {
                    switch selectedSegment {
                    case .strength:
                        suggestionsSection

                        ForEach(strengthStore.daysWithExercises, id: \.self) { day in
                            daySection(day)
                        }

                        addDayButton

                    case .stretch:
                        stretchSegmentContent

                    case .heat:
                        heatTemplateSection
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
        }
    }

    private var stretchSegmentContent: some View {
        VStack(spacing: 12) {
            if stretchStore.hasTemplate {
                ForEach(stretchStore.daysWithExercises, id: \.self) { day in
                    stretchDaySection(day)
                }

                stretchAddDayButton
            } else {
                VStack(spacing: 16) {
                    Text("No stretches yet.")
                        .font(TrailFont.detail)
                        .foregroundStyle(.tertiary)

                    if let plan = planStore.activePlan {
                        Button {
                            stretchStore.createBlankTemplate(planId: plan.id)
                        } label: {
                            Label("Create Stretch Program", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.trailGreen)
                    }
                }
            }
        }
    }

    // MARK: - Suggestions

    @ViewBuilder
    private var suggestionsSection: some View {
        if !strengthStore.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Progression Suggestions", systemImage: "arrow.up.circle.fill")
                    .font(TrailFont.detailBold)
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
                .font(TrailFont.bodyBold)

            Text(suggestion.reason)
                .font(TrailFont.meta)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("Current")
                        .font(TrailFont.meta)
                        .foregroundStyle(.secondary)
                    Text(formatPrescription(
                        sets: suggestion.currentSets,
                        reps: suggestion.currentReps,
                        weightKg: suggestion.currentWeightKg
                    ))
                    .font(TrailFont.metaBold)
                }

                Image(systemName: "arrow.right")
                    .font(TrailFont.meta)
                    .foregroundStyle(.green)

                VStack(spacing: 2) {
                    Text("Suggested")
                        .font(TrailFont.meta)
                        .foregroundStyle(.secondary)
                    Text(formatPrescription(
                        sets: suggestion.suggestedSets,
                        reps: suggestion.suggestedReps,
                        weightKg: suggestion.suggestedWeightKg
                    ))
                    .font(TrailFont.metaBold)
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
        .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.green.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Day Section

    private var currentAdjustedDay: Int {
        let wd = Calendar.current.component(.weekday, from: Date())
        return wd == 1 ? 7 : wd - 1
    }

    private func isHighlightedDay(_ day: Int, availableDays: [Int]) -> Bool {
        let today = currentAdjustedDay
        // If today has a session, highlight only today
        if availableDays.contains(today) {
            return day == today
        }
        // Otherwise highlight the next upcoming day
        let futureDays = availableDays.filter { $0 > today }.sorted()
        let wrappedDays = availableDays.filter { $0 < today }.sorted()
        let nextDay = futureDays.first ?? wrappedDays.first
        return day == nextDay
    }

    private func daySection(_ day: Int) -> some View {
        let isToday = isHighlightedDay(day, availableDays: strengthStore.daysWithExercises)
        let exercises = strengthStore.exercises(for: day)
        let weekSessions: [StrengthSession] = {
            guard let week = planStore.currentWeekNumber else { return [] }
            return strengthStore.sessions(for: week, dayOfWeek: day)
        }()

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayNames[day])
                    .font(TrailFont.title)

                Spacer()

                if !weekSessions.isEmpty {
                    let completed = weekSessions.filter { strengthStore.isSessionComplete($0.id) }.count
                    Text("\(completed)/\(weekSessions.count) done")
                        .font(TrailFont.meta)
                        .foregroundStyle(completed == weekSessions.count ? .green : .secondary)
                }
            }

            ForEach(exercises) { exercise in
                let complete = weekSessions.first(where: { $0.templateExerciseId == exercise.id })
                    .map { strengthStore.isSessionComplete($0.id) } ?? false

                exerciseRow(exercise, complete: complete)
                    .contextMenu {
                        Button {
                            editingExercise = exercise
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button {
                            historyExerciseName = exercise.exerciseName
                            showingHistory = true
                        } label: {
                            Label("View History", systemImage: "chart.line.uptrend.xyaxis")
                        }

                        Button(role: .destructive) {
                            exerciseToDelete = exercise
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isToday ? Color.trailGreen.opacity(0.08) : Color(.systemBackground))
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isToday ? Color.trailGreen.opacity(0.3) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if let week = planStore.currentWeekNumber {
                selectedSession = StrengthDaySelection(weekNumber: week, dayOfWeek: day)
            }
        }
    }

    private func exerciseRow(_ exercise: StrengthTemplateExercise, complete: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(complete ? .green : .secondary.opacity(0.4))

            Image(systemName: "dumbbell.fill")
                .font(TrailFont.body)
                .foregroundStyle(Color.trailGreen)
                .frame(width: 32, height: 32)
                .background(Color.trailGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exerciseName)
                    .font(TrailFont.body)
                    .strikethrough(complete)
                    .foregroundStyle(complete ? .secondary : .primary)

                let repsLabel = exercise.isTimed ? "\(exercise.prescribedReps)s" : "\(exercise.prescribedReps)"
                let prescription = "\(exercise.prescribedSets)x\(repsLabel)" + (exercise.prescribedWeightKg.map { " @ \(Int($0 * 2.205)) lbs" } ?? "")
                Text(prescription)
                    .font(TrailFont.data)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
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
        .tint(Color.trailGreen)
        .disabled(strengthStore.daysWithExercises.count >= 7)
    }

    private func stretchDaySection(_ day: Int) -> some View {
        let isToday = isHighlightedDay(day, availableDays: stretchStore.daysWithExercises)
        let exercises = stretchStore.exercises(for: day)
        let weekSessions: [StretchSession] = {
            guard let week = planStore.currentWeekNumber else { return [] }
            return stretchStore.sessions(for: week, dayOfWeek: day)
        }()

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayNames[day])
                    .font(TrailFont.title)

                Spacer()

                if !weekSessions.isEmpty {
                    let completed = weekSessions.filter { stretchStore.isComplete($0.id) }.count
                    Text("\(completed)/\(weekSessions.count) done")
                        .font(TrailFont.meta)
                        .foregroundStyle(completed == weekSessions.count ? .green : .secondary)
                }
            }

            ForEach(exercises) { exercise in
                let complete = weekSessions.first(where: { $0.templateExerciseId == exercise.id })
                    .map { stretchStore.isComplete($0.id) } ?? false

                stretchExerciseRow(exercise, complete: complete)
                    .contextMenu {
                        Button {
                            editingStretch = exercise
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            stretchToDelete = exercise
                            showingStretchDeleteConfirmation = true
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isToday ? Color.trailGreen.opacity(0.08) : Color(.systemBackground))
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isToday ? Color.trailGreen.opacity(0.3) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if let week = planStore.currentWeekNumber {
                selectedStretchDay = StretchDaySelection(weekNumber: week, dayOfWeek: day)
            }
        }
    }

    private func stretchExerciseRow(_ exercise: StretchTemplateExercise, complete: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(complete ? .green : .secondary.opacity(0.4))

            Image(systemName: "figure.flexibility")
                .font(TrailFont.body)
                .foregroundStyle(Color.trailGreen)
                .frame(width: 32, height: 32)
                .background(Color.trailGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.stretchName)
                    .font(TrailFont.body)
                    .strikethrough(complete)
                    .foregroundStyle(complete ? .secondary : .primary)

                let perSide = exercise.isBilateral ? " each side" : ""
                Text("\(exercise.sets)x\(exercise.holdSeconds)s\(perSide)")
                    .font(TrailFont.data)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var stretchAddDayButton: some View {
        Menu {
            ForEach(1...7, id: \.self) { day in
                if !stretchStore.daysWithExercises.contains(day) {
                    Button(dayNames[day]) {
                        addStretchDay = day
                        showingAddStretch = true
                    }
                }
            }
        } label: {
            Label("Add Stretches on Another Day", systemImage: "plus.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Color.trailGreen)
        .disabled(stretchStore.daysWithExercises.count >= 7)
    }

    // MARK: - Heat Template Section

    private var heatTemplateSection: some View {
        VStack(spacing: 12) {
            if heatStore.hasSessions {
                let heatDays = heatDaysFromSessions()

                let heatDayNumbers = heatDays.map(\.day)

                ForEach(heatDays, id: \.day) { entry in
                    let highlighted = isHighlightedDay(entry.day, availableDays: heatDayNumbers)
                    let complete = heatStore.isComplete(entry.session.id)

                    HStack(spacing: 12) {
                        Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(complete ? .green : .secondary.opacity(0.4))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(dayNames[entry.day])
                                .font(TrailFont.title)

                            Text("\(entry.session.sessionType.displayName) • \(entry.session.targetDurationMinutes) min")
                                .font(TrailFont.detail)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(highlighted ? Color.orange.opacity(0.08) : Color(.systemBackground))
                    )
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(highlighted ? Color.orange.opacity(0.3) : .clear, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedHeatSession = entry.session
                    }
                    .contextMenu {
                        Button {
                            selectedHeatSession = entry.session
                        } label: {
                            Label("Edit / Log", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            heatStore.removeDay(entry.day)
                        } label: {
                            Label("Remove Day", systemImage: "trash")
                        }
                    }
                }
            } else {
                Text("No heat sessions scheduled")
                    .font(TrailFont.detail)
                    .foregroundStyle(.tertiary)
            }

            Button {
                showingAddHeatDay = true
            } label: {
                Label("Add Heat Day", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
    }

    private struct HeatDayEntry {
        let day: Int
        let session: HeatSession
    }

    private func heatDaysFromSessions() -> [HeatDayEntry] {
        let currentWeek = planStore.currentWeekNumber
        var seen = Set<Int>()
        var entries: [HeatDayEntry] = []

        // Prefer current week's session (reflects one-off edits), fall back to any week
        let sorted = heatStore.sessions.sorted { a, b in
            if a.dayOfWeek != b.dayOfWeek { return a.dayOfWeek < b.dayOfWeek }
            let aIsCurrent = a.weekNumber == currentWeek
            let bIsCurrent = b.weekNumber == currentWeek
            if aIsCurrent != bIsCurrent { return aIsCurrent }
            return a.weekNumber < b.weekNumber
        }
        for session in sorted {
            if seen.insert(session.dayOfWeek).inserted {
                entries.append(HeatDayEntry(day: session.dayOfWeek, session: session))
            }
        }
        return entries
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedSegment) {
                ForEach(StrengthTabSegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                VStack(spacing: 24) {
                    switch selectedSegment {
                    case .strength:
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.trailGreen)

                        Text("No strength program yet")
                            .font(TrailFont.title)
                            .foregroundStyle(.secondary)

                        Text("Start a strength program to track exercises alongside your runs.")
                            .font(TrailFont.detail)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        if let plan = planStore.activePlan {
                            Button {
                                strengthStore.createBlankTemplate(planId: plan.id)
                            } label: {
                                Label("Create Strength Program", systemImage: "plus.circle.fill")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                        }

                    case .stretch:
                        stretchSegmentContent

                    case .heat:
                        heatTemplateSection
                    }
                }
                .padding()
                .padding(.top, 40)
            }
        }
    }

    // MARK: - Helpers

    private func formatPrescription(sets: Int, reps: Int, weightKg: Double?, isTimed: Bool = false) -> String {
        let repsLabel = isTimed ? "\(reps)s" : "\(reps)"
        if let kg = weightKg {
            let lbs = kg * 2.205
            return "\(sets)×\(repsLabel) @ \(Int(lbs)) lbs"
        }
        return "\(sets)×\(repsLabel)"
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
    @State private var durationSeconds = 30
    @State private var weightLbs = ""
    @State private var isBodyweight = true
    @State private var isTimed = false
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

                    Toggle("Timed (hold for duration)", isOn: $isTimed)

                    if isTimed {
                        Stepper("Duration: \(durationSeconds)s", value: $durationSeconds, in: 5...300, step: 5)
                    } else {
                        Stepper("Reps: \(reps)", value: $reps, in: 1...50)
                    }

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
        let effectiveReps = isTimed ? durationSeconds : reps

        strengthStore.addExercise(
            dayOfWeek: dayOfWeek,
            name: name.trimmingCharacters(in: .whitespaces),
            sets: sets,
            reps: effectiveReps,
            weightKg: isBodyweight ? nil : weightKg,
            isBodyweight: isBodyweight,
            isTimed: isTimed,
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
    @State private var durationSeconds: Int = 30
    @State private var weightLbs: String = ""
    @State private var isBodyweight: Bool = true
    @State private var isTimed: Bool = false
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

                    Toggle("Timed (hold for duration)", isOn: $isTimed)

                    if isTimed {
                        Stepper("Duration: \(durationSeconds)s", value: $durationSeconds, in: 5...300, step: 5)
                    } else {
                        Stepper("Reps: \(reps)", value: $reps, in: 1...50)
                    }

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
                isTimed = exercise.isTimed
                if exercise.isTimed {
                    durationSeconds = exercise.targetReps
                } else {
                    reps = exercise.targetReps
                }
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
        updated.targetReps = isTimed ? durationSeconds : reps
        updated.isBodyweight = isBodyweight
        updated.isTimed = isTimed
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
        .environment(StretchStore())
        .environment(OuraService())
}
