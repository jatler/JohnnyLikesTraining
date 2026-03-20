import SwiftUI

struct WeekView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava

    @State private var selectedWeek: Int = 1
    @State private var selectedSession: PlannedSession?
    @State private var hasInitialized = false

    var body: some View {
        NavigationStack {
            Group {
                if planStore.hasPlan {
                    weekContent
                } else {
                    emptyState
                }
            }
            .navigationTitle("Week \(selectedWeek)")
        }
    }

    // MARK: - Week Content

    private var weekContent: some View {
        VStack(spacing: 0) {
            weekNavigator

            weekSummaryBar

            ScrollView {
                LazyVStack(spacing: 12) {
                    let sessions = planStore.sessions(for: selectedWeek)
                        .filter { $0.workoutType != .strength }
                    ForEach(sessions) { session in
                        sessionRow(session)
                            .onTapGesture { selectedSession = session }
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
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
        HStack {
            Button {
                if selectedWeek > 1 { selectedWeek -= 1 }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(selectedWeek <= 1)

            Spacer()

            VStack(spacing: 2) {
                Text(weekDateRange)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if planStore.currentWeekNumber == selectedWeek {
                    Text("Current Week")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }
            }

            Spacer()

            Button {
                if selectedWeek < planStore.totalWeeks { selectedWeek += 1 }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(selectedWeek >= planStore.totalWeeks)
        }
        .padding()
        .background(.bar)
    }

    private var weekDateRange: String {
        let sessions = planStore.sessions(for: selectedWeek)
        guard let first = sessions.first, let last = sessions.last else { return "" }
        let start = first.scheduledDate.formatted(.dateTime.month(.abbreviated).day())
        let end = last.scheduledDate.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) \u{2013} \(end)"
    }

    // MARK: - Week Summary Bar

    private var weekSummaryBar: some View {
        let sessions = planStore.sessions(for: selectedWeek)
            .filter { $0.workoutType != .strength }
        let plannedMi = sessions.compactMap(\.targetDistanceMi).reduce(0, +)
        let completed = sessions.filter { strava.activity(for: $0.id) != nil }.count
        let skipped = sessions.filter { planStore.isSkipped($0.id) }.count
        let actualMi = sessions.compactMap { strava.activity(for: $0.id)?.distanceMi }.reduce(0, +)

        return HStack(spacing: 16) {
            Label(String(format: "%.0f mi planned", plannedMi), systemImage: "target")
                .font(.caption)

            if actualMi > 0 {
                Label(String(format: "%.0f mi done", actualMi), systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Spacer()

            if completed > 0 {
                Text("\(completed) done")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            if skipped > 0 {
                Text("\(skipped) skipped")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Session Row

    private func sessionRow(_ session: PlannedSession) -> some View {
        let skipped = planStore.isSkipped(session.id)
        let isToday = Calendar.current.isDateInToday(session.scheduledDate)
        let activity = strava.activity(for: session.id)
        let strength = planStore.strengthSession(for: session)

        return HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(session.scheduledDate.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(Calendar.current.component(.day, from: session.scheduledDate))")
                    .font(.title3.bold())
            }
            .frame(width: 40)

            Image(systemName: session.workoutType.iconName)
                .font(.body)
                .foregroundStyle(session.workoutType.swiftUIColor)
                .frame(width: 32, height: 32)
                .background(session.workoutType.swiftUIColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.workoutType.displayName)
                        .font(.headline)
                        .strikethrough(skipped)

                    if strength != nil {
                        Label("Strength", systemImage: "dumbbell.fill")
                            .font(.caption2)
                            .foregroundStyle(.indigo)
                    }
                }

                if let mi = session.targetDistanceMi {
                    Text(String(format: "%.1f mi", mi))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let pace = session.targetPaceDescription, !pace.isEmpty {
                    Text(pace)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let activity {
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(String(format: "%.1f mi", activity.distanceMi))
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            } else if skipped {
                Text("Skipped")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fontWeight(.semibold)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isToday ? session.workoutType.swiftUIColor.opacity(0.08) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isToday ? session.workoutType.swiftUIColor.opacity(0.3) : .clear, lineWidth: 1)
        )
        .opacity(skipped ? 0.6 : 1.0)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("No plan loaded yet")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Create a training plan to see your weekly schedule.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}

#Preview {
    WeekView()
        .environment(TrainingPlanStore())
        .environment(StravaService())
}
