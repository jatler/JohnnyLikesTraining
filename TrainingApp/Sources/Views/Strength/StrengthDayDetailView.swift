import SwiftUI

struct StrengthDayDetailView: View {
    let weekNumber: Int
    let dayOfWeek: Int

    @Environment(StrengthStore.self) private var strengthStore
    @Environment(\.dismiss) private var dismiss

    private static let dayNames = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                let daySessions = strengthStore.sessions(for: weekNumber, dayOfWeek: dayOfWeek)

                if daySessions.isEmpty {
                    emptyState
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
        .presentationDetents([.custom(BannerGapDetent.self)])
        .presentationDragIndicator(.visible)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No strength sessions for this day")
                .font(TrailFont.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
    @State private var editAthleteNotes: String = ""

    private var isSkipped: Bool { strengthStore.isSkipped(session.id) }
    private var isEdited: Bool { strengthStore.isEdited(session.id) }

    /// Parse a row-style headline out of `coachNotes` ("Mountain Legs: 3x10..."
    /// → "Mountain Legs"). Matches the boldDayRow split so the detail sheet
    /// echoes whatever the user tapped.
    private var displayTitle: String {
        let trimmed = session.coachNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Strength" }
        if let colonIdx = trimmed.firstIndex(of: ":") {
            let head = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            if !head.isEmpty, head.count <= 40 { return head }
        }
        if let dotIdx = trimmed.firstIndex(of: ".") {
            let head = String(trimmed[..<dotIdx]).trimmingCharacters(in: .whitespaces)
            if !head.isEmpty, head.count <= 40 { return head }
        }
        return "Strength"
    }

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
                athleteNotesReadonly
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
                    Text(displayTitle)
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
        } else if session.isComplete {
            // Burst animation on first appearance, same as the Week tab.
            // CompletionCelebrationStore keeps the burst one-shot — second
            // visit to the sheet (or the row outside) shows the filled
            // checked state directly. magnitude = 20 produces a Week-tab-sized
            // grow (~2.4×) since strength has no mileage to scale against.
            CompleteStatus(
                magnitude: 20,
                label: "",
                sessionId: session.id,
                baseSize: 22
            )
        }
    }

    private var metaLine: String {
        "WK \(session.weekNumber) D\(session.dayOfWeek)"
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

    /// Read-only athlete-notes card. Hidden when nothing's been written so the
    /// summary stays tight for fresh sessions.
    @ViewBuilder
    private var athleteNotesReadonly: some View {
        if let text = session.athleteNotes?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Athlete notes")
                    .font(TrailFont.coach)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(TrailFont.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .unifiedCard()
        }
    }

    /// Edit-mode athlete-notes input. Saves through `updateAthleteNotes`,
    /// independent of `updateCoachNotes`, so a journal entry doesn't trip the
    /// "edited" pencil + Reset-to-Original flow.
    private var athleteNotesEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Athlete notes")
                .font(TrailFont.body)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                if editAthleteNotes.isEmpty {
                    Text("How did this session feel? What did you actually do?")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $editAthleteNotes)
                    .font(TrailFont.body)
                    .frame(minHeight: 140)
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
                        editAthleteNotes = session.athleteNotes ?? ""
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

    @ViewBuilder
    private var markDoneButton: some View {
        if session.isComplete {
            Button {
                strengthStore.toggleComplete(session.id)
            } label: {
                Label("Mark Incomplete", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        } else {
            Button {
                strengthStore.toggleComplete(session.id)
            } label: {
                Label("Mark Done", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.trailGreen)
        }
    }

    // MARK: Swap (move to different day)

    private var swapTargetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select a day to swap with:")
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(StrengthDayDetailView.dayName(for: day))
                                    .font(TrailFont.body)
                                if let preview = swapPreview(for: day) {
                                    Text(preview)
                                        .font(TrailFont.meta)
                                        .foregroundStyle(.secondary)
                                }
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

    private func swapPreview(for day: Int) -> String? {
        let existing = strengthStore.sessions(for: session.weekNumber, dayOfWeek: day)
        guard !existing.isEmpty else { return "Empty" }
        return "Also has \(existing.count) strength session\(existing.count == 1 ? "" : "s")"
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
                // Athlete notes save on a parallel path so a fresh journal
                // entry doesn't mark the session as "edited."
                strengthStore.updateAthleteNotes(session.id, notes: editAthleteNotes)
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

            athleteNotesEditor

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
