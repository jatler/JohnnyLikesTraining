import SwiftUI

struct StrengthTemplateView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(StretchStore.self) private var stretchStore
    @Environment(OuraService.self) private var oura

    @State private var selectedSession: StrengthSession?
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
                if strengthStore.hasSessions || stretchStore.hasTemplate {
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
            .sheet(item: $selectedSession) { session in
                StrengthDayDetailView(
                    weekNumber: session.weekNumber,
                    dayOfWeek: session.dayOfWeek
                )
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
                    .font(TrailFont.title)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Section", selection: $selectedSegment) {
                    ForEach(StrengthTabSegment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding()
            .background(Color.trailGreen)

            ScrollView {
                VStack(spacing: 12) {
                    switch selectedSegment {
                    case .strength:
                        strengthSegmentContent

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

    // MARK: - Strength Segment (Coach Notes)

    private var strengthSegmentContent: some View {
        let currentWeek = planStore.currentWeekNumber ?? 1
        let weekDays = strengthStore.daysWithSessions(for: currentWeek)

        return VStack(spacing: 12) {
            if weekDays.isEmpty {
                VStack(spacing: 8) {
                    Text("No strength sessions this week")
                        .font(TrailFont.body)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 20)
            } else {
                HStack {
                    Text("Week \(currentWeek)")
                        .font(TrailFont.title)
                    Spacer()
                    let completed = strengthStore.sessions(for: currentWeek).filter(\.isComplete).count
                    let total = strengthStore.sessions(for: currentWeek).count
                    Text("\(completed)/\(total) done")
                        .font(TrailFont.meta)
                        .foregroundStyle(completed == total ? .green : .secondary)
                }

                ForEach(weekDays, id: \.self) { day in
                    strengthDayCard(weekNumber: currentWeek, dayOfWeek: day)
                }
            }
        }
    }

    private func strengthDayCard(weekNumber: Int, dayOfWeek: Int) -> some View {
        let daySessions = strengthStore.sessions(for: weekNumber, dayOfWeek: dayOfWeek)
        let isToday = isHighlightedDay(
            dayOfWeek,
            availableDays: strengthStore.daysWithSessions(for: weekNumber)
        )

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayNames[dayOfWeek])
                    .font(TrailFont.title)

                Spacer()

                let completed = daySessions.filter(\.isComplete).count
                if completed == daySessions.count && !daySessions.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            ForEach(daySessions) { session in
                strengthSessionRow(session)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isToday ? Color.trailGreen.opacity(0.08) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isToday ? Color.trailGreen.opacity(0.3) : Color(.separator).opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedSession = daySessions.first
        }
    }

    private func strengthSessionRow(_ session: StrengthSession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                strengthStore.toggleComplete(session.id)
            } label: {
                Image(systemName: session.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(session.isComplete ? .green : .secondary.opacity(0.4))
                    .completionPulse(session.isComplete)
            }
            .buttonStyle(.plain)

            Image(systemName: "dumbbell.fill")
                .font(TrailFont.body)
                .foregroundStyle(Color.trailGreen)
                .frame(width: 32, height: 32)
                .background(Color.trailGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.label)
                    .font(TrailFont.body)
                    .strikethrough(session.isComplete)
                    .foregroundStyle(session.isComplete ? .secondary : .primary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Day Highlighting

    private var currentAdjustedDay: Int {
        let wd = Calendar.current.component(.weekday, from: Date())
        return wd == 1 ? 7 : wd - 1
    }

    private func isHighlightedDay(_ day: Int, availableDays: [Int]) -> Bool {
        let today = currentAdjustedDay
        if availableDays.contains(today) {
            return day == today
        }
        let futureDays = availableDays.filter { $0 > today }.sorted()
        let wrappedDays = availableDays.filter { $0 < today }.sorted()
        let nextDay = futureDays.first ?? wrappedDays.first
        return day == nextDay
    }

    // MARK: - Stretch Segment (unchanged)

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
                        .font(TrailFont.body)
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isToday ? Color.trailGreen.opacity(0.3) : Color(.separator).opacity(0.3), lineWidth: 1)
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

    // MARK: - Heat Template Section (unchanged)

    private var heatTemplateSection: some View {
        VStack(spacing: 12) {
            if heatStore.hasSessions {
                let heatDays = heatDaysFromSessions()

                let heatDayNumbers = heatDays.map(\.day)

                ForEach(heatDays, id: \.day) { entry in
                    let highlighted = isHighlightedDay(entry.day, availableDays: heatDayNumbers)
                    let complete = heatStore.isComplete(entry.session.id)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(dayNames[entry.day])
                                .font(TrailFont.title)

                            Spacer()

                            if complete {
                                Text("Done")
                                    .font(TrailFont.meta)
                                    .foregroundStyle(.green)
                            }
                        }

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(complete ? .green : .secondary.opacity(0.4))

                            Image(systemName: "flame.fill")
                                .font(TrailFont.body)
                                .foregroundStyle(.orange)
                                .frame(width: 32, height: 32)
                                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.session.sessionType.displayName)
                                    .font(TrailFont.body)
                                    .strikethrough(complete)
                                    .foregroundStyle(complete ? .secondary : .primary)

                                Text("\(entry.session.targetDurationMinutes) min")
                                    .font(TrailFont.data)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(highlighted ? Color.orange.opacity(0.08) : Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(highlighted ? Color.orange.opacity(0.3) : Color(.separator).opacity(0.3), lineWidth: 1)
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
                    .font(TrailFont.body)
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

                        Text("No strength sessions")
                            .font(TrailFont.title)
                            .foregroundStyle(.secondary)

                        Text("Strength workouts will appear here once you activate a training plan with coach-prescribed strength sessions.")
                            .font(TrailFont.body)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

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
}

// MARK: - Day Selection for Sheet

struct StrengthDaySelection: Identifiable {
    let id = UUID()
    let weekNumber: Int
    let dayOfWeek: Int
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
