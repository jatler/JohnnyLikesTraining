import SwiftUI

struct PlanCalendarView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(HeatStore.self) private var heatStore

    @State private var selectedSession: PlannedSession?

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        Group {
            if planStore.hasPlan {
                calendarContent
            } else {
                emptyState
            }
        }
        .navigationTitle("Plan")
    }

    // MARK: - Calendar Content

    private var calendarContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 2) {
                    if let plan = planStore.activePlan {
                        planHeader(plan)
                    }

                    colorLegend
                        .padding(.bottom, 8)

                    dayHeaderRow
                        .padding(.bottom, 4)

                    ForEach(planStore.allWeekNumbers, id: \.self) { week in
                        if shouldShowMonthHeader(for: week) {
                            monthHeader(for: week)
                        }
                        weekRow(week)
                            .id(week)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .padding(.bottom, 20)
            }
            .onAppear {
                if let current = planStore.currentWeekNumber {
                    withAnimation {
                        proxy.scrollTo(current, anchor: .center)
                    }
                }
            }
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailSheet(session: session)
        }
    }

    // MARK: - Plan Header

    private func planHeader(_ plan: TrainingPlan) -> some View {
        VStack(spacing: 4) {
            Text(plan.name)
                .font(.headline)
            HStack(spacing: 16) {
                Label(plan.raceDate.formatted(date: .abbreviated, time: .omitted), systemImage: "flag.fill")
                if let week = planStore.currentWeekNumber {
                    Text("Week \(week) of \(planStore.totalWeeks)")
                        .fontWeight(.medium)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 8)
    }

    // MARK: - Color Legend

    private var colorLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(WorkoutType.allCases) { type in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(type.swiftUIColor)
                            .frame(width: 8, height: 8)
                        Text(type.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.green)
                    Text("Done")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Day Header

    private var dayHeaderRow: some View {
        HStack(spacing: 4) {
            Text("")
                .frame(width: 32)

            ForEach(0..<7, id: \.self) { i in
                Text(dayLabels[i])
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Month Headers

    private func shouldShowMonthHeader(for week: Int) -> Bool {
        let sessions = planStore.sessions(for: week)
        guard let firstDate = sessions.first?.scheduledDate else { return false }

        guard let firstWeek = planStore.allWeekNumbers.first else { return true }
        if week == firstWeek { return true }

        let prevSessions = planStore.sessions(for: week - 1)
        guard let prevDate = prevSessions.first?.scheduledDate else { return true }

        return Calendar.current.component(.month, from: firstDate) != Calendar.current.component(.month, from: prevDate)
    }

    private func monthHeader(for week: Int) -> some View {
        let sessions = planStore.sessions(for: week)
        let date = sessions.first?.scheduledDate ?? Date()

        return Text(date.formatted(.dateTime.month(.wide).year()))
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, week == planStore.allWeekNumbers.first ? 0 : 12)
            .padding(.bottom, 4)
    }

    // MARK: - Week Row

    private func weekRow(_ weekNumber: Int) -> some View {
        let weekSessions = planStore.sessions(for: weekNumber)
        let isCurrentWeek = planStore.currentWeekNumber == weekNumber

        let primarySessions = Dictionary(grouping: weekSessions, by: \.dayOfWeek)
            .compactMap { (_, daySessions) in daySessions.first(where: { $0.workoutType != .strength }) ?? daySessions.first }
            .sorted { $0.dayOfWeek < $1.dayOfWeek }

        let daysWithStrength = Set(
            weekSessions.filter { $0.workoutType == .strength }.map(\.dayOfWeek)
        )

        let heatWeekSessions = heatStore.sessions(for: weekNumber)
        let daysWithHeat = Set(heatWeekSessions.map(\.dayOfWeek))
        let daysWithHeatDone = Set(heatWeekSessions.filter { heatStore.isComplete($0.id) }.map(\.dayOfWeek))

        return HStack(spacing: 4) {
            Text("W\(weekNumber)")
                .font(.caption2.bold())
                .foregroundStyle(isCurrentWeek ? .blue : .secondary)
                .frame(width: 32)

            ForEach(primarySessions) { session in
                dayCell(
                    session,
                    isCurrentWeek: isCurrentWeek,
                    hasStrength: daysWithStrength.contains(session.dayOfWeek),
                    hasHeat: daysWithHeat.contains(session.dayOfWeek),
                    heatDone: daysWithHeatDone.contains(session.dayOfWeek)
                )
                .onTapGesture { selectedSession = session }
            }
        }
    }

    // MARK: - Day Cell

    private func dayCell(_ session: PlannedSession, isCurrentWeek: Bool, hasStrength: Bool = false, hasHeat: Bool = false, heatDone: Bool = false) -> some View {
        let isToday = Calendar.current.isDateInToday(session.scheduledDate)
        let skipped = planStore.isSkipped(session.id)
        let overridden = planStore.isOverridden(session.id)
        let dayNum = Calendar.current.component(.day, from: session.scheduledDate)
        let hasActivity = strava.activity(for: session.id) != nil

        return VStack(spacing: 2) {
            Text("\(dayNum)")
                .font(.caption2)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? .primary : .secondary)

            ZStack {
                Image(systemName: session.workoutType.iconName)
                    .font(.system(size: 10))
                    .foregroundStyle(session.workoutType.swiftUIColor)

                if hasActivity {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.green)
                        .offset(x: 8, y: -6)
                }

                if hasStrength {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.indigo)
                        .offset(x: -8, y: -6)
                }

                if overridden {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.orange)
                        .offset(x: 8, y: 6)
                }

                if hasHeat {
                    Image(systemName: heatDone ? "checkmark.circle.fill" : "flame.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(heatDone ? .green : .orange)
                        .offset(x: -8, y: 6)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(session.workoutType.swiftUIColor.opacity(skipped ? 0.08 : 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isToday ? Color.primary : .clear, lineWidth: 1.5)
        )
        .opacity(skipped ? 0.5 : 1.0)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("No plan loaded yet")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Create a training plan to see your full schedule.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        PlanCalendarView()
    }
    .environment(TrainingPlanStore())
    .environment(StravaService())
    .environment(HeatStore())
}
