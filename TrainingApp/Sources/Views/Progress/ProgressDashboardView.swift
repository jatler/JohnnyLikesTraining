import SwiftUI

struct ProgressDashboardView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(OuraService.self) private var oura
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(StretchStore.self) private var stretchStore
    @Environment(HeatStore.self) private var heatStore

    @State private var showingPlanSetup = false
    @State private var focusedWeek: Int = 1

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
        VStack(alignment: .leading, spacing: 4) {
            Text("Progress")
                .font(TrailFont.tabHeading)
                .foregroundStyle(.white)

            if let templateName = planStore.currentTemplate?.name {
                Text(templateName.uppercased())
                    .font(TrailFont.data)
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.trailGreen)
    }

    // MARK: - Content

    private var content: some View {
        let entries = computeWeeklyEntries()
        return ScrollView {
            VStack(spacing: 12) {
                focusedWeekCard(entries: entries)
                mileageCard(entries: entries)
                elevationCard(entries: entries)
                raceCard(entries: entries)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Focused Week Card

    private func focusedWeekCard(entries: [WeekProgressEntry]) -> some View {
        let entry = entries.first(where: { $0.week == focusedWeek }) ?? entries.first
        let isCurrent = entry?.isCurrent == true
        let isFuture = entry?.isFuture == true
        let canGoPrev = focusedWeek > (entries.first?.week ?? 1)
        let canGoNext = focusedWeek < (entries.last?.week ?? 1)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WK")
                        .font(TrailFont.data).tracking(0.5)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%02d", entry?.week ?? 0))
                        .font(.custom("GeistMono-Medium", size: 22, relativeTo: .title2))
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

            Divider().padding(.top, 12).padding(.bottom, 10)

            HStack(alignment: .top, spacing: 10) {
                focusedStat(
                    label: "MILES",
                    primary: entry?.actualMi.map { String(format: "%.1f", $0) } ?? "—",
                    primaryColor: isCurrent ? Color.trailGreen : .primary,
                    secondary: "/ \(String(format: "%.1f", entry?.plannedMi ?? 0)) mi"
                )
                focusedStat(
                    label: "CROSS-TRAIN",
                    primary: entry?.crossTrainHours.map { String(format: "%.1f", $0) } ?? "—",
                    primaryColor: .orange,
                    secondary: "hr"
                )
                focusedStat(
                    label: "VERT",
                    primary: entry?.elevationGainFt.map { formatFt($0) } ?? "—",
                    primaryColor: Color(red: 0.54, green: 0.42, blue: 0.82),
                    secondary: "ft"
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrent ? Color.trailGreenSubtle : Color(.systemBackground))
        .overlay(alignment: .leading) {
            if isCurrent {
                Rectangle()
                    .fill(Color.trailGreen)
                    .frame(width: 4)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(isCurrent ? Color.trailGreen.opacity(0.33) : Color(.separator).opacity(0.3),
                              lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .opacity(isFuture ? 0.65 : 1)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.width < 0, canGoNext {
                        focusedWeek = min(focusedWeek + 1, entries.last?.week ?? focusedWeek)
                    } else if value.translation.width > 0, canGoPrev {
                        focusedWeek = max(focusedWeek - 1, entries.first?.week ?? focusedWeek)
                    }
                }
        )
        .animation(.easeOut(duration: 0.2), value: focusedWeek)
    }

    private func focusedStat(label: String, primary: String, primaryColor: Color, secondary: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(TrailFont.data).tracking(0.4)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(primary)
                    .font(.custom("GeistMono-Medium", size: 20, relativeTo: .title3))
                    .foregroundStyle(primaryColor)
                Text(secondary)
                    .font(TrailFont.data)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        let completedMilesTotal = elapsed.reduce(0.0) { $0 + ($1.actualMi ?? 0) }
        let weeklyAvgMiles = elapsed.isEmpty ? 0 : completedMilesTotal / Double(elapsed.count)

        return VStack(alignment: .leading, spacing: 8) {
            chartHeader(
                leftLabel: "TOTAL MILES",
                leftValue: "\(Int(completedMilesTotal)) mi",
                rightLabel: "WEEKLY AVG",
                rightValue: String(format: "%.1f mi", weeklyAvgMiles)
            )
            MileageChart(entries: entries, focusedWeek: $focusedWeek)
                .frame(height: 142)
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Elevation Card

    private func elevationCard(entries: [WeekProgressEntry]) -> some View {
        let elapsed = entries.filter { !$0.isFuture }
        let completedVertTotal = elapsed.reduce(0.0) { $0 + ($1.elevationGainFt ?? 0) }
        let weeklyAvgVert = elapsed.isEmpty ? 0 : completedVertTotal / Double(elapsed.count)

        return VStack(alignment: .leading, spacing: 8) {
            chartHeader(
                leftLabel: "TOTAL VERT",
                leftValue: "\(formatFt(completedVertTotal)) ft",
                rightLabel: "WEEKLY AVG",
                rightValue: "\(formatFt(weeklyAvgVert)) ft"
            )
            ElevationChart(entries: entries, focusedWeek: $focusedWeek)
                .frame(height: 86)
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
        )
    }

    private func chartHeader(leftLabel: String, leftValue: String, rightLabel: String, rightValue: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(leftLabel).font(TrailFont.data).tracking(0.5).foregroundStyle(.secondary)
                Text(leftValue).font(TrailFont.data).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(rightLabel).font(TrailFont.data).tracking(0.5).foregroundStyle(.secondary)
                Text(rightValue).font(TrailFont.data).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Race Card

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

            VStack(alignment: .leading, spacing: 12) {
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
                                .font(.custom("GeistMono-Medium", size: 20, relativeTo: .title3))
                                .foregroundStyle(.primary)
                            Text("d")
                                .font(TrailFont.data)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("SESSIONS")
                            .font(TrailFont.data).tracking(0.5)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 0) {
                            Text("\(sessionsDone)")
                                .font(TrailFont.data)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Text("/\(sessionsTotal)")
                                .font(TrailFont.data)
                                .foregroundStyle(.secondary)
                        }
                    }
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
                }
            }
            .padding(14)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
            )
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
        }

        let rawWeeks: [RawWeek] = planStore.allWeekNumbers.map { weekNum in
            let weekSessions = planStore.sessions(for: weekNum)
            let trackableRuns = weekSessions.filter { $0.workoutType != .rest && $0.workoutType != .strength }
            let plannedKm = trackableRuns.compactMap(\.targetDistanceKm).reduce(0, +)

            var actualKm: Double = 0
            var elevationM: Double = 0
            var runSeconds = 0
            var runsDone = 0
            var countedActivityIds: Set<Int64> = []

            for session in weekSessions {
                if let activity = strava.activity(for: session.id), activity.isRun {
                    actualKm += activity.distanceKm
                    runSeconds += activity.movingTimeSeconds
                    elevationM += activity.elevationGainM ?? 0
                    runsDone += 1
                    countedActivityIds.insert(activity.stravaId)
                }
            }

            if let firstDate = weekSessions.first?.scheduledDate,
               let lastDate = weekSessions.last?.scheduledDate {
                let start = calendar.startOfDay(for: firstDate)
                let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDate))!
                for activity in strava.activities where activity.isRun && !countedActivityIds.contains(activity.stravaId) {
                    if activity.activityDate >= start && activity.activityDate < end {
                        actualKm += activity.distanceKm
                        runSeconds += activity.movingTimeSeconds
                        elevationM += activity.elevationGainM ?? 0
                        runsDone += 1
                        countedActivityIds.insert(activity.stravaId)
                    }
                }
            }

            var crossTrainSeconds = 0
            for session in weekSessions {
                if let activity = strava.activity(for: session.id), activity.isCrossTraining {
                    crossTrainSeconds += activity.movingTimeSeconds
                }
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
                crossTrainSeconds: crossTrainSeconds
            )
        }

        // Plan-wide run pace (mph) across every week with actual run data.
        // Falls back to 6.0 mph when no history yet.
        let totalMi = rawWeeks.reduce(0.0) { $0 + DistanceFormatter.miles(from: $1.actualKm) }
        let totalRunHours = rawWeeks.reduce(0.0) { $0 + Double($1.runSeconds) / 3600.0 }
        let runPaceMph = totalRunHours > 0 ? totalMi / totalRunHours : 6.0

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
            let crossTrainHours = Double(raw.crossTrainSeconds) / 3600.0

            return WeekProgressEntry(
                week: weekNum,
                rangeLabel: rangeLabel(from: firstDate, to: lastDate),
                plannedMi: plannedMi,
                actualMi: (isFuture || (actualMi == 0 && !isCurrent && lastDate > today)) ? nil : actualMi,
                crossTrainHours: isFuture ? nil : (crossTrainHours > 0 ? crossTrainHours : nil),
                elevationGainFt: isFuture ? nil : (elevationFt > 0 ? elevationFt : nil),
                sessionsCompleted: completedItems,
                totalSessions: totalItems,
                isCurrent: isCurrent,
                isFuture: isFuture,
                runPaceMph: runPaceMph
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
    let actualMi: Double?
    let crossTrainHours: Double?
    let elevationGainFt: Double?
    let sessionsCompleted: Int
    let totalSessions: Int
    let isCurrent: Bool
    let isFuture: Bool
    let runPaceMph: Double

    var id: Int { week }

    /// Cross-training hours converted to mile-equivalents at the athlete's average running pace.
    /// This sums cross-train hours into the same "load" unit as run hours.
    var crossTrainMileEquivalent: Double { (crossTrainHours ?? 0) * runPaceMph }
}

// MARK: - Mileage Chart

private struct MileageChart: View {
    let entries: [WeekProgressEntry]
    @Binding var focusedWeek: Int

    private let axisWidth: CGFloat = 22
    private let barWidth: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            let chartHeight = geo.size.height - 20
            let availableWidth = geo.size.width - axisWidth
            let n = max(entries.count, 1)
            let spacing = n > 1 ? max(2, (availableWidth - CGFloat(n) * barWidth) / CGFloat(n - 1)) : 0
            let niceMax = niceMax(for: entries)

            HStack(alignment: .top, spacing: 0) {
                // Y-axis labels (hide the topmost so it doesn't clip)
                ZStack(alignment: .topTrailing) {
                    ForEach(0..<4, id: \.self) { tick in
                        let v = niceMax * Double(tick) / 4
                        let y = chartHeight - CGFloat(v / niceMax) * chartHeight
                        Text("\(Int(v))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .offset(x: -3, y: y - 6)
                    }
                }
                .frame(width: axisWidth, height: chartHeight, alignment: .topTrailing)

                // Bars + gridlines
                ZStack(alignment: .bottomLeading) {
                    // Gridlines
                    ForEach(0..<5, id: \.self) { tick in
                        let y = chartHeight * CGFloat(tick) / 4
                        Rectangle()
                            .fill(Color(.separator).opacity(0.5))
                            .frame(height: 0.5)
                            .offset(y: -(chartHeight - y))
                    }

                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(entries) { entry in
                            mileageBar(entry: entry, niceMax: niceMax, chartHeight: chartHeight)
                                .frame(width: barWidth, height: chartHeight, alignment: .bottom)
                                .overlay(alignment: .bottom) {
                                    Text("\(entry.week)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .fontWeight(entry.week == focusedWeek || entry.isCurrent ? .semibold : .regular)
                                        .foregroundStyle(entry.week == focusedWeek || entry.isCurrent ? Color.trailGreen : Color.secondary.opacity(0.55))
                                        .offset(y: 14)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { focusedWeek = entry.week }
                        }
                    }
                    .frame(height: chartHeight, alignment: .bottom)
                }
                .frame(height: chartHeight, alignment: .bottom)
            }
        }
    }

    @ViewBuilder
    private func mileageBar(entry: WeekProgressEntry, niceMax: Double, chartHeight: CGFloat) -> some View {
        let planH = CGFloat(entry.plannedMi / niceMax) * chartHeight
        let actH = CGFloat((entry.actualMi ?? 0) / niceMax) * chartHeight
        let ctH = CGFloat(entry.crossTrainMileEquivalent / niceMax) * chartHeight
        let remH = entry.isCurrent ? max(0, planH - actH - ctH) : 0

        VStack(spacing: 0) {
            if remH > 0 { Rectangle().fill(Color(.systemGray5)).frame(height: remH) }
            if ctH > 0 { Rectangle().fill(Color.orange.opacity(entry.isCurrent ? 1.0 : 0.5)).frame(height: ctH) }
            if actH > 0 {
                Rectangle()
                    .fill(entry.isCurrent ? Color.trailGreen : Color.trailGreen.opacity(0.55))
                    .frame(height: actH)
            }
            if entry.isFuture && planH > 0 {
                Rectangle().fill(Color(.systemGray5)).frame(height: planH)
            }
        }
    }

    private func niceMax(for entries: [WeekProgressEntry]) -> Double {
        let raw = entries.map { max($0.plannedMi, ($0.actualMi ?? 0) + $0.crossTrainMileEquivalent) }.max() ?? 10
        return max(10, ceil(raw / 10) * 10)
    }
}

// MARK: - Elevation Chart

private struct ElevationChart: View {
    let entries: [WeekProgressEntry]
    @Binding var focusedWeek: Int

    private let axisWidth: CGFloat = 28
    private let barWidth: CGFloat = 12
    private let purple = Color(red: 0.54, green: 0.42, blue: 0.82)
    private let purpleLight = Color(red: 0.76, green: 0.71, blue: 0.90)

    var body: some View {
        GeometryReader { geo in
            let chartHeight = geo.size.height - 20
            let availableWidth = geo.size.width - axisWidth
            let n = max(entries.count, 1)
            let spacing = n > 1 ? max(2, (availableWidth - CGFloat(n) * barWidth) / CGFloat(n - 1)) : 0
            let niceMax = niceMax(for: entries)

            HStack(alignment: .top, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    ForEach(0..<4, id: \.self) { tick in
                        let v = niceMax * Double(tick) / 4
                        let y = chartHeight - CGFloat(v / niceMax) * chartHeight
                        Text(labelText(v))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .offset(x: -3, y: y - 6)
                    }
                }
                .frame(width: axisWidth, height: chartHeight, alignment: .topTrailing)

                ZStack(alignment: .bottomLeading) {
                    ForEach(0..<5, id: \.self) { tick in
                        let y = chartHeight * CGFloat(tick) / 4
                        Rectangle()
                            .fill(Color(.separator).opacity(0.5))
                            .frame(height: 0.5)
                            .offset(y: -(chartHeight - y))
                    }
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(entries) { entry in
                            elevationBar(entry: entry, niceMax: niceMax, chartHeight: chartHeight)
                                .frame(width: barWidth, height: chartHeight, alignment: .bottom)
                                .overlay(alignment: .bottom) {
                                    Text("\(entry.week)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .fontWeight(entry.week == focusedWeek || entry.isCurrent ? .semibold : .regular)
                                        .foregroundStyle(entry.week == focusedWeek || entry.isCurrent ? purple : Color.secondary.opacity(0.55))
                                        .offset(y: 14)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { focusedWeek = entry.week }
                        }
                    }
                    .frame(height: chartHeight, alignment: .bottom)
                }
                .frame(height: chartHeight, alignment: .bottom)
            }
        }
    }

    @ViewBuilder
    private func elevationBar(entry: WeekProgressEntry, niceMax: Double, chartHeight: CGFloat) -> some View {
        let plannedFt = entry.plannedMi * 55  // synthesize a planned elevation to keep ghost bars readable
        let plannedH = CGFloat(plannedFt / niceMax) * chartHeight
        let actualH = CGFloat((entry.elevationGainFt ?? 0) / niceMax) * chartHeight

        if entry.isFuture {
            Rectangle().fill(Color(.systemGray5)).frame(height: plannedH)
        } else {
            VStack(spacing: 0) {
                if entry.isCurrent && plannedH > actualH {
                    Rectangle().fill(Color(.systemGray5)).frame(height: plannedH - actualH)
                }
                if actualH > 0 {
                    Rectangle().fill(entry.isCurrent ? purple : purpleLight).frame(height: actualH)
                }
            }
        }
    }

    private func niceMax(for entries: [WeekProgressEntry]) -> Double {
        let raw = entries.map { max($0.elevationGainFt ?? 0, $0.plannedMi * 55) }.max() ?? 1000
        return max(1000, ceil(raw / 1000) * 1000)
    }

    private func labelText(_ value: Double) -> String {
        if value >= 1000 { return String(format: "%.1fk", value / 1000) }
        return "\(Int(value))"
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
}
