import SwiftUI

struct PlanSetupView: View {
    @Environment(AuthService.self) private var auth
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(StretchStore.self) private var stretchStore
    @Environment(PatreonService.self) private var patreon
    @Environment(\.dismiss) private var dismiss

    @State private var raceName = ""
    @State private var raceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 7, day: 18)
    )!
    @State private var selectedTemplate: TrainingPlanTemplate?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isConnectingPatreon = false

    private var premiumLocked: Bool {
        PatreonService.arePremiumPlansLocked(
            isRequired: patreon.isRequired,
            isPatron: patreon.isPatron,
            gracePeriodDaysRemaining: patreon.gracePeriodDaysRemaining
        )
    }

    private var templates: [TrainingPlanTemplate] {
        PlanTemplateService.shared.availableTemplates(includesPatronOnly: !premiumLocked)
    }

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
                            Text(template.name)
                                .tag(template as TrainingPlanTemplate?)
                        }
                    }

                    inlinePatreonBlock
                } footer: {
                    if let template = selectedTemplate {
                        VStack(alignment: .leading, spacing: 4) {
                            if template.source == "SWAP Running" {
                                Text("By \(BrandKit.coachCredit) • \(template.durationWeeks) weeks")
                                    .foregroundStyle(Color.trailGreen)
                            } else {
                                Text("\(template.durationWeeks) weeks \u{2022} \(template.author)")
                            }
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
                                Text("Add Training Plan")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canCreate || planStore.isLoading)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Plan")
                        .font(.custom("Fraunces-SemiBold", size: 22, relativeTo: .headline))
                        .foregroundStyle(Color.primary)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if selectedTemplate == nil {
                    #if DEBUG
                    raceName = "MJ"
                    raceDate = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 9))!
                    selectedTemplate = templates.first(where: { $0.name.localizedCaseInsensitiveContains("champion") }) ?? templates.first
                    #else
                    selectedTemplate = templates.first
                    #endif
                }
            }
            .onChange(of: premiumLocked) { _, locked in
                // If patron access flips off mid-flow, reset a now-hidden
                // selection so the picker doesn't display a stale label.
                if locked, let current = selectedTemplate,
                   PlanTemplateService.shared.isPatronOnly(current) {
                    selectedTemplate = templates.first
                }
            }
        }
    }

    // MARK: - Inline Patreon block

    /// Shared font for the primary action line across not-connected and
    /// not-patron states. Same weight + size so the affordance reads as
    /// one role regardless of where the user is in the unlock flow.
    private var unlockActionFont: Font {
        .system(size: 17, weight: .semibold)
    }

    @ViewBuilder
    private var inlinePatreonBlock: some View {
        if patreon.isRequired {
            if patreon.isPatron || patreon.gracePeriodDaysRemaining != nil {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.trailGreen)
                    Text("Patreon connected — full catalog unlocked")
                        .font(TrailFont.meta)
                        .foregroundStyle(Color.trailGreen)
                }
            } else if patreon.isConnected {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Patreon connected — subscribe at $5+/mo to unlock the full SWAP catalog.")
                        .font(TrailFont.meta)
                        .foregroundStyle(.secondary)
                    Link(destination: BrandKit.patreonURL) {
                        Text("Subscribe on Patreon \u{2197}")
                            .font(unlockActionFont)
                            .foregroundStyle(Color.trailGreen)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Unlock the full SWAP catalog with a Patreon membership.")
                        .font(TrailFont.meta)
                        .foregroundStyle(.secondary)
                    Button {
                        connectPatreon()
                    } label: {
                        HStack(spacing: 6) {
                            if isConnectingPatreon { ProgressView().controlSize(.small) }
                            Text("Connect Patreon")
                                .font(unlockActionFont)
                        }
                        .foregroundStyle(Color.trailGreen)
                    }
                    .disabled(isConnectingPatreon)
                    Text("We'll open Patreon in a new window.")
                        .font(TrailFont.meta)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func connectPatreon() {
        Task {
            isConnectingPatreon = true
            defer { isConnectingPatreon = false }
            do { try await patreon.authorize() }
            catch {
                errorMessage = error.localizedDescription
                showingError = true
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
            strengthStore.initializeFromPlannedSessions(
                planStore.sessions,
                planId: plan.id
            )

            if let heatTemplates = template.heatSessions, !heatTemplates.isEmpty {
                heatStore.initializeFromTemplate(
                    heatTemplates,
                    planId: plan.id,
                    planStartDate: plan.planStartDate,
                    totalWeeks: template.durationWeeks
                )
            }

            if let stretchExercises = template.stretchExercises, !stretchExercises.isEmpty {
                stretchStore.initializeFromTemplate(
                    stretchExercises,
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
        .environment(StretchStore())
        .environment(PatreonService())
}
