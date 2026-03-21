import SwiftUI

struct PlanEditView: View {
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var raceName: String
    @State private var raceDate: Date
    @State private var selectedTemplate: TrainingPlanTemplate?
    @State private var showingReplaceConfirmation = false

    private let originalTemplateId: String?
    private let templates = PlanTemplateService.shared.availableTemplates

    init(plan: TrainingPlan, template: TrainingPlanTemplate?) {
        _raceName = State(initialValue: plan.name)
        _raceDate = State(initialValue: plan.raceDate)
        _selectedTemplate = State(initialValue: template)
        originalTemplateId = template?.id
    }

    private var templateChanged: Bool {
        selectedTemplate?.id != originalTemplateId
    }

    private var planStartDate: Date? {
        guard let template = selectedTemplate else { return nil }
        let daysBeforeRace = (template.durationWeeks - 1) * 7 + 5
        return Calendar.current.date(byAdding: .day, value: -daysBeforeRace, to: raceDate)
    }

    private var hasChanges: Bool {
        let nameChanged = raceName.trimmingCharacters(in: .whitespaces) != planStore.activePlan?.name
        let dateChanged: Bool = {
            guard let planDate = planStore.activePlan?.raceDate else { return false }
            return !Calendar.current.isDate(raceDate, inSameDayAs: planDate)
        }()
        return nameChanged || dateChanged || templateChanged
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Race Name", text: $raceName)
                } header: {
                    Text("Race Name")
                }

                Section {
                    DatePicker(
                        "Race Date",
                        selection: $raceDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                } footer: {
                    if let start = planStartDate {
                        Text("Training starts \(start.formatted(date: .long, time: .omitted))")
                    }
                }

                Section {
                    Picker("Training Plan", selection: $selectedTemplate) {
                        Text("Select a plan").tag(nil as TrainingPlanTemplate?)
                        ForEach(templates) { template in
                            Text(template.name).tag(template as TrainingPlanTemplate?)
                        }
                    }
                } footer: {
                    if templateChanged {
                        Label(
                            "Changing the template will replace your entire plan and reset all swaps and skips.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }

                if let template = selectedTemplate, let start = planStartDate {
                    Section("Plan Summary") {
                        LabeledContent("Duration", value: "\(template.durationWeeks) weeks")
                        LabeledContent("Starts", value: start.formatted(date: .abbreviated, time: .omitted))
                        LabeledContent("Race Day", value: raceDate.formatted(date: .abbreviated, time: .omitted))
                        LabeledContent("Total Sessions", value: "\(template.sessions.count)")
                    }
                }

                Section {
                    Button {
                        saveChanges()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Save Changes")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!hasChanges || raceName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Replace Training Plan?", isPresented: $showingReplaceConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Replace", role: .destructive) {
                    applyChanges(replaceTemplate: true)
                }
            } message: {
                Text("This will replace your entire plan with the new template. All swaps and skips will be reset.")
            }
        }
    }

    private func saveChanges() {
        if templateChanged {
            showingReplaceConfirmation = true
        } else {
            applyChanges(replaceTemplate: false)
        }
    }

    private func applyChanges(replaceTemplate: Bool) {
        let trimmedName = raceName.trimmingCharacters(in: .whitespaces)

        if replaceTemplate, let template = selectedTemplate, let userId = auth.currentUserId {
            planStore.replacePlan(raceName: trimmedName, raceDate: raceDate, template: template, userId: userId)

            strengthStore.clearAll()
            heatStore.clearAll()
            if let plan = planStore.activePlan {
                if let strengthExercises = template.strengthExercises, !strengthExercises.isEmpty {
                    strengthStore.initializeFromTemplate(
                        strengthExercises,
                        planId: plan.id,
                        planStartDate: plan.planStartDate,
                        totalWeeks: template.durationWeeks
                    )
                }
                if let heatTemplates = template.heatSessions, !heatTemplates.isEmpty {
                    heatStore.initializeFromTemplate(
                        heatTemplates,
                        planId: plan.id,
                        planStartDate: plan.planStartDate,
                        totalWeeks: template.durationWeeks
                    )
                }
            }
        } else {
            if trimmedName != planStore.activePlan?.name {
                planStore.updateRaceName(trimmedName)
            }

            if let template = selectedTemplate,
               let planDate = planStore.activePlan?.raceDate,
               !Calendar.current.isDate(raceDate, inSameDayAs: planDate) {
                planStore.updateRaceDate(raceDate, template: template)
            }
        }

        dismiss()
    }
}
