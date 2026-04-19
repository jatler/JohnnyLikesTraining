import SwiftUI

struct WeekView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(OuraService.self) private var oura

    @State private var selectedWeek: Int = 1
    @State private var selectedSession: PlannedSession?
    @State private var hasInitialized = false
    @State private var showingPlanSetup = false

    var body: some View {
        NavigationStack {
            Group {
                if planStore.hasPlan {
                    weekContent
                } else {
                    emptyState
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Error", isPresented: Binding(
                get: { planStore.lastError != nil },
                set: { if !$0 { planStore.lastError = nil } }
            )) {
                Button("OK") { planStore.lastError = nil }
            } message: {
                Text(planStore.lastError ?? "")
            }
        }
    }

    // MARK: - Week Content

    private var weekContent: some View {
        VStack(spacing: 0) {
            weekNavigator

            if let todaySession = todaySession {
                readinessBanner(for: todaySession)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
            }

            TabView(selection: $selectedWeek) {
                ForEach(planStore.allWeekNumbers, id: \.self) { week in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            let sessions = planStore.sessions(for: week)
                                .filter { $0.workoutType != .strength }
                            ForEach(sessions) { session in
                                sessionRow(session)
                                    .onTapGesture { selectedSession = session }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }
                    .tag(week)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            if !hasInitialized {
                selectedWeek = planStore.currentWeekNumber ?? 1
                hasInitialized = true
            }
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailSheet(session: session)
        }
    }

    // MARK: - Week Navigator

    private var weekNavigator: some View {
        // Inset title + meta line 8pt so their left edge aligns with the date column
        // in the rows below (rows container pad 12 + row pad X 12 = 24, minus header pad 16 = 8).
        let titleInset: CGFloat = 8

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Week \(selectedWeek)")
                    .font(TrailFont.tabHeading)
                    .foregroundStyle(.white)
                    .padding(.leading, titleInset)

                Spacer()

                HStack(spacing: 14) {
                    Button {
                        if selectedWeek > 1 { selectedWeek -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(selectedWeek <= 1)

                    Button {
                        if selectedWeek < planStore.totalWeeks { selectedWeek += 1 }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(selectedWeek >= planStore.totalWeeks)

                    NavigationLink {
                        PlanCalendarView()
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }

            Text(weekDateRange)
                .font(TrailFont.data)
                .foregroundStyle(.white.opacity(0.85))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.leading, titleInset)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.trailGreen)
        .background(Color.trailGreen.ignoresSafeArea(edges: .top))
        .tint(.white)
    }

    private var weekDateRange: String {
        let sessions = planStore.sessions(for: selectedWeek)
        guard let first = sessions.first, let last = sessions.last else { return "" }
        let start = first.scheduledDate.formatted(.dateTime.month(.abbreviated).day())
        let end = last.scheduledDate.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) \u{2013} \(end)"
    }

    // MARK: - Session Row (Bold Day layout)

    private func sessionRow(_ session: PlannedSession) -> some View {
        let skipped = planStore.isSkipped(session.id)
        let isToday = Calendar.current.isDateInToday(session.scheduledDate)
        let activity = strava.activity(for: session.id)
        let day = Calendar.current.component(.day, from: session.scheduledDate)
        let weekday = session.scheduledDate.formatted(.dateTime.weekday(.abbreviated))
        let rangeText = session.displayTargetRange
        let hue = session.workoutType.swiftUIColor

        return ZStack(alignment: .leading) {
            // Today left accent bar (runs full row height)
            if isToday {
                Rectangle()
                    .fill(Color.trailGreen)
                    .frame(width: 4)
            }

            HStack(spacing: 0) {
                // Date column: day abbrev + numeric date, two lines, Geist Mono.
                // Date stays grey on every row — today's identity is carried by the
                // accent bar, tint, and "TODAY" pill instead.
                VStack(alignment: .leading, spacing: 4) {
                    Text(weekday.uppercased())
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

                // Workout type badge (43x43, radius 15, 15% tint)
                Image(systemName: session.workoutType.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(hue)
                    .frame(width: 43, height: 43)
                    .background(hue.opacity(0.15), in: RoundedRectangle(cornerRadius: 15))

                Spacer().frame(width: 14)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.workoutType.displayName)
                        .font(.system(size: 18))
                        .strikethrough(skipped)
                        .lineLimit(1)

                    if let rangeText {
                        Text(rangeText)
                            .font(TrailFont.data)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if session.workoutType == .rest {
                        Text("Full recovery")
                            .font(TrailFont.data)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 4)

                trailingStatus(session: session, activity: activity, skipped: skipped, isToday: isToday)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
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
    }

    @ViewBuilder
    private func trailingStatus(session: PlannedSession, activity: StravaActivity?, skipped: Bool, isToday: Bool) -> some View {
        if activity != nil {
            // Sum miles across every run on this session's date — handles doubles days
            // where multiple Strava runs land on one scheduled session.
            let dayRuns = strava.runActivities(on: session.scheduledDate)
            let dayMiles = dayRuns.reduce(0.0) { $0 + $1.distanceMi }
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.green)
                if dayMiles > 0 {
                    Text(String(format: "%.1f mi", dayMiles))
                        .font(TrailFont.data)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
            }
        } else if skipped {
            Text("Skipped")
                .font(TrailFont.meta)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
                .textCase(.uppercase)
                .tracking(0.5)
        } else if isToday {
            Text("Today")
                .font(TrailFont.meta)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.trailGreen, in: Capsule())
        }
    }

    // MARK: - Readiness banner (ported from former Today tab)

    private var todaySession: PlannedSession? {
        let today = Calendar.current.startOfDay(for: Date())
        return planStore.sessions(for: selectedWeek)
            .first { Calendar.current.isDate($0.scheduledDate, inSameDayAs: today) }
    }

    @ViewBuilder
    private func readinessBanner(for session: PlannedSession) -> some View {
        if let today = oura.todayReadiness(),
           today.readinessLevel == .low,
           session.workoutType != .easy,
           session.workoutType != .rest,
           session.workoutType != .recovery,
           !planStore.isSkipped(session.id),
           let easyDay = planStore.nearestEasyDay(for: session) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Low readiness (\(today.readinessScore ?? 0))")
                        .font(TrailFont.body)
                        .fontWeight(.semibold)
                }

                Text("Swap today's \(session.workoutType.displayName) with \(easyDay.scheduledDate.formatted(.dateTime.weekday(.wide)))'s \(easyDay.workoutType.displayName)?")
                    .font(TrailFont.body)
                    .foregroundStyle(.secondary)

                Button {
                    planStore.swapSessions(session, with: easyDay, reason: "Low readiness (\(today.readinessScore ?? 0))")
                    if let planId = planStore.activePlan?.id {
                        strengthStore.refreshFromPlannedSessions(planStore.sessions, planId: planId)
                    }
                } label: {
                    Label("Swap to \(easyDay.workoutType.displayName)", systemImage: "arrow.left.arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .controlSize(.small)
            }
            .padding(10)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundStyle(Color.trailGreen)

            Text("No plan loaded yet")
                .font(TrailFont.title)
                .foregroundStyle(.secondary)

            Text("Create a training plan to see your weekly schedule.")
                .font(TrailFont.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Set Up Your Plan") {
                showingPlanSetup = true
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .sheet(isPresented: $showingPlanSetup) {
            PlanSetupView()
        }
    }
}

#Preview {
    WeekView()
        .environment(TrainingPlanStore())
        .environment(StravaService())
        .environment(StrengthStore())
        .environment(OuraService())
}
