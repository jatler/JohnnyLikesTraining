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
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Calendar Content

    private var calendarContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 2) {
                    if let plan = planStore.activePlan {
                        planHeader(plan)
                    }

                    ForEach(planStore.allWeekNumbers, id: \.self) { week in
                        if shouldShowMonthHeader(for: week) {
                            monthHeader(for: week)
                            dayHeaderRow
                                .padding(.bottom, 4)
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
                .font(TrailFont.title)
            HStack(spacing: 16) {
                Label(plan.raceDate.formatted(date: .abbreviated, time: .omitted), systemImage: "flag.fill")
                if let week = planStore.currentWeekNumber {
                    Text("Week \(week) of \(planStore.totalWeeks)")
                        .fontWeight(.medium)
                }
            }
            .font(TrailFont.meta)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 8)
    }

    // MARK: - Day Header

    private var dayHeaderRow: some View {
        HStack(spacing: 4) {
            Text("")
                .frame(width: 32)

            ForEach(0..<7, id: \.self) { i in
                Text(dayLabels[i])
                    .font(TrailFont.meta)
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
            .font(TrailFont.body)
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

        return HStack(spacing: 4) {
            Text("W\(weekNumber)")
                .font(TrailFont.meta)
                .foregroundStyle(isCurrentWeek ? Color.trailGreen : .secondary)
                .frame(width: 32)

            ForEach(primarySessions) { session in
                dayCell(session)
                    .onTapGesture { selectedSession = session }
            }
        }
    }

    // MARK: - Day Cell

    private func dayCell(_ session: PlannedSession) -> some View {
        let isToday = Calendar.current.isDateInToday(session.scheduledDate)
        let skipped = planStore.isSkipped(session.id)
        let hasActivity = strava.activity(for: session.id) != nil

        return ZStack(alignment: .bottomTrailing) {
            Image(systemName: session.workoutType.iconName)
                .font(.system(size: 18))
                .foregroundStyle(session.workoutType.swiftUIColor)
                .frame(maxWidth: .infinity)
                .frame(height: 40)

            if hasActivity {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.trailGreen)
                    .background(Circle().fill(Color(.systemBackground)))
                    .padding(.trailing, 3)
                    .padding(.bottom, 3)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? Color.trailGreenSubtle : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isToday ? Color.trailGreen : Color.clear, lineWidth: 2)
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
                .font(TrailFont.title)
                .foregroundStyle(.secondary)

            Text("Create a training plan to see your full schedule.")
                .font(TrailFont.body)
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
