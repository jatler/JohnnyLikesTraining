import SwiftUI

struct WeekView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(OuraService.self) private var oura
    @Environment(AuthService.self) private var auth

    @State private var selectedWeek: Int = 1
    @State private var selectedSession: PlannedSession?
    @State private var hasInitialized = false
    @State private var showingPlanSetup = false
    @State private var syncError: String?

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
            .alert("Sync Failed", isPresented: Binding(
                get: { syncError != nil },
                set: { if !$0 { syncError = nil } }
            )) {
                Button("OK") { syncError = nil }
            } message: {
                Text(syncError ?? "")
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

            tuesdayBanner
                .padding(.horizontal, 12)
                .padding(.top, 12)

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
                    // .always so pull-to-refresh works even when the week has few rows
                    // and the content doesn't fill the viewport. Without this, short
                    // weeks silently swallow the down-swipe gesture.
                    .scrollBounceBehavior(.always)
                    .refreshable { await sync() }
                    .tint(Color.trailGreen)
                    .tag(week)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .frame(maxHeight: .infinity)
        .onPreferenceChange(BannerHeightKey.self) { height in
            BannerGapDetent.bannerHeight = height
        }
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

                HStack(spacing: 0) {
                    NavigationLink {
                        PlanCalendarView()
                    } label: {
                        Image(systemName: "calendar")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }

                    Button {
                        // withAnimation so chevron taps mirror the TabView's
                        // page-style swipe — without it the week change is
                        // instant while a swipe slides smoothly.
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
                        if selectedWeek < planStore.totalWeeks {
                            withAnimation { selectedWeek += 1 }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(selectedWeek >= planStore.totalWeeks)
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
        .padding(.vertical, 13)
        .background(Color.trailGreen)
        .background(Color.trailGreen.ignoresSafeArea(edges: .top))
        .tint(.white)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: BannerHeightKey.self, value: geo.size.height)
            }
        )
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

        return HStack(spacing: 0) {
            // Date column: day abbrev + numeric date, two lines, Geist Mono.
            // Date stays grey on every row — today's identity is carried by the
            // tint + stroke + "TODAY" pill.
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
    }

    @ViewBuilder
    private func trailingStatus(session: PlannedSession, activity: StravaActivity?, skipped: Bool, isToday: Bool) -> some View {
        if let activity {
            // Run miles always win the label: a day with an easy run + a bike
            // commute should read "6.2 mi", not the commute's hours, no matter
            // which activity happened to win the session match. Miles sum
            // across every run on the day (doubles days). Cross-train hours
            // only show when the day had no run at all.
            let dayMiles = strava.runActivities(on: session.scheduledDate).reduce(0.0) { $0 + $1.distanceMi }
            if dayMiles > 0 {
                CompleteStatus(
                    magnitude: dayMiles,
                    label: String(format: "%.1f mi", dayMiles),
                    sessionId: session.id
                )
            } else if activity.isCrossTraining {
                // Sum cross-training hours across every cross-train activity on
                // this session's date — parallel to how runs aggregate miles.
                let crossDay = strava.activities(on: session.scheduledDate).filter(\.isCrossTraining)
                let hours = crossDay.reduce(0.0) { $0 + Double($1.movingTimeSeconds) } / 3600.0
                CompleteStatus(
                    magnitude: hours,
                    label: String(format: "%.1f hr", hours),
                    sessionId: session.id
                )
            } else {
                // Matched something with no run mileage (strength, yoga) —
                // completion dot, no label.
                CompleteStatus(
                    magnitude: 0,
                    label: "",
                    sessionId: session.id
                )
            }
        } else if planStore.isManuallyComplete(session.id) {
            // User pressed Mark Done in the detail sheet without a Strava match.
            // Same burst-on-first-appearance as the Strava-match path so manual
            // completion feels like the same celebration. No mileage label.
            CompleteStatus(
                magnitude: 20,
                label: "",
                sessionId: session.id
            )
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

    // MARK: - Sync (pull-to-refresh)

    private func sync() async {
        #if DEBUG
        // The pull-to-refresh UI test passes a marker path so it can verify the
        // gesture actually reaches this method — it has silently broken before.
        if let marker = ProcessInfo.processInfo.environment["PTR_SYNC_MARKER"] {
            try? "fired \(Date())".write(toFile: marker, atomically: true, encoding: .utf8)
        }
        #endif
        guard let userId = auth.currentUserId else { return }
        // Run Strava + Oura concurrently — they share nothing, so while
        // one is awaiting URLSession the other can be in flight. Strava
        // passes `after:` so a typical "nothing new" pull skips the
        // 6-month default scan and just checks the last couple days
        // (48h overlap covers late watch uploads). merge:true so a
        // transient API blip doesn't wipe the local cache.
        async let stravaDone: Void = syncStravaIfConnected(userId: userId)
        async let ouraDone:   Void = syncOuraIfConnected(userId: userId)
        _ = await (stravaDone, ouraDone)
    }

    private func syncStravaIfConnected(userId: UUID) async {
        guard strava.isConnected else { return }
        do {
            try await strava.syncActivities(userId: userId, after: strava.incrementalSyncCutoff, merge: true)
        } catch is CancellationError {
            // User dismissed the refresh or paged away — not an error.
        } catch {
            // Never fail silently — a swallowed error here is indistinguishable
            // from "pull-to-refresh is broken."
            syncError = error.localizedDescription
        }
        strava.autoMatchActivities(sessions: planStore.sessions)
    }

    private func syncOuraIfConnected(userId: UUID) async {
        guard oura.isConnected else { return }
        try? await oura.syncDaily(userId: userId, merge: true)
    }

    // MARK: - Tuesday podcast banner

    @ViewBuilder
    private var tuesdayBanner: some View {
        if Calendar.current.component(.weekday, from: Date()) == 3 {
            Link(destination: URL(string: "https://open.spotify.com/show/3AaJYZngimocFf8aztKTcO")!) {
                HStack(spacing: 12) {
                    Image(systemName: "headphones")
                        .foregroundStyle(Color.trailGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Happy Tuesday! It's Tuesday!")
                            .font(TrailFont.body)
                            .foregroundStyle(.primary)
                        Text("Listen to the latest SWAP podcast")
                            .font(TrailFont.meta)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(10)
                .background(Color.trailGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.trailGreen.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
            }
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
            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
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

// MARK: - Run-complete trailing status

/// Replaces the static checkmark + miles label with the miles-aware burst
/// animation. Tuned in `MilesCompletionPrototype` and frozen in
/// `CompletionParams.burst`. Plays once when the row first appears.
#Preview {
    WeekView()
        .environment(TrainingPlanStore())
        .environment(StravaService())
        .environment(StrengthStore())
        .environment(OuraService())
        .environment(AuthService())
}
