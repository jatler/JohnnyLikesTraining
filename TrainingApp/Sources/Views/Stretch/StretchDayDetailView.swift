import SwiftUI

struct StretchDayDetailView: View {
    let weekNumber: Int
    let dayOfWeek: Int

    @Environment(StretchStore.self) private var stretchStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingSkipOptions = false
    @State private var showingSwapTargets = false

    private static let dayNames = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private static let weekdayShort = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var daySessions: [StretchSession] {
        stretchStore.sessions(for: weekNumber, dayOfWeek: dayOfWeek)
    }

    private var completedCount: Int {
        daySessions.filter { stretchStore.isComplete($0.id) }.count
    }

    private var isDayComplete: Bool {
        !daySessions.isEmpty && completedCount == daySessions.count
    }

    private var isDaySkipped: Bool {
        stretchStore.isDaySkipped(weekNumber: weekNumber, dayOfWeek: dayOfWeek)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if daySessions.isEmpty {
                    emptyState
                } else {
                    summaryCard
                    progressSection
                    ForEach(daySessions) { session in
                        stretchCard(session)
                    }
                    actionsSection
                    if showingSwapTargets {
                        swapTargetsSection
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .presentationDetents([.custom(BannerGapDetent.self)])
        .presentationDragIndicator(.visible)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.flexibility")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No stretches for this day")
                .font(TrailFont.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: Summary

    private var summaryCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.flexibility")
                .font(.system(size: 20))
                .foregroundStyle(.mint)
                .frame(width: 43, height: 43)
                .background(Color.mint.opacity(0.15), in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 3) {
                Text("Stretches")
                    .font(.system(size: 18))
                    .strikethrough(isDaySkipped)
                    .opacity(isDaySkipped ? 0.5 : 1)
                Text(metaLine)
                    .font(TrailFont.data).tracking(0.5)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            trailingStatus
        }
        .unifiedCard()
    }

    @ViewBuilder
    private var trailingStatus: some View {
        if isDaySkipped {
            Text("SKIPPED")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.8), in: Capsule())
        } else if isDayComplete {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.trailGreen)
                .font(.title3)
                .completionPulse(true)
        }
    }

    private var metaLine: String {
        "WK \(weekNumber) D\(dayOfWeek) · \(completedCount)/\(daySessions.count) STRETCHES"
    }

    // MARK: Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(completedCount) of \(daySessions.count) done")
                    .font(TrailFont.body)
                Spacer()
                Text("\(Int((Double(completedCount) / Double(max(daySessions.count, 1))) * 100))%")
                    .font(TrailFont.data)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(completedCount), total: Double(max(daySessions.count, 1)))
                .tint(Color.trailGreen)
        }
        .unifiedCard()
        .opacity(isDaySkipped ? 0.5 : 1)
    }

    // MARK: Per-Stretch Card

    private func stretchCard(_ session: StretchSession) -> some View {
        let complete = stretchStore.isComplete(session.id)

        return HStack(alignment: .top, spacing: 12) {
            Button {
                if complete {
                    stretchStore.removeLog(sessionId: session.id)
                } else {
                    stretchStore.logCompletion(sessionId: session.id)
                }
            } label: {
                Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(complete ? Color.trailGreen : Color.secondary.opacity(0.4))
                    .completionPulse(complete)
            }
            .buttonStyle(.plain)
            .disabled(isDaySkipped)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.stretchName)
                    .font(.system(size: 18))
                    .strikethrough(complete || isDaySkipped)
                    .foregroundStyle(complete || isDaySkipped ? .secondary : .primary)

                Text(prescriptionText(session))
                    .font(TrailFont.data)
                    .foregroundStyle(.secondary)

                if let exercise = stretchStore.exercises.first(where: { $0.id == session.templateExerciseId }),
                   let notes = exercise.notes, !notes.isEmpty {
                    Text(notes)
                        .font(TrailFont.meta)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }

            Spacer()

            if session.isBilateral {
                Text("Bilateral")
                    .font(TrailFont.meta)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .unifiedCard()
        .opacity(isDaySkipped ? 0.5 : 1)
    }

    private func prescriptionText(_ session: StretchSession) -> String {
        let perSide = session.isBilateral ? " each side" : ""
        return "\(session.prescribedSets)×\(session.prescribedHoldSeconds)s hold\(perSide)"
    }

    // MARK: Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if isDaySkipped {
                Button {
                    stretchStore.unskipDay(weekNumber: weekNumber, dayOfWeek: dayOfWeek)
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            } else {
                markDoneButton

                HStack(spacing: 8) {
                    Button {
                        showingSkipOptions = true
                    } label: {
                        Label("Skip", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .confirmationDialog("Skip these stretches?", isPresented: $showingSkipOptions) {
                        Button("Injury") { stretchStore.skipDay(weekNumber: weekNumber, dayOfWeek: dayOfWeek, reason: "Injury") }
                        Button("Illness") { stretchStore.skipDay(weekNumber: weekNumber, dayOfWeek: dayOfWeek, reason: "Illness") }
                        Button("Life / Schedule") { stretchStore.skipDay(weekNumber: weekNumber, dayOfWeek: dayOfWeek, reason: "Life") }
                        Button("Skip (no reason)") { stretchStore.skipDay(weekNumber: weekNumber, dayOfWeek: dayOfWeek, reason: nil) }
                        Button("Cancel", role: .cancel) {}
                    }

                    Button {
                        withAnimation { showingSwapTargets.toggle() }
                    } label: {
                        Label("Swap", systemImage: "arrow.left.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                }
            }
        }
    }

    @ViewBuilder
    private var markDoneButton: some View {
        if isDayComplete {
            Button {
                stretchStore.unmarkDayComplete(weekNumber: weekNumber, dayOfWeek: dayOfWeek)
            } label: {
                Label("Mark Incomplete", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        } else {
            Button {
                stretchStore.markDayComplete(weekNumber: weekNumber, dayOfWeek: dayOfWeek)
            } label: {
                Label("Mark All Done", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.trailGreen)
        }
    }

    // MARK: Swap

    private var swapTargetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select a day to swap with:")
                .font(TrailFont.body)
                .foregroundStyle(.secondary)

            ForEach(1...7, id: \.self) { day in
                if day != dayOfWeek {
                    Button {
                        stretchStore.moveDay(weekNumber: weekNumber, fromDay: dayOfWeek, toDay: day)
                        showingSwapTargets = false
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(.mint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Self.dayNames[day])
                                    .font(TrailFont.body)
                                Text(swapPreview(for: day))
                                    .font(TrailFont.meta)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(TrailFont.meta)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func swapPreview(for day: Int) -> String {
        let existing = stretchStore.sessions(for: weekNumber, dayOfWeek: day)
        guard !existing.isEmpty else { return "Empty" }
        return "Has \(existing.count) stretch\(existing.count == 1 ? "" : "es")"
    }
}

struct StretchDaySelection: Identifiable {
    let id = UUID()
    let weekNumber: Int
    let dayOfWeek: Int
}

#Preview {
    StretchDayDetailView(weekNumber: 1, dayOfWeek: 2)
        .environment(StretchStore())
}
