import SwiftUI
import UIKit

struct ProgressDashboardView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(OuraService.self) private var oura
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(StretchStore.self) private var stretchStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(AuthService.self) private var auth

    @State private var showingPlanSetup = false
    @State private var focusedWeek: Int = 1
    @State private var selectedChartPage: ChartPage = .miles

    private enum ChartPage: Int, CaseIterable, Identifiable {
        case miles, vert, time
        var id: Int { rawValue }
    }

    init() {
        // Global UIPageControl tint — affects every page-style TabView in the app.
        // WeekView's TabView uses indexDisplayMode: .never so it's invisible there. If a
        // future surface enables page dots, it'll inherit this black-on-grey tint.
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor.label
        UIPageControl.appearance().pageIndicatorTintColor = UIColor.systemGray3
    }

    var body: some View {
        NavigationStack {
            Group {
                if planStore.hasPlan {
                    VStack(spacing: 0) {
                        header
                        content
                    }
                } else {
                    emptyState
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: primeFocusedWeek)
            .onChange(of: planStore.allWeekNumbers) { _, _ in primeFocusedWeek() }
        }
    }

    // MARK: - Header

    private var header: some View {
        // Two-line green bar matching Week / Strength: tabHeading + a single
        // data-style sub-line so the vertical height lines up across tabs.
        // Chevrons drive `focusedWeek`, paralleling the existing drag-to-swipe
        // on the focused-week card so the user has both a tap and a swipe path.
        let firstWeek = planStore.allWeekNumbers.first ?? 1
        let lastWeek = planStore.allWeekNumbers.last ?? 1

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Progress")
                    .font(TrailFont.tabHeading)
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 0) {
                    Button {
                        if focusedWeek > firstWeek {
                            // Match the focused-week card's drag-end animation
                            // (.easeOut 0.22) so chevron taps and swipes feel
                            // like the same gesture.
                            withAnimation(.easeOut(duration: 0.22)) {
                                focusedWeek -= 1
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(focusedWeek <= firstWeek)

                    Button {
                        if focusedWeek < lastWeek {
                            withAnimation(.easeOut(duration: 0.22)) {
                                focusedWeek += 1
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(focusedWeek >= lastWeek)
                }
            }

            Text(secondaryHeaderLine)
                .font(TrailFont.data)
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.trailGreen)
        .background(Color.trailGreen.ignoresSafeArea(edges: .top))
        .tint(.white)
    }

    /// Sub-line under "Progress" in the header. Template name when present,
    /// otherwise the focused-week date range — guarantees a non-empty line
    /// so the bar height stays in sync with Week / Strength.
    private var secondaryHeaderLine: String {
        if let name = planStore.currentTemplate?.name {
            return name.uppercased()
        }
        return weekDateRange(for: focusedWeek)
    }

    private func weekDateRange(for week: Int) -> String {
        let sessions = planStore.sessions(for: week)
        guard let first = sessions.first?.scheduledDate,
              let last = sessions.last?.scheduledDate else { return "" }
        let start = first.formatted(.dateTime.month(.abbreviated).day())
        let end = last.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) \u{2013} \(end)"
    }

    // MARK: - Content

    private var content: some View {
        let entries = computeWeeklyEntries()
        return ScrollView {
            VStack(spacing: 10) {
                focusedWeekCard(entries: entries)
                TabView(selection: $selectedChartPage) {
                    mileageCard(entries: entries).tag(ChartPage.miles)
                    elevationCard(entries: entries).tag(ChartPage.vert)
                    timeCard(entries: entries).tag(ChartPage.time)
                }
                // Native page dots hidden — we render our own below the card
                // so they sit outside the shadow and can be tinted per-page.
                .tabViewStyle(.page(indexDisplayMode: .never))
                // +8pt to compensate for the 4pt vertical margin each card now
                // claims for its shadow, +8pt more for the chart's top y-axis
                // label gutter (188pt chart body = 8pt top + 160pt body + 20pt
                // week labels).
                .frame(height: 264)
                chartPageDots
                raceCard(entries: entries)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .refreshable { await sync() }
        .tint(Color.trailGreen)
    }

    /// Custom page indicator below the chart card. Each dot is tinted to match
    /// the corresponding stat pill in the focused-week card above
    /// (miles=trailGreen, vert=purple, time=orange). Grey when not selected.
    private var chartPageDots: some View {
        HStack(spacing: 8) {
            ForEach(ChartPage.allCases) { page in
                Circle()
                    // systemGray2 over systemGray3: at arm's length the lighter
                    // grey nearly vanished against the off-white background, so
                    // users couldn't tell there were three pages until they
                    // swiped. One step darker restores the affordance.
                    .fill(page == selectedChartPage ? color(for: page) : Color(.systemGray2))
                    .frame(width: 8, height: 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedChartPage = page
                        }
                    }
            }
        }
        // Anchor the dots to the chart card above them, not the race card
        // below: 0pt top + 12pt bottom (on top of the 10pt VStack spacing
        // either side) reads as "belongs to the chart" instead of orphaned.
        .padding(.top, 0)
        .padding(.bottom, 12)
    }

    private func color(for page: ChartPage) -> Color {
        switch page {
        case .miles: return Color.trailGreen
        case .vert:  return Color.trailPurple
        case .time:  return .orange
        }
    }

    private func sync() async {
        guard let userId = auth.currentUserId else { return }
        // Pull from the source APIs, not just the Supabase cache — see WeekView.sync().
        if strava.isConnected {
            try? await strava.syncActivities(userId: userId, merge: true)
            strava.autoMatchActivities(sessions: planStore.sessions)
        }
        if oura.isConnected {
            try? await oura.syncDaily(userId: userId, merge: true)
        }
    }

    // MARK: - Focused Week Card

    private func focusedWeekCard(entries: [WeekProgressEntry]) -> some View {
        let entry = entries.first(where: { $0.week == focusedWeek }) ?? entries.first
        let isCurrent = entry?.isCurrent == true
        let isFuture = entry?.isFuture == true
        let canGoPrev = focusedWeek > (entries.first?.week ?? 1)
        let canGoNext = focusedWeek < (entries.last?.week ?? 1)

        // Card SHELL is static — background, border, shadow stay put on swipe.
        // Only the INNER text content slides in/out via .id + .transition. This
        // avoids the prior bug where the whole card (shadow included) animated
        // and the week number appeared to "break" mid-transition.
        return ZStack {
            focusedWeekCardContent(entry: entry, isCurrent: isCurrent)
                .id(focusedWeek)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrent ? Color.trailGreenSubtle : Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(isCurrent ? Color.trailGreen.opacity(0.33) : Color(.separator).opacity(0.3),
                              lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        .opacity(isFuture ? 0.65 : 1)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.width < 0, canGoNext {
                        withAnimation(.easeOut(duration: 0.22)) {
                            focusedWeek = min(focusedWeek + 1, entries.last?.week ?? focusedWeek)
                        }
                    } else if value.translation.width > 0, canGoPrev {
                        withAnimation(.easeOut(duration: 0.22)) {
                            focusedWeek = max(focusedWeek - 1, entries.first?.week ?? focusedWeek)
                        }
                    }
                }
        )
    }

    @ViewBuilder
    private func focusedWeekCardContent(entry: WeekProgressEntry?, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WK")
                        .font(TrailFont.data).tracking(0.5)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%02d", entry?.week ?? 0))
                        .font(TrailFont.bigNumber)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 38, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry?.rangeLabel.uppercased() ?? "")
                        .font(TrailFont.data).tracking(0.4)
                        .foregroundStyle(.secondary)
                    Text(entry.map(phaseLabel) ?? "—")
                        .font(.system(size: 18))
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
            }

            Divider().padding(.top, 8).padding(.bottom, 8)

            HStack(alignment: .top, spacing: 8) {
                focusedStat(
                    label: "MILES",
                    primary: entry?.actualMi.map { String(format: "%.1f", $0) } ?? "—",
                    primaryColor: entry?.actualMi != nil ? Color.trailGreen : .secondary,
                    secondary: "/\(String(format: "%.1f", entry?.plannedMi ?? 0)) mi"
                )
                focusedStat(
                    label: "VERT",
                    primary: entry?.elevationGainFt.map { formatFt($0) } ?? "—",
                    primaryColor: entry?.elevationGainFt != nil ? Color.trailPurple : .secondary,
                    secondary: "ft",
                    alignment: .center
                )
                focusedStat(
                    label: "CROSS-TRAIN",
                    primary: entry?.crossTrainHours.map { String(format: "%.1f", $0) } ?? "—",
                    primaryColor: entry?.crossTrainHours != nil ? .orange : .secondary,
                    secondary: "hr"
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func focusedStat(label: String, primary: String, primaryColor: Color, secondary: String, alignment: Alignment = .leading) -> some View {
        VStack(alignment: alignment.horizontal, spacing: 3) {
            Text(label)
                .font(TrailFont.data).tracking(0.4)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(primary)
                    .font(TrailFont.bigNumber)
                    .foregroundStyle(primaryColor)
                Text(secondary)
                    .font(TrailFont.data)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func phaseLabel(for entry: WeekProgressEntry) -> String {
        let total = planStore.totalWeeks
        guard total > 0 else { return "Week \(entry.week)" }
        if entry.week == total { return "Race Week" }
        let pct = Double(entry.week) / Double(total)
        if pct <= 0.30 { return "Base" }
        if pct <= 0.60 { return "Build" }
        if pct <= 0.80 { return "Peak" }
        return "Taper"
    }

    // MARK: - Mileage Card

    private func mileageCard(entries: [WeekProgressEntry]) -> some View {
        let elapsed = entries.filter { !$0.isFuture }
        let completedOnly = entries.filter { !$0.isFuture && !$0.isCurrent }
        let completedMilesTotal = elapsed.reduce(0.0) { $0 + ($1.actualMi ?? 0) }
        let avgMilesBase = completedOnly.reduce(0.0) { $0 + ($1.actualMi ?? 0) }
        let weeklyAvgMiles = completedOnly.isEmpty ? 0 : avgMilesBase / Double(completedOnly.count)

        return VStack(alignment: .leading, spacing: 8) {
            chartHeader(
                leftLabel: "01 · TOTAL MILES",
                leftNumber: "\(Int(completedMilesTotal))",
                leftUnit: "mi",
                rightLabel: "WEEKLY AVG",
                rightNumber: String(format: "%.1f", weeklyAvgMiles),
                rightUnit: "mi"
            )
            MileageChart(entries: entries, focusedWeek: $focusedWeek)
                .frame(height: 188)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        // TabView page-style clips at the page bounds, so a shadow rendered
        // at the card edge gets cropped and looks different from the
        // session-row / focused-week / race cards elsewhere. The 4pt margin
        // gives all four shadow sides room to render fully.
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    // MARK: - Elevation Card

    private func elevationCard(entries: [WeekProgressEntry]) -> some View {
        let elapsed = entries.filter { !$0.isFuture }
        let completedOnly = entries.filter { !$0.isFuture && !$0.isCurrent }
        let completedVertTotal = elapsed.reduce(0.0) { $0 + ($1.elevationGainFt ?? 0) }
        let avgVertBase = completedOnly.reduce(0.0) { $0 + ($1.elevationGainFt ?? 0) }
        let weeklyAvgVert = completedOnly.isEmpty ? 0 : avgVertBase / Double(completedOnly.count)

        return VStack(alignment: .leading, spacing: 8) {
            chartHeader(
                leftLabel: "02 · TOTAL VERT",
                leftNumber: "\(formatFt(completedVertTotal))",
                leftUnit: "ft",
                rightLabel: "WEEKLY AVG",
                rightNumber: "\(formatFt(weeklyAvgVert))",
                rightUnit: "ft"
            )
            ElevationChart(entries: entries, focusedWeek: $focusedWeek)
                .frame(height: 188)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    // MARK: - Time Card

    private func timeCard(entries: [WeekProgressEntry]) -> some View {
        let elapsed = entries.filter { !$0.isFuture }
        let completedOnly = entries.filter { !$0.isFuture && !$0.isCurrent }
        let totalRunH = elapsed.reduce(0.0) { $0 + ($1.runHours ?? 0) }
        let totalCtH = elapsed.reduce(0.0) { $0 + ($1.crossTrainHours ?? 0) }
        let totalH = totalRunH + totalCtH
        let avgBaseH = completedOnly.reduce(0.0) { $0 + ($1.runHours ?? 0) + ($1.crossTrainHours ?? 0) }
        let weeklyAvgH = completedOnly.isEmpty ? 0 : avgBaseH / Double(completedOnly.count)

        return VStack(alignment: .leading, spacing: 8) {
            chartHeader(
                leftLabel: "03 · TOTAL TIME",
                leftNumber: formatHoursNumber(totalH),
                leftUnit: "hr",
                rightLabel: "WEEKLY AVG",
                rightNumber: formatHoursNumber(weeklyAvgH),
                rightUnit: "hr"
            )
            TotalTimeChart(entries: entries, focusedWeek: $focusedWeek)
                .frame(height: 188)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    private func formatHours(_ value: Double) -> String {
        if value >= 10 { return String(format: "%.0f hr", value) }
        return String(format: "%.1f hr", value)
    }

    private func formatHoursNumber(_ value: Double) -> String {
        if value >= 10 { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }

    private func chartHeader(
        leftLabel: String, leftNumber: String, leftUnit: String,
        rightLabel: String, rightNumber: String, rightUnit: String
    ) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(leftLabel).font(TrailFont.data).tracking(0.5).foregroundStyle(.secondary)
                (Text(leftNumber).font(TrailFont.data).fontWeight(.medium).foregroundStyle(.primary)
                 + Text(" \(leftUnit)").font(TrailFont.data).foregroundStyle(.secondary))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(rightLabel).font(TrailFont.data).tracking(0.5).foregroundStyle(.secondary)
                (Text(rightNumber).font(TrailFont.data).fontWeight(.medium).foregroundStyle(.primary)
                 + Text(" \(rightUnit)").font(TrailFont.data).foregroundStyle(.secondary))
            }
        }
    }

    // MARK: - Race Card

    private func sessionCountPill(count: Int, label: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .foregroundStyle(tint)
            Text("\(count)")
                .font(TrailFont.data)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Text(label)
                .font(TrailFont.meta)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func raceCard(entries: [WeekProgressEntry]) -> some View {
        if let plan = planStore.activePlan {
            let daysToRace = max(0, Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: plan.raceDate)
            ).day ?? 0)
            let sessionsDone = entries.reduce(0) { $0 + $1.sessionsCompleted }
            let sessionsTotal = max(entries.reduce(0) { $0 + $1.totalSessions }, 1)
            let pct = Double(sessionsDone) / Double(sessionsTotal)
            // Inferred + explicit skips, computed across all weeks. Replaces the
            // old explicit-only count so a missed run counts even without the
            // user tapping "skip".
            let skippedCount = entries.reduce(0) { $0 + $1.sessionsSkipped }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(plan.name)
                        .font(.system(size: 18))
                        .foregroundStyle(.primary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(plan.raceDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased())
                            .font(TrailFont.data).tracking(0.5)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(daysToRace)")
                                .font(TrailFont.bigNumber)
                                .foregroundStyle(.primary)
                            Text("d")
                                .font(TrailFont.data)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("SESSIONS")
                        .font(TrailFont.data).tracking(0.5)
                        .foregroundStyle(.secondary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.black.opacity(0.06))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.trailGreen)
                                .frame(width: max(0, geo.size.width * pct))
                        }
                    }
                    .frame(height: 6)

                    HStack(spacing: 14) {
                        sessionCountPill(
                            count: sessionsDone,
                            label: "done",
                            systemImage: "checkmark.circle.fill",
                            tint: Color.trailGreen
                        )
                        sessionCountPill(
                            count: skippedCount,
                            label: "skipped",
                            systemImage: "minus.circle.fill",
                            tint: .secondary
                        )
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.trailGreen)
            Text("No data yet")
                .font(TrailFont.title)
                .foregroundStyle(.secondary)
            Text("Create a training plan and complete some runs to see your progress.")
                .font(TrailFont.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Create a Training Plan") { showingPlanSetup = true }
                .buttonStyle(.borderedProminent)
                .tint(Color.trailGreen)
            Spacer()
        }
        .sheet(isPresented: $showingPlanSetup) { PlanSetupView() }
    }

    // MARK: - Helpers

    private func primeFocusedWeek() {
        guard !planStore.allWeekNumbers.isEmpty else { return }
        focusedWeek = planStore.currentWeekNumber ?? planStore.allWeekNumbers.first ?? 1
    }

    private func formatFt(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return NumberFormatter.localizedString(from: NSNumber(value: rounded), number: .decimal)
    }

    // MARK: - Data

    private func computeWeeklyEntries() -> [WeekProgressEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentWeek = planStore.currentWeekNumber

        struct RawWeek {
            let weekNum: Int
            let weekSessions: [PlannedSession]
            let trackableRuns: [PlannedSession]
            let plannedKm: Double
            let actualKm: Double
            let elevationM: Double
            let runSeconds: Int
            let runsDone: Int
            let crossTrainSeconds: Int
            let sessionsSkipped: Int
        }

        let rawWeeks: [RawWeek] = planStore.allWeekNumbers.map { weekNum in
            let weekSessions = planStore.sessions(for: weekNum)
            let trackableRuns = weekSessions.filter { $0.workoutType != .rest && $0.workoutType != .strength }
            let plannedKm = trackableRuns.compactMap(\.targetDistanceKm).reduce(0, +)

            var actualKm: Double = 0
            var elevationM: Double = 0
            var runSeconds = 0
            var runsDone = 0
            var crossTrainSeconds = 0
            var countedActivityIds: Set<Int64> = []

            // Step 1 — matched activities (runs and cross-training both live off session matches).
            for session in weekSessions {
                guard let activity = strava.activity(for: session.id) else { continue }
                if activity.isRun {
                    actualKm += activity.distanceKm
                    runSeconds += activity.movingTimeSeconds
                    elevationM += activity.elevationGainM ?? 0
                    runsDone += 1
                    countedActivityIds.insert(activity.stravaId)
                } else if activity.isCrossTraining {
                    crossTrainSeconds += activity.movingTimeSeconds
                    countedActivityIds.insert(activity.stravaId)
                }
            }

            // Step 2 — unmatched activities in the week's local-calendar date range.
            // Picks up doubles days + cross-training that wasn't auto-matched to a session
            // (e.g., a bonus bike ride on a day without a planned cross-train slot).
            // Day-equality goes through `isOnLocalDay` to avoid the timezone shift.
            if let firstDate = weekSessions.first?.scheduledDate,
               let lastDate = weekSessions.last?.scheduledDate {
                let weekDays: [Date] = {
                    let start = calendar.startOfDay(for: firstDate)
                    let end = calendar.startOfDay(for: lastDate)
                    var out: [Date] = []
                    var d = start
                    while d <= end {
                        out.append(d)
                        guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
                        d = next
                    }
                    return out
                }()
                for activity in strava.activities where !countedActivityIds.contains(activity.stravaId) {
                    guard weekDays.contains(where: { activity.isOnLocalDay($0) }) else { continue }
                    if activity.isRun {
                        actualKm += activity.distanceKm
                        runSeconds += activity.movingTimeSeconds
                        elevationM += activity.elevationGainM ?? 0
                        runsDone += 1
                        countedActivityIds.insert(activity.stravaId)
                    } else if activity.isCrossTraining {
                        crossTrainSeconds += activity.movingTimeSeconds
                        countedActivityIds.insert(activity.stravaId)
                    }
                }
            }

            // Step 3 — infer skipped sessions.
            //
            // A trackable run that's already in the past with neither a
            // matched Strava activity NOR any activity on its scheduled day
            // (covers doubles where the user ran but mismatched) AND no
            // explicit user skip → counts as a skipped workout. Combined
            // with explicit user skips below for the per-week total.
            let sessionsSkipped: Int = trackableRuns.reduce(0) { acc, session in
                let day = calendar.startOfDay(for: session.scheduledDate)
                guard day <= today else { return acc }
                if planStore.isSkipped(session.id) { return acc + 1 }
                if strava.activity(for: session.id) != nil { return acc }
                let hasActivityOnDay = strava.activities.contains { activity in
                    activity.isOnLocalDay(session.scheduledDate)
                        && (activity.isRun || activity.isCrossTraining)
                }
                return hasActivityOnDay ? acc : acc + 1
            }

            return RawWeek(
                weekNum: weekNum,
                weekSessions: weekSessions,
                trackableRuns: trackableRuns,
                plannedKm: plannedKm,
                actualKm: actualKm,
                elevationM: elevationM,
                runSeconds: runSeconds,
                runsDone: runsDone,
                crossTrainSeconds: crossTrainSeconds,
                sessionsSkipped: sessionsSkipped
            )
        }

        return rawWeeks.map { raw in
            let weekNum = raw.weekNum
            let weekSessions = raw.weekSessions

            let weekStrengthDates = Set(
                strengthStore.sessions
                    .filter { $0.weekNumber == weekNum }
                    .map { calendar.startOfDay(for: $0.scheduledDate) }
            )
            let strengthDone = weekStrengthDates.filter { date in
                strengthStore.isDayComplete(on: date, stravaActivities: strava.activities)
            }.count

            let weekStretchDates = Set(
                stretchStore.sessions
                    .filter { $0.weekNumber == weekNum }
                    .map { calendar.startOfDay(for: $0.scheduledDate) }
            )
            let stretchDone = weekStretchDates.filter { stretchStore.isAllComplete(on: $0) }.count

            let weekHeat = heatStore.sessions(for: weekNum)
            let heatDone = weekHeat.filter { heatStore.isComplete($0.id) }.count

            let totalItems = raw.trackableRuns.count + weekStrengthDates.count + weekStretchDates.count + weekHeat.count
            let completedItems = raw.runsDone + strengthDone + stretchDone + heatDone

            let lastDate = weekSessions.last?.scheduledDate ?? today
            let firstDate = weekSessions.first?.scheduledDate ?? today
            let isCurrent = currentWeek == weekNum
            let isFuture = calendar.startOfDay(for: firstDate) > today && !isCurrent

            let plannedMi = DistanceFormatter.miles(from: raw.plannedKm)
            let actualMi = DistanceFormatter.miles(from: raw.actualKm)
            let elevationFt = raw.elevationM * 3.28084
            let runHours = Double(raw.runSeconds) / 3600.0
            let crossTrainHours = Double(raw.crossTrainSeconds) / 3600.0

            // Sum each trackable run's parsed coach range (low / high in mi) for
            // the planned-range oval on the Miles chart. Sessions without an
            // explicit "N–M mi" range contribute their single targetDistanceMi
            // to both ends — same parsing PlannedSession.displayTargetRange uses
            // for the per-session range pill in the Week tab.
            var loMi: Double = 0
            var hiMi: Double = 0
            for session in raw.trackableRuns {
                if let range = session.plannedDistanceRangeMi {
                    loMi += range.low
                    hiMi += range.high
                } else if let mi = session.targetDistanceMi {
                    loMi += mi
                    hiMi += mi
                }
            }
            // Guard against a week with no parseable sessions — fall back to
            // plannedMi so the oval still anchors near the column rather than
            // collapsing to zero.
            if hiMi == 0 { loMi = plannedMi; hiMi = plannedMi }

            return WeekProgressEntry(
                week: weekNum,
                rangeLabel: rangeLabel(from: firstDate, to: lastDate),
                plannedMi: plannedMi,
                plannedMiLow: loMi,
                plannedMiHigh: hiMi,
                actualMi: isFuture ? nil : (actualMi > 0 ? actualMi : nil),
                runHours: isFuture ? nil : (runHours > 0 ? runHours : nil),
                crossTrainHours: isFuture ? nil : (crossTrainHours > 0 ? crossTrainHours : nil),
                elevationGainFt: isFuture ? nil : (elevationFt > 0 ? elevationFt : nil),
                sessionsCompleted: completedItems,
                sessionsSkipped: raw.sessionsSkipped,
                totalSessions: totalItems,
                isCurrent: isCurrent,
                isFuture: isFuture
            )
        }
    }

    private func rangeLabel(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startStr = formatter.string(from: start)
        let endStr: String = {
            let sameMonth = Calendar.current.isDate(start, equalTo: end, toGranularity: .month)
            formatter.dateFormat = sameMonth ? "d" : "MMM d"
            return formatter.string(from: end)
        }()
        return "\(startStr)–\(endStr)"
    }
}

// MARK: - Entry model

struct WeekProgressEntry: Identifiable, Equatable {
    let week: Int
    let rangeLabel: String
    let plannedMi: Double
    /// Sum of each session's parsed low/high range (mi) for the week — used by
    /// the Miles chart's planned-range oval. Falls back to a zero-width range
    /// (low == high == plannedMi) when no session has an explicit "N–M mi" in
    /// its coach notes.
    let plannedMiLow: Double
    let plannedMiHigh: Double
    let actualMi: Double?
    let runHours: Double?
    let crossTrainHours: Double?
    let elevationGainFt: Double?
    let sessionsCompleted: Int
    /// Trackable runs in past days with no matching Strava activity (and no
    /// other activity on the day) plus any sessions the user explicitly
    /// skipped. Surfaced in the race card "skipped" pill.
    let sessionsSkipped: Int
    let totalSessions: Int
    let isCurrent: Bool
    let isFuture: Bool

    var id: Int { week }

    /// Planned hours for the week — derived from planned mileage at a nominal 6 mph.
    /// Used as the grey-ghost bar on the Total Time chart for current/future weeks.
    var plannedHours: Double { plannedMi / 6.0 }
}

// MARK: - Lollipop chart primitive
//
// All three Progress charts share one renderer (`LollipopChart`). Each chart
// card configures it via closures: `segments` produces the colored stack of
// stem segments per column (one for Miles/Vert, two for Time), `plannedRange`
// optionally returns the (low, high) range for a grey planned-range capsule
// (Miles only), and `isInRange` flags weeks where the actual landed inside the
// planned range — those weeks get the capsule tinted green as a small "you
// nailed the plan" reward.
//
// Layout tokens come from "Bold Day Progress Handoff.html" §02. The chart
// frame is 188pt: 8pt top gutter (so the topmost y-axis label has room),
// 160pt chart body, 20pt bottom strip for week labels.

private enum LollipopChartConstants {
    static let topPad: CGFloat = 8        // pt above the chart body for the top y-axis label
    static let labelArea: CGFloat = 20    // pt below the chart body for week labels
    static let stemWidth: CGFloat = 2     // pt
    static let dotDiameter: CGFloat = 12  // pt — radius 6 per spec
    static let ovalWidth: CGFloat = 12    // pt
    static let ovalStroke: CGFloat = 0.5  // pt — hairline
    static let ovalFillOpacity: Double = 0.40
    static let ovalNonCurrentOpacity: Double = 0.30
    /// Warm grey #8A8478 used for the planned-range oval. Same hue as the
    /// `textTertiary` token in the design handoff so the oval reads as a
    /// background reference, not a colored data series.
    static let ovalGrey = Color(red: 0.541, green: 0.518, blue: 0.471)
    /// Past weeks fade their colors to this opacity. Current OR focused weeks
    /// always render at full opacity — that pair-up is what makes the focus
    /// state read clearly when the user swipes the focused-week card up top.
    static let pastOpacity: Double = 0.55
}

/// One colored vertical contribution to a column's stack. Miles/Vert charts
/// emit a single segment (the actual value); Time emits two (cross-train then
/// run, stacked from baseline upward).
private struct LollipopColumnSegment {
    let value: Double
    let color: Color
}

/// Y-axis labels, shared across all three charts. Renders all 5 tick labels
/// (0, 25%, 50%, 75%, 100% of niceMax). The topmost label sits in the chart's
/// 8pt top gutter, so it never clips the plot area.
private struct ChartAxisLabels: View {
    let niceMax: Double
    let chartHeight: CGFloat
    let axisWidth: CGFloat
    let format: (Double) -> String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(0..<5, id: \.self) { tick in
                let v = niceMax * Double(tick) / 4
                let y = chartHeight - CGFloat(v / niceMax) * chartHeight
                Text(format(v))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .offset(x: -4, y: y - 6) // 4pt label gap per spec §02
            }
        }
        .frame(width: axisWidth, height: chartHeight, alignment: .topTrailing)
    }
}

private struct ChartGridlines: View {
    let chartWidth: CGFloat
    let chartHeight: CGFloat

    var body: some View {
        ForEach(0..<5, id: \.self) { tick in
            let y = chartHeight * CGFloat(tick) / 4
            Rectangle()
                .fill(Color(.separator).opacity(0.5))
                .frame(width: chartWidth, height: 0.5)
                .offset(x: 0, y: y)
        }
    }
}

/// Tap target rectangles, one per column. Decoupled from the visual layer so
/// the thin stems and dots don't fight a 22pt-wide tap zone for hit-testing.
private struct LollipopTapTargets: View {
    let entries: [WeekProgressEntry]
    let columnWidth: CGFloat
    let chartHeight: CGFloat
    @Binding var focusedWeek: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(entries) { entry in
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: columnWidth, height: chartHeight + LollipopChartConstants.labelArea)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeOut(duration: 0.22)) { focusedWeek = entry.week } }
            }
        }
    }
}

/// Week-number label below each column. Bold + accent only when this week is
/// the currently focused one — so the highlight follows the focused-week card
/// up top as the user swipes / chevrons through weeks. The current week always
/// wears a 1.5pt accent underline so "today" stays findable while the user
/// browses past weeks.
private struct WeekTickLabel: View {
    let entry: WeekProgressEntry
    let focusedWeek: Int
    let highlightColor: Color
    let cx: CGFloat
    let chartHeight: CGFloat

    var body: some View {
        let isFocused = entry.week == focusedWeek
        Text("\(entry.week)")
            .font(.system(size: 9, design: .monospaced))
            .fontWeight(isFocused ? .semibold : .regular)
            .foregroundStyle(isFocused ? highlightColor : Color.secondary.opacity(0.55))
            .position(x: cx, y: chartHeight + 11)
        if entry.isCurrent {
            Rectangle()
                .fill(highlightColor)
                .frame(width: 8, height: 1.5)
                .position(x: cx, y: chartHeight + 18)
        }
    }
}

private struct LollipopChart: View {
    let entries: [WeekProgressEntry]
    let yMax: Double
    let axisWidth: CGFloat
    let axisFormat: (Double) -> String
    /// Used for the focused-column highlight, the planned-range oval when
    /// in-range, and the week-label color.
    let highlightColor: Color
    /// One or more colored segments stacked from baseline. Empty array = nothing
    /// drawn (e.g. future weeks on Vert/Time).
    let segments: (WeekProgressEntry) -> [LollipopColumnSegment]
    /// nil = no planned-range capsule for this chart (Vert/Time).
    let plannedRange: ((WeekProgressEntry) -> (low: Double, high: Double))?
    /// nil = no in-range tinting; otherwise true means actual fell inside
    /// the planned range and the capsule should render in `highlightColor`.
    let isInRange: ((WeekProgressEntry) -> Bool)?
    @Binding var focusedWeek: Int

    var body: some View {
        GeometryReader { geo in
            let chartHeight = geo.size.height
                - LollipopChartConstants.labelArea
                - LollipopChartConstants.topPad
            let chartWidth = max(1, geo.size.width - axisWidth)
            let columnWidth = chartWidth / CGFloat(max(entries.count, 1))

            HStack(alignment: .top, spacing: 0) {
                ChartAxisLabels(niceMax: yMax, chartHeight: chartHeight,
                                axisWidth: axisWidth, format: axisFormat)

                ZStack(alignment: .topLeading) {
                    ChartGridlines(chartWidth: chartWidth, chartHeight: chartHeight)

                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        let cx = (CGFloat(index) + 0.5) * columnWidth
                        column(entry: entry, cx: cx,
                               chartHeight: chartHeight, columnWidth: columnWidth)
                    }

                    LollipopTapTargets(entries: entries, columnWidth: columnWidth,
                                       chartHeight: chartHeight, focusedWeek: $focusedWeek)
                }
                .frame(width: chartWidth,
                       height: chartHeight + LollipopChartConstants.labelArea,
                       alignment: .topLeading)
            }
            .padding(.top, LollipopChartConstants.topPad)
        }
    }

    @ViewBuilder
    private func column(entry: WeekProgressEntry, cx: CGFloat,
                        chartHeight: CGFloat, columnWidth: CGFloat) -> some View {
        // The focused week is the only "active" one — its lollipop pops to
        // full opacity. The current week is no different colorwise; it's
        // marked by the underline beneath the week-number label so the user
        // can find "today" without conflating it with their focus.
        let isFocused = entry.week == focusedWeek

        if let range = plannedRange?(entry) {
            plannedOval(range: range, isActive: isFocused, entry: entry,
                        chartHeight: chartHeight, cx: cx)
        }

        let segs = segments(entry)
        let total = segs.reduce(0.0) { $0 + $1.value }
        if total > 0 {
            // Render stem segments + dot at full opacity inside a compositing
            // group so a single .opacity() applies to the whole lollipop as one
            // shape — without compositingGroup, the dot's overlap with the
            // top of the stem doubles up to ~80% opacity and creates a darker
            // collar at the dot/stem junction.
            ZStack(alignment: .topLeading) {
                stems(segments: segs, cx: cx, chartHeight: chartHeight)
                let topColor = segs.last?.color ?? highlightColor
                let dotY = chartHeight - CGFloat(total / yMax) * chartHeight
                Circle()
                    .fill(topColor)
                    .frame(width: LollipopChartConstants.dotDiameter,
                           height: LollipopChartConstants.dotDiameter)
                    .position(x: cx, y: dotY)
            }
            .compositingGroup()
            .opacity(isFocused ? 1.0 : LollipopChartConstants.pastOpacity)
        }

        WeekTickLabel(entry: entry, focusedWeek: focusedWeek,
                      highlightColor: highlightColor,
                      cx: cx, chartHeight: chartHeight)
    }

    @ViewBuilder
    private func plannedOval(range: (low: Double, high: Double), isActive: Bool,
                             entry: WeekProgressEntry,
                             chartHeight: CGFloat, cx: CGFloat) -> some View {
        let yHi = chartHeight - CGFloat(range.high / yMax) * chartHeight
        let yLo = chartHeight - CGFloat(range.low / yMax) * chartHeight
        let ovalH = max(yLo - yHi, LollipopChartConstants.ovalWidth)
        // In-range weeks get an accent-tinted capsule — the small visual reward
        // for hitting the prescribed range.
        let inRange = isInRange?(entry) ?? false
        let ovalColor = inRange ? highlightColor : LollipopChartConstants.ovalGrey
        // Active (current or focused) weeks render at full opacity; everything
        // else fades to 0.30 per spec §02.
        let ovalOpacity = isActive ? 1.0 : LollipopChartConstants.ovalNonCurrentOpacity

        Capsule()
            .fill(ovalColor.opacity(LollipopChartConstants.ovalFillOpacity))
            .overlay(
                Capsule().stroke(ovalColor, lineWidth: LollipopChartConstants.ovalStroke)
            )
            .frame(width: LollipopChartConstants.ovalWidth, height: ovalH)
            .opacity(ovalOpacity)
            .position(x: cx, y: yHi + ovalH / 2)
    }

    /// Stack each segment as a flat-cap rectangle from the baseline up. Butt
    /// caps avoid the rounded-cap pinch where two stacked segments meet
    /// (visible on the Time chart's cross-then-run stem). Always renders at
    /// full opacity — the caller's compositingGroup dims the whole lollipop
    /// as one piece so dot/stem overlap doesn't double up.
    @ViewBuilder
    private func stems(segments: [LollipopColumnSegment],
                       cx: CGFloat, chartHeight: CGFloat) -> some View {
        ForEach(0..<segments.count, id: \.self) { i in
            let belowSum = segments.prefix(i).reduce(0.0) { $0 + $1.value }
            let segValue = segments[i].value
            if segValue > 0 {
                let segBottomY = chartHeight - CGFloat(belowSum / yMax) * chartHeight
                let segTopY = chartHeight - CGFloat((belowSum + segValue) / yMax) * chartHeight
                let h = max(0, segBottomY - segTopY)
                Rectangle()
                    .fill(segments[i].color)
                    .frame(width: LollipopChartConstants.stemWidth, height: h)
                    .position(x: cx, y: segTopY + h / 2)
            }
        }
    }
}

// MARK: - Per-metric chart wrappers
//
// Each wrapper is the call-site contract used by the chart cards. They keep
// the surrounding card code unchanged while the per-chart configuration —
// segments, planned range, in-range rule, axis format — lives in one place.

private struct MileageChart: View {
    let entries: [WeekProgressEntry]
    @Binding var focusedWeek: Int

    var body: some View {
        LollipopChart(
            entries: entries,
            yMax: Self.yMax(for: entries),
            axisWidth: 22,
            axisFormat: { "\(Int($0))" },
            highlightColor: .trailGreen,
            segments: { entry in
                guard let mi = entry.actualMi, mi > 0 else { return [] }
                return [LollipopColumnSegment(value: mi, color: .trailGreen)]
            },
            plannedRange: { ($0.plannedMiLow, $0.plannedMiHigh) },
            isInRange: { entry in
                guard let mi = entry.actualMi, !entry.isFuture else { return false }
                guard entry.plannedMiHigh > entry.plannedMiLow else { return false }
                return mi >= entry.plannedMiLow && mi <= entry.plannedMiHigh
            },
            focusedWeek: $focusedWeek
        )
    }

    /// Y-scale spans the largest planned-range high or actual mi rounded up to
    /// the next 10 — guarantees the oval's top never clips the plot area.
    static func yMax(for entries: [WeekProgressEntry]) -> Double {
        let raw = entries.map { max($0.plannedMiHigh, $0.actualMi ?? 0) }.max() ?? 10
        return max(10, ceil(raw / 10) * 10)
    }
}

private struct ElevationChart: View {
    let entries: [WeekProgressEntry]
    @Binding var focusedWeek: Int

    var body: some View {
        LollipopChart(
            entries: entries,
            yMax: Self.yMax(for: entries),
            axisWidth: 28,
            axisFormat: Self.labelText,
            highlightColor: .trailPurple,
            segments: { entry in
                guard let ft = entry.elevationGainFt, ft > 0 else { return [] }
                return [LollipopColumnSegment(value: ft, color: .trailPurple)]
            },
            plannedRange: nil,
            isInRange: nil,
            focusedWeek: $focusedWeek
        )
    }

    /// Y-scale rounded up to nearest 500 ft per spec §05. Floor of 1000 keeps
    /// the chart legible during the first weeks of a fresh plan.
    static func yMax(for entries: [WeekProgressEntry]) -> Double {
        let raw = entries.compactMap { $0.elevationGainFt }.max() ?? 1000
        return max(1000, ceil(raw / 500) * 500)
    }

    static func labelText(_ value: Double) -> String {
        if value >= 1000 { return String(format: "%.1fk", value / 1000) }
        return "\(Int(value))"
    }
}

private struct TotalTimeChart: View {
    let entries: [WeekProgressEntry]
    @Binding var focusedWeek: Int

    var body: some View {
        LollipopChart(
            entries: entries,
            yMax: Self.yMax(for: entries),
            axisWidth: 24,
            axisFormat: { "\(Int($0))h" },
            highlightColor: .trailGreen,
            segments: { entry in
                let runH = entry.runHours ?? 0
                let crossH = entry.crossTrainHours ?? 0
                guard runH + crossH > 0 else { return [] }
                // Cross-train (orange) on bottom, run (green) stacked above
                // per spec §06. The dot inherits the topmost (run) color.
                var out: [LollipopColumnSegment] = []
                if crossH > 0 { out.append(LollipopColumnSegment(value: crossH, color: .orange)) }
                if runH > 0 { out.append(LollipopColumnSegment(value: runH, color: .trailGreen)) }
                return out
            },
            plannedRange: nil,
            isInRange: nil,
            focusedWeek: $focusedWeek
        )
    }

    /// Y-scale taken from past + current weeks per spec §06: ceil(max(run + cross) + 1).
    /// Floor of 2 keeps a brand-new plan from rendering with a degenerate axis.
    static func yMax(for entries: [WeekProgressEntry]) -> Double {
        let raw = entries
            .filter { !$0.isFuture }
            .map { ($0.runHours ?? 0) + ($0.crossTrainHours ?? 0) }
            .max() ?? 1
        return max(2, ceil(raw + 1))
    }
}

#Preview {
    ProgressDashboardView()
        .environment(TrainingPlanStore())
        .environment(StravaService())
        .environment(OuraService())
        .environment(StrengthStore())
        .environment(StretchStore())
        .environment(HeatStore())
        .environment(AuthService())
}
