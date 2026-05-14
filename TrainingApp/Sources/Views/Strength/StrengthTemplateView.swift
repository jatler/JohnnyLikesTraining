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
    @State private var showingAddStrengthDay = false
    @State private var selectedWeek: Int = 1
    @State private var hasInitializedWeek = false

    private let dayAbbrev = ["", "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private let dayNames = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    enum StrengthTabSegment: String, CaseIterable {
        case strength = "Strength"
        case heat = "Heat"
        case stretch = "Stretch"
    }

    private enum RowState { case done, today, upcoming, skipped }

    private struct RowItem: Identifiable {
        let id: AnyHashable
        let dayOfWeek: Int
        let scheduledDate: Date
        let title: String
        let detail: String?
        let hue: Color
        let icon: String
        let state: RowState
        let onTap: () -> Void
    }

    var body: some View {
        NavigationStack {
            Group {
                if strengthStore.hasSessions || stretchStore.hasTemplate || heatStore.hasSessions {
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
            .sheet(isPresented: $showingAddStrengthDay) {
                AddStrengthDaySheet()
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

    // MARK: - Layout

    private var templateContent: some View {
        VStack(spacing: 0) {
            header
            segmentedPicker
            // Week-paginated content — same pattern as WeekView. Each week is its
            // own ScrollView so the swipe gesture is owned by the TabView and
            // doesn't fight per-row scroll.
            TabView(selection: $selectedWeek) {
                ForEach(planStore.allWeekNumbers, id: \.self) { week in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            switch selectedSegment {
                            case .strength: strengthRows(for: week)
                            case .stretch:  stretchRows(for: week)
                            case .heat:     heatRows(for: week)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .padding(.bottom, 20)
                    }
                    .tag(week)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .onAppear {
            if !hasInitializedWeek {
                selectedWeek = planStore.currentWeekNumber ?? planStore.allWeekNumbers.first ?? 1
                hasInitializedWeek = true
            }
            syncStrengthFromPlan()
        }
        .onChange(of: planStore.allWeekNumbers) { _, _ in syncStrengthFromPlan() }
    }

    private var header: some View {
        // Two-line green bar — matches Week / Progress / Settings vertical
        // height. Title "Strength + Heat" stays as the tab's identity; week
        // selector + date range share line two so the bar doesn't grow.
        let total = planStore.totalWeeks

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Strength + Heat")
                    .font(TrailFont.tabHeading)
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 0) {
                    Button {
                        if selectedWeek > 1 {
                            withAnimation { selectedWeek -= 1 }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(selectedWeek <= 1)

                    Button {
                        if selectedWeek < total {
                            withAnimation { selectedWeek += 1 }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(selectedWeek >= total)
                }
            }

            // "WEEK 04 · MAR 4 — MAR 10" — keeps the week indicator and the
            // date range on a single line so the bar stays two lines tall.
            Text(weekLine(for: selectedWeek))
                .font(TrailFont.data)
                .foregroundStyle(.white.opacity(0.85))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.trailGreen)
        .background(Color.trailGreen.ignoresSafeArea(edges: .top))
        .tint(.white)
    }

    private func weekLine(for week: Int) -> String {
        let range = weekDateRange(for: week)
        let label = String(format: "Week %02d", week)
        if range.isEmpty { return label }
        return "\(label) \u{00B7} \(range)"
    }

    private var segmentedPicker: some View {
        Picker("Section", selection: $selectedSegment) {
            ForEach(StrengthTabSegment.allCases, id: \.self) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func weekDateRange(for week: Int) -> String {
        let weekSessions = planStore.sessions(for: week)
        guard let first = weekSessions.first?.scheduledDate,
              let last  = weekSessions.last?.scheduledDate else {
            return ""
        }
        let start = first.formatted(.dateTime.month(.abbreviated).day())
        let end   = last.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) \u{2013} \(end)"
    }

    /// Pull any newly-added coach-prescribed strength sessions out of the plan
    /// (e.g. the "Mountain Lakes" hike) into StrengthStore so they render here.
    private func syncStrengthFromPlan() {
        guard let planId = planStore.activePlan?.id else { return }
        strengthStore.refreshFromPlannedSessions(planStore.sessions, planId: planId)
    }

    // MARK: - Segment Rows

    private func strengthRows(for week: Int) -> some View {
        let sessions = strengthStore.sessions(for: week).sorted { $0.dayOfWeek < $1.dayOfWeek }

        return Group {
            if sessions.isEmpty {
                emptySegmentMessage(icon: "dumbbell.fill", text: "No strength sessions this week")
            } else {
                ForEach(sessions) { session in
                    let parts = strengthRowParts(coachNotes: session.coachNotes)
                    boldDayRow(item: RowItem(
                        id: session.id,
                        dayOfWeek: session.dayOfWeek,
                        scheduledDate: session.scheduledDate,
                        title: parts.title,
                        detail: parts.detail,
                        hue: .trailGreen,
                        icon: "dumbbell.fill",
                        state: rowState(
                            isDone: session.isComplete,
                            scheduledDate: session.scheduledDate
                        ),
                        onTap: { selectedSession = session }
                    ))
                }
            }

            strengthAddDayButton
        }
    }

    /// Split strength coach notes into a row title (short headline) and detail
    /// (the prescription that follows). Falls back to the whole label if there's
    /// no clean split.
    ///
    /// Examples:
    ///   "Mountain Legs. 3x10 step-ups, 3x10 calf raises." → ("Mountain Legs", "3x10 step-ups, 3x10 calf raises.")
    ///   "Squat 3x5, RDL 3x8" → ("Squat 3x5, RDL 3x8", nil)
    private func strengthRowParts(coachNotes: String) -> (title: String, detail: String?) {
        let trimmed = coachNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return ("Strength", nil) }

        // Prefer a colon split — common in templates ("Mountain Legs: 3x10...").
        if let colonIdx = trimmed.firstIndex(of: ":") {
            let title = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let rest  = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            if !title.isEmpty, !rest.isEmpty, title.count <= 40 {
                return (title, rest)
            }
        }

        // Otherwise split on the first sentence boundary, but only when the
        // headline is short enough to read as a title.
        if let dotIdx = trimmed.firstIndex(of: ".") {
            let title = String(trimmed[..<dotIdx]).trimmingCharacters(in: .whitespaces)
            let after = trimmed.index(after: dotIdx)
            let rest  = after < trimmed.endIndex
                ? String(trimmed[after...]).trimmingCharacters(in: .whitespaces)
                : ""
            if !title.isEmpty, !rest.isEmpty, title.count <= 40 {
                return (title, rest)
            }
        }

        // Single-line note — show as title only.
        if trimmed.count <= 60 { return (trimmed, nil) }
        return (String(trimmed.prefix(57)) + "…", nil)
    }

    private var strengthAddDayButton: some View {
        Button {
            showingAddStrengthDay = true
        } label: {
            Label("Add Strength on Another Day", systemImage: "plus.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Color.trailGreen)
        .padding(.top, 12)
    }

    private func stretchRows(for week: Int) -> some View {
        let days = stretchStore.daysWithExercises

        return Group {
            if !stretchStore.hasTemplate {
                stretchEmptyState
            } else if days.isEmpty {
                emptySegmentMessage(icon: "figure.flexibility", text: "No stretches scheduled this week")
                stretchAddDayButton
            } else {
                ForEach(days, id: \.self) { day in
                    let exercises = stretchStore.exercises(for: day)
                    let sessions = stretchStore.sessions(for: week, dayOfWeek: day)
                    let total = sessions.count
                    let done = sessions.filter { stretchStore.isComplete($0.id) }.count
                    let scheduled = sessions.first?.scheduledDate ?? dateFor(week: week, dayOfWeek: day)
                    let title = exercises.first?.stretchName ?? "Stretches"
                    let detail = total > 0 ? "\(total) stretches · \(done)/\(total) done" : "\(exercises.count) stretches"

                    boldDayRow(item: RowItem(
                        id: day,
                        dayOfWeek: day,
                        scheduledDate: scheduled,
                        title: exercises.count > 1 ? "\(title) +\(exercises.count - 1)" : title,
                        detail: detail,
                        hue: Color.mint,
                        icon: "figure.flexibility",
                        state: rowState(
                            isDone: total > 0 && done == total,
                            scheduledDate: scheduled
                        ),
                        onTap: {
                            selectedStretchDay = StretchDaySelection(weekNumber: week, dayOfWeek: day)
                        }
                    ))
                    .contextMenu {
                        ForEach(exercises) { ex in
                            Button {
                                editingStretch = ex
                            } label: {
                                Label("Edit \(ex.stretchName)", systemImage: "pencil")
                            }
                        }
                        ForEach(exercises) { ex in
                            Button(role: .destructive) {
                                stretchToDelete = ex
                                showingStretchDeleteConfirmation = true
                            } label: {
                                Label("Remove \(ex.stretchName)", systemImage: "trash")
                            }
                        }
                    }
                }
                stretchAddDayButton
            }
        }
    }

    private func heatRows(for week: Int) -> some View {
        let entries = heatDaysFromSessions()

        return Group {
            if entries.isEmpty {
                emptySegmentMessage(icon: "flame.fill", text: "No heat sessions scheduled")
            } else {
                ForEach(entries, id: \.day) { entry in
                    let isDone = heatStore.isComplete(entry.session.id)
                    let actual = heatStore.log(for: entry.session.id)?.actualDurationMinutes
                    let scheduled = currentWeekHeatDate(for: entry.day, fallback: entry.session.scheduledDate, week: week)
                    let detailMin = actual ?? entry.session.targetDurationMinutes

                    boldDayRow(item: RowItem(
                        id: entry.session.id,
                        dayOfWeek: entry.day,
                        scheduledDate: scheduled,
                        title: entry.session.sessionType.displayName,
                        detail: "\(detailMin) min",
                        hue: entry.session.sessionType.color,
                        icon: entry.session.sessionType.iconName,
                        state: rowState(isDone: isDone, scheduledDate: scheduled),
                        onTap: { selectedHeatSession = entry.session }
                    ))
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
            }

            Button {
                showingAddHeatDay = true
            } label: {
                Label("Add Heat Day", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .padding(.top, 12)
        }
    }

    // MARK: - Bold Day Row

    private func boldDayRow(item: RowItem) -> some View {
        let isToday = item.state == .today
        let isSkip = item.state == .skipped
        let day = Calendar.current.component(.day, from: item.scheduledDate)
        let weekday = dayAbbrev[item.dayOfWeek]

        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(weekday)
                    .font(TrailFont.data)
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                    .opacity(0.75)
                Text(String(format: "%02d", day))
                    .font(TrailFont.title)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 42, alignment: .leading)

            Spacer().frame(width: 9)

            Image(systemName: item.icon)
                .font(.system(size: 20))
                .foregroundStyle(item.hue)
                .frame(width: 43, height: 43)
                .background(item.hue.opacity(0.15), in: RoundedRectangle(cornerRadius: 15))

            Spacer().frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 18))
                    .strikethrough(isSkip)
                    .lineLimit(1)

                if let detail = item.detail {
                    Text(detail)
                        .font(TrailFont.data)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            rowTrailing(state: item.state)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: 67)
        .background(
            isToday ? Color.trailGreen.opacity(0.07) : Color(.systemBackground),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    isToday ? Color.trailGreen.opacity(0.33) : Color(.separator).opacity(0.3),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture { item.onTap() }
    }

    @ViewBuilder
    private func rowTrailing(state: RowState) -> some View {
        switch state {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green)
        case .skipped:
            Text("Skipped")
                .font(TrailFont.meta)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
                .textCase(.uppercase)
                .tracking(0.5)
        case .today:
            Text("Today")
                .font(TrailFont.meta)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.trailGreen, in: Capsule())
        case .upcoming:
            EmptyView()
        }
    }

    private func rowState(isDone: Bool, scheduledDate: Date) -> RowState {
        if isDone { return .done }
        if Calendar.current.isDateInToday(scheduledDate) { return .today }
        return .upcoming
    }

    // MARK: - Helpers

    private func emptySegmentMessage(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(TrailFont.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var stretchEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.flexibility")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No stretches yet.")
                .font(TrailFont.body)
                .foregroundStyle(.secondary)

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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
        .padding(.top, 12)
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

    /// Pick the heat session's date for the *current* week if one exists;
    /// otherwise fall back to the dedup-pick's own scheduled date.
    private func currentWeekHeatDate(for day: Int, fallback: Date, week: Int) -> Date {
        if let s = heatStore.sessions.first(where: { $0.weekNumber == week && $0.dayOfWeek == day }) {
            return s.scheduledDate
        }
        return fallback
    }

    /// Estimate a date for a stretch day if no session exists (rare — empty week).
    private func dateFor(week: Int, dayOfWeek: Int) -> Date {
        let weekSessions = planStore.sessions(for: week)
        guard let monday = weekSessions.first?.scheduledDate else { return Date.distantPast }
        return Calendar.current.date(byAdding: .day, value: dayOfWeek - 1, to: monday) ?? monday
    }

    // MARK: - Empty State (no plan / no template / no heat)

    private var emptyState: some View {
        VStack(spacing: 0) {
            header
            segmentedPicker
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedSegment {
                    case .strength:
                        emptySegmentMessage(icon: "dumbbell.fill", text: "No strength sessions yet.")
                        Text("Strength workouts appear here once you activate a training plan with coach-prescribed strength sessions.")
                            .font(TrailFont.body)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    case .stretch:
                        stretchEmptyState
                    case .heat:
                        emptySegmentMessage(icon: "flame.fill", text: "No heat sessions yet.")
                        Button {
                            showingAddHeatDay = true
                        } label: {
                            Label("Add Heat Day", systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }
                .padding(.top, 40)
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct AddStrengthDaySheet: View {
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDay: Int = 1
    @State private var coachNotes: String = ""

    private let dayNames = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var availableDays: [Int] {
        let usedDays = Set(strengthStore.sessions.map(\.dayOfWeek))
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

                Section("Notes") {
                    TextField("Title or coach notes", text: $coachNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Strength Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addStrengthDay() }
                        .disabled(availableDays.isEmpty || coachNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let first = availableDays.first {
                    selectedDay = first
                }
            }
        }
    }

    private func addStrengthDay() {
        guard let plan = planStore.activePlan else { return }
        let totalWeeks = planStore.sessions.map(\.weekNumber).max() ?? 1

        strengthStore.addDay(
            dayOfWeek: selectedDay,
            coachNotes: coachNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            planId: plan.id,
            planStartDate: plan.planStartDate,
            totalWeeks: totalWeeks
        )
        dismiss()
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
