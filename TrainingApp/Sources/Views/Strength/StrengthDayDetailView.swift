import SwiftUI

struct StrengthDayDetailView: View {
    let weekNumber: Int
    let dayOfWeek: Int

    @Environment(StrengthStore.self) private var strengthStore
    @Environment(\.dismiss) private var dismiss

    @State private var logInputs: [UUID: [SetInput]] = [:]

    private let dayNames = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let daySessions = strengthStore.sessions(for: weekNumber, dayOfWeek: dayOfWeek)

                    if daySessions.isEmpty {
                        Text("No strength exercises for this day")
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(daySessions) { session in
                            exerciseCard(session)
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
            .onAppear { initializeInputs() }
        }
        .presentationDetents([.large])
    }

    // MARK: - Exercise Card

    private func exerciseCard(_ session: StrengthSession) -> some View {
        let sessionLogs = strengthStore.logs(for: session.id)
        let isComplete = strengthStore.isSessionComplete(session.id)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.indigo)

                Text(session.exerciseName)
                    .font(.headline)

                if session.isDeload {
                    Text("Deload")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: Capsule())
                }

                Spacer()

                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Text(prescriptionText(session))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(1...session.prescribedSets, id: \.self) { setNum in
                setRow(session: session, setNumber: setNum, existingLog: sessionLogs.first { $0.setNumber == setNum })
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Set Row

    private func setRow(session: StrengthSession, setNumber: Int, existingLog: StrengthLog?) -> some View {
        HStack(spacing: 12) {
            Text("Set \(setNumber)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            if let log = existingLog {
                completedSetView(log)
            } else {
                editableSetView(session: session, setNumber: setNumber)
            }
        }
    }

    private func completedSetView(_ log: StrengthLog) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)

            Text("\(log.actualReps) reps")
                .font(.subheadline)

            if let kg = log.actualWeightKg {
                Text("@ \(Int(kg * 2.205)) lbs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let rpe = log.rpe {
                Text("RPE \(String(format: "%.0f", rpe))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                strengthStore.deleteLog(log.id)
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.6))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    private func editableSetView(session: StrengthSession, setNumber: Int) -> some View {
        HStack(spacing: 8) {
            let inputs = logInputs[session.id] ?? []
            let inputIndex = setNumber - 1

            if inputIndex < inputs.count {
                TextField("reps", text: binding(session: session.id, set: inputIndex, keyPath: \.reps))
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)

                if session.prescribedWeightKg != nil {
                    TextField("lbs", text: binding(session: session.id, set: inputIndex, keyPath: \.weight))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 55)
                }

                Spacer()

                Button {
                    logSetFromInput(session: session, setNumber: setNumber)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.indigo)
                }
                .disabled(inputs[inputIndex].reps.isEmpty)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func prescriptionText(_ session: StrengthSession) -> String {
        var text = "\(session.prescribedSets)×\(session.prescribedReps)"
        if let kg = session.prescribedWeightKg {
            text += " @ \(Int(kg * 2.205)) lbs"
        }
        if let rpe = session.prescribedRpe {
            text += " • RPE \(String(format: "%.0f", rpe))"
        }
        return text
    }

    private func initializeInputs() {
        let daySessions = strengthStore.sessions(for: weekNumber, dayOfWeek: dayOfWeek)
        for session in daySessions {
            let defaultWeight = session.prescribedWeightKg.map { String(Int($0 * 2.205)) } ?? ""
            let defaultReps = String(session.prescribedReps)
            logInputs[session.id] = (0..<session.prescribedSets).map { _ in
                SetInput(reps: defaultReps, weight: defaultWeight)
            }
        }
    }

    private func binding(session sessionId: UUID, set index: Int, keyPath: WritableKeyPath<SetInput, String>) -> Binding<String> {
        Binding {
            logInputs[sessionId]?[index][keyPath: keyPath] ?? ""
        } set: { newValue in
            logInputs[sessionId]?[index][keyPath: keyPath] = newValue
        }
    }

    private func logSetFromInput(session: StrengthSession, setNumber: Int) {
        let inputIndex = setNumber - 1
        guard let inputs = logInputs[session.id],
              inputIndex < inputs.count,
              let reps = Int(inputs[inputIndex].reps) else { return }

        let weightKg = Double(inputs[inputIndex].weight).map { $0 / 2.205 }

        strengthStore.logSet(
            sessionId: session.id,
            setNumber: setNumber,
            reps: reps,
            weightKg: weightKg ?? session.prescribedWeightKg,
            rpe: nil
        )
    }
}

private struct SetInput {
    var reps: String
    var weight: String
}

#Preview {
    StrengthDayDetailView(weekNumber: 1, dayOfWeek: 3)
        .environment(StrengthStore())
}
