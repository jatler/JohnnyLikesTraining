import SwiftUI

struct StrengthDayDetailView: View {
    let weekNumber: Int
    let dayOfWeek: Int

    @Environment(StrengthStore.self) private var strengthStore
    @Environment(\.dismiss) private var dismiss

    private static let dayNames = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    let daySessions = strengthStore.sessions(for: weekNumber, dayOfWeek: dayOfWeek)

                    if daySessions.isEmpty {
                        Text("No strength sessions for this day")
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(daySessions) { session in
                            SessionDetail(session: session)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .navigationTitle("\(Self.dayNames[dayOfWeek]) — Week \(weekNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Per-Session Detail

/// One strength session's worth of UI: summary card, coach notes, action row.
/// Mirrors `SessionDetailSheet` for cardio so the two windows feel identical.
private struct SessionDetail: View {
    let session: StrengthSession

    @Environment(StrengthStore.self) private var strengthStore

    @State private var showingSkipOptions = false
    @State private var showingSwapTargets = false
    @State private var isEditing = false
    @State private var editNotes: String = ""

    private static let weekdayNames = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var isSkipped: Bool { strengthStore.isSkipped(session.id) }
    private var isEdited: Bool { strengthStore.isEdited(session.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isEditing {
                editHeader
                editForm
            } else {
                summaryCard
                if !session.coachNotes.isEmpty {
                    notesSection
                }
                actionsSection
                if showingSwapTargets {
                    swapTargetsSection
                }
            }
        }
    }

    // MARK: Summary

    private var summaryCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.trailGreen)
                .frame(width: 43, height: 43)
                .background(Color.trailGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Strength")
                        .font(.system(size: 18))
                        .strikethrough(isSkipped)
                        .opacity(isSkipped ? 0.5 : 1)
                    if isEdited {
                        Image(systemName: "pencil.circle.fill")
                            .font(TrailFont.meta)
                            .foregroundStyle(.orange)
                    }
                }
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
        if isSkipped {
            Text("SKIPPED")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.8), in: Capsule())
        } else {
            Button {
                strengthStore.toggleComplete(session.id)
            } label: {
                Image(systemName: session.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(session.isComplete ? Color.trailGreen : Color.secondary.opacity(0.4))
                    .completionPulse(session.isComplete)
            }
            .buttonStyle(.plain)
        }
    }

    private var metaLine: String {
        "WK \(session.weekNumber) D\(session.dayOfWeek) · \(Self.weekdayNames[session.dayOfWeek].uppercased())"
    }

    // MARK: Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coach notes")
                .font(TrailFont.coach)
                .foregroundStyle(.secondary)
            Text(session.coachNotes)
                .font(TrailFont.body)
                .foregroundStyle(isSkipped ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .unifiedCard()
    }

    // MARK: Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if isSkipped {
                Button {
                    strengthStore.unskipSession(session.id)
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            } else {
                HStack(spacing: 8) {
                    Button {
                        showingSkipOptions = true
                    } label: {
                        Label("Skip", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .confirmationDialog("Skip this workout?", isPresented: $showingSkipOptions) {
                        Button("Injury") { strengthStore.skipSession(session.id, reason: "Injury") }
                        Button("Illness") { strengthStore.skipSession(session.id, reason: "Illness") }
                        Button("Life / Schedule") { strengthStore.skipSession(session.id, reason: "Life") }
                        Button("Skip (no reason)") { strengthStore.skipSession(session.id, reason: nil) }
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

                    Button {
                        editNotes = session.coachNotes
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                }
            }
        }
    }

    // MARK: Swap (move to different day)

    private var swapTargetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Move to a different day:")
                .font(TrailFont.body)
                .foregroundStyle(.secondary)

            ForEach(1...7, id: \.self) { day in
                if day != session.dayOfWeek {
                    Button {
                        strengthStore.moveToDay(session.id, dayOfWeek: day)
                        showingSwapTargets = false
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(Color.trailGreen)
                                .frame(width: 28)
                            Text(StrengthDayDetailView.dayName(for: day))
                                .font(TrailFont.body)
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

    // MARK: Edit

    private var editHeader: some View {
        HStack {
            Button("Cancel") { isEditing = false }
                .font(TrailFont.data).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Save") {
                strengthStore.updateCoachNotes(session.id, notes: editNotes)
                isEditing = false
            }
            .font(TrailFont.data).fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.trailGreen, in: Capsule())
        }
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Strength")
                .font(TrailFont.title)

            VStack(alignment: .leading, spacing: 8) {
                Text("Coach notes")
                    .font(TrailFont.body)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    if editNotes.isEmpty {
                        Text("Describe the session — exercises, sets, reps")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $editNotes)
                        .font(TrailFont.body)
                        .frame(minHeight: 220)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(.separator), lineWidth: 1)
                )
            }

            if isEdited {
                Button {
                    strengthStore.resetToOriginal(session.id)
                    isEditing = false
                } label: {
                    Label("Reset to Original Plan", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
    }
}

// MARK: - Helpers

extension StrengthDayDetailView {
    fileprivate static func dayName(for day: Int) -> String {
        guard (1...7).contains(day) else { return "" }
        return dayNames[day]
    }
}

#Preview {
    StrengthDayDetailView(weekNumber: 1, dayOfWeek: 3)
        .environment(StrengthStore())
}
