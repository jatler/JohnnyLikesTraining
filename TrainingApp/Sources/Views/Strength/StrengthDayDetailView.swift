import SwiftUI

struct StrengthDayDetailView: View {
    let weekNumber: Int
    let dayOfWeek: Int

    @Environment(StrengthStore.self) private var strengthStore
    @Environment(\.dismiss) private var dismiss

    private let dayNames = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let daySessions = strengthStore.sessions(for: weekNumber, dayOfWeek: dayOfWeek)

                    if daySessions.isEmpty {
                        Text("No strength sessions for this day")
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(daySessions) { session in
                            strengthCard(session)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
            .navigationTitle("\(dayNames[dayOfWeek]) — Week \(weekNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Strength Card

    private func strengthCard(_ session: StrengthSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(Color.trailGreen)

                Text("Strength")
                    .font(TrailFont.title)

                Spacer()

                Button {
                    strengthStore.toggleComplete(session.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: session.isComplete ? "checkmark.circle.fill" : "circle")
                        Text(session.isComplete ? "Done" : "Mark Done")
                            .font(TrailFont.meta)
                    }
                    .foregroundStyle(session.isComplete ? .green : .secondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(session.isComplete ? .green : .secondary)
            }

            Text(session.coachNotes)
                .font(TrailFont.coach)
                .foregroundStyle(session.isComplete ? .secondary : .primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StrengthDayDetailView(weekNumber: 1, dayOfWeek: 3)
        .environment(StrengthStore())
}
