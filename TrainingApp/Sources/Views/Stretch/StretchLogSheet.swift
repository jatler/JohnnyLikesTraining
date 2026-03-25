import SwiftUI

struct AddStretchExerciseSheet: View {
    let dayOfWeek: Int
    @Environment(StretchStore.self) private var stretchStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var holdSeconds = 45
    @State private var sets = 1
    @State private var isBilateral = true
    @State private var notes = ""

    private let dayNames = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Stretch") {
                    TextField("Stretch name (e.g. Pigeon Pose)", text: $name)
                }

                Section("Prescription") {
                    Stepper("Hold: \(holdSeconds)s", value: $holdSeconds, in: 10...120, step: 5)
                    Stepper("Sets: \(sets)", value: $sets, in: 1...5)
                    Toggle("Bilateral (each side)", isOn: $isBilateral)
                }

                Section("Notes") {
                    TextField("PT notes, cues, modifications…", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Add to \(dayNames[dayOfWeek])")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addExercise() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addExercise() {
        stretchStore.addExercise(
            dayOfWeek: dayOfWeek,
            name: name.trimmingCharacters(in: .whitespaces),
            holdSeconds: holdSeconds,
            sets: sets,
            isBilateral: isBilateral,
            notes: notes.isEmpty ? nil : notes
        )
        dismiss()
    }
}

struct EditStretchExerciseSheet: View {
    @State var exercise: StretchTemplateExercise
    @Environment(StretchStore.self) private var stretchStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var holdSeconds: Int = 45
    @State private var sets: Int = 1
    @State private var isBilateral: Bool = true
    @State private var notes: String = ""
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Stretch") {
                    TextField("Stretch name", text: $name)
                }

                Section("Prescription") {
                    Stepper("Hold: \(holdSeconds)s", value: $holdSeconds, in: 10...120, step: 5)
                    Stepper("Sets: \(sets)", value: $sets, in: 1...5)
                    Toggle("Bilateral (each side)", isOn: $isBilateral)
                }

                Section("Notes") {
                    TextField("PT notes, cues, modifications…", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Remove Stretch", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit Stretch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExercise() }
                }
            }
            .alert("Remove Stretch?", isPresented: $showingDeleteConfirmation) {
                Button("Remove", role: .destructive) {
                    stretchStore.removeExercise(exercise)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove \(exercise.stretchName) from your template and all future weeks.")
            }
            .onAppear {
                name = exercise.stretchName
                holdSeconds = exercise.holdSeconds
                sets = exercise.sets
                isBilateral = exercise.isBilateral
                notes = exercise.notes ?? ""
            }
        }
    }

    private func saveExercise() {
        var updated = exercise
        updated.stretchName = name.trimmingCharacters(in: .whitespaces)
        updated.holdSeconds = holdSeconds
        updated.sets = sets
        updated.isBilateral = isBilateral
        updated.notes = notes.isEmpty ? nil : notes

        stretchStore.updateExercise(updated)
        dismiss()
    }
}
