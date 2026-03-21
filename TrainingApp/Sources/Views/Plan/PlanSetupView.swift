import SwiftUI

struct PlanSetupView: View {
    @Environment(AuthService.self) private var auth
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(\.dismiss) private var dismiss

    @State private var raceName = ""
    @State private var raceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 7, day: 18)
    )!
    @State private var selectedTemplate: TrainingPlanTemplate?
    @State private var showingError = false
    @State private var errorMessage = ""

    private let templates = PlanTemplateService.shared.availableTemplates

    private var planStartDate: Date? {
        guard let template = selectedTemplate else { return nil }
        let daysBeforeRace = (template.durationWeeks - 1) * 7 + 5
        return Calendar.current.date(byAdding: .day, value: -daysBeforeRace, to: raceDate)
    }

    private var canCreate: Bool {
        !raceName.trimmingCharacters(in: .whitespaces).isEmpty && selectedTemplate != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Tahoe Rim Trail Endurance Run 100K", text: $raceName)
                } header: {
                    Text("Race Name")
                } footer: {
                    Text("The name of your target race or training goal.")
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
                    if let template = selectedTemplate {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(template.durationWeeks) weeks \u{2022} \(template.author)")
                            Text(template.description)
                        }
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
                        createPlan()
                    } label: {
                        HStack {
                            Spacer()
                            if planStore.isLoading {
                                ProgressView()
                            } else {
                                Text("Create Training Plan")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canCreate || planStore.isLoading)
                }
            }
            .navigationTitle("New Plan")
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if selectedTemplate == nil {
                    selectedTemplate = templates.first
                }
            }
        }
    }

    private func createPlan() {
        guard let template = selectedTemplate else { return }

        guard let userId = auth.currentUserId else {
            errorMessage = "You must be signed in to create a plan."
            showingError = true
            return
        }

        planStore.createPlan(
            raceName: raceName.trimmingCharacters(in: .whitespaces),
            raceDate: raceDate,
            template: template,
            userId: userId
        )

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

        dismiss()
    }
}

// MARK: - Hashable / Equatable for picker binding

extension TrainingPlanTemplate: Equatable {
    static func == (lhs: TrainingPlanTemplate, rhs: TrainingPlanTemplate) -> Bool {
        lhs.id == rhs.id
    }
}

extension TrainingPlanTemplate: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    PlanSetupView()
        .environment(AuthService())
        .environment(TrainingPlanStore())
        .environment(StrengthStore())
        .environment(HeatStore())
}
