import SwiftUI

struct StretchDayDetailView: View {
    let weekNumber: Int
    let dayOfWeek: Int

    @Environment(StretchStore.self) private var stretchStore
    @Environment(\.dismiss) private var dismiss

    private let dayNames = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let daySessions = stretchStore.sessions(for: weekNumber, dayOfWeek: dayOfWeek)

                    if daySessions.isEmpty {
                        Text("No stretches for this day")
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    } else {
                        let completed = daySessions.filter { stretchStore.isComplete($0.id) }.count
                        progressHeader(completed: completed, total: daySessions.count)

                        ForEach(daySessions) { session in
                            stretchCard(session)
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

    private func progressHeader(completed: Int, total: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.flexibility")
                .font(.title3)
                .foregroundStyle(.teal)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(completed)/\(total) stretches done")
                    .font(.subheadline.bold())

                ProgressView(value: Double(completed), total: Double(total))
                    .tint(.teal)
            }

            if completed == total {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        }
        .padding()
        .background(.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func stretchCard(_ session: StretchSession) -> some View {
        let complete = stretchStore.isComplete(session.id)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(complete ? .green : .secondary.opacity(0.4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.stretchName)
                        .font(.headline)
                        .strikethrough(complete)
                        .foregroundStyle(complete ? .secondary : .primary)

                    Text(prescriptionText(session))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if session.isBilateral {
                    Text("Bilateral")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }

            if let exercise = stretchStore.exercises.first(where: { $0.id == session.templateExerciseId }),
               let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                if complete {
                    stretchStore.removeLog(sessionId: session.id)
                } else {
                    stretchStore.logCompletion(sessionId: session.id)
                }
            } label: {
                Label(
                    complete ? "Undo" : "Mark Done",
                    systemImage: complete ? "arrow.uturn.backward" : "checkmark"
                )
                .frame(maxWidth: .infinity)
                .font(.subheadline.bold())
            }
            .buttonStyle(.bordered)
            .tint(complete ? .secondary : .teal)
            .controlSize(.small)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func prescriptionText(_ session: StretchSession) -> String {
        let perSide = session.isBilateral ? " each side" : ""
        return "\(session.prescribedSets)×\(session.prescribedHoldSeconds)s hold\(perSide)"
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
