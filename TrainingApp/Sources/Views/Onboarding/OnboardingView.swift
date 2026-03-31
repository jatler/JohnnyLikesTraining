import SwiftUI

struct OnboardingView: View {
    @Environment(AuthService.self) private var auth
    @Environment(PatreonService.self) private var patreon
    @Environment(StravaService.self) private var strava
    @Environment(OuraService.self) private var oura
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(StretchStore.self) private var stretchStore

    var onComplete: () -> Void

    @State private var currentPage = 0

    // Plan creation state
    @State private var raceName = ""
    @State private var raceDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
    @State private var selectedTemplate: TrainingPlanTemplate?
    @State private var showingPlanError = false
    @State private var planErrorMessage = ""

    private let templates = PlanTemplateService.shared.availableTemplates

    private var planStartDate: Date? {
        guard let template = selectedTemplate else { return nil }
        let daysBeforeRace = (template.durationWeeks - 1) * 7 + 5
        return Calendar.current.date(byAdding: .day, value: -daysBeforeRace, to: raceDate)
    }

    private var canCreatePlan: Bool {
        !raceName.trimmingCharacters(in: .whitespaces).isEmpty && selectedTemplate != nil
    }

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            connectServicesPage.tag(1)
            createPlanPage.tag(2)
            allSetPage.tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .onAppear {
            if selectedTemplate == nil {
                selectedTemplate = templates.first
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.swapAccent)

            VStack(spacing: 8) {
                Text("Welcome to SWAP Training")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("Train with David & Megan Roche")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.swapAccent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .padding()
    }

    // MARK: - Page 2: Connect Services

    private var connectServicesPage: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Connect Your Services")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("Optional \u{2014} you can always do this later in Settings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                serviceRow(
                    icon: "star.circle.fill",
                    name: "Patreon",
                    isConnected: patreon.isConnected
                ) {
                    try? await patreon.authorize()
                }

                serviceRow(
                    icon: "figure.run",
                    name: "Strava",
                    isConnected: strava.isConnected
                ) {
                    try? await strava.authorize()
                }

                serviceRow(
                    icon: "heart.circle.fill",
                    name: "Oura",
                    isConnected: oura.isConnected
                ) {
                    try? await oura.authorize()
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                withAnimation { currentPage = 2 }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.swapAccent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .padding()
    }

    private func serviceRow(
        icon: String,
        name: String,
        isConnected: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.swapAccent)
                .frame(width: 32)

            Text(name)
                .font(.body.weight(.medium))

            Spacer()

            if isConnected {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.swapAccent)
            } else {
                Button("Connect") {
                    Task { await action() }
                }
                .buttonStyle(.bordered)
                .tint(Color.swapAccent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Page 3: Create Plan

    private var createPlanPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Create Your Training Plan")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("Choose a plan and set your race date")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                VStack(spacing: 16) {
                    // Race name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Race Name")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        TextField("e.g. Tahoe Rim Trail 100K", text: $raceName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Race date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Race Date")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        DatePicker(
                            "Race Date",
                            selection: $raceDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }

                    // Template picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Training Plan")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Picker("Training Plan", selection: $selectedTemplate) {
                            Text("Select a plan").tag(nil as TrainingPlanTemplate?)
                            ForEach(templates) { template in
                                Text(template.name)
                                    .tag(template as TrainingPlanTemplate?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.swapAccent)
                    }

                    if let template = selectedTemplate {
                        VStack(alignment: .leading, spacing: 4) {
                            if template.source == "SWAP Running" {
                                Text("By \(BrandKit.coachCredit) \u{2022} \(template.durationWeeks) weeks")
                                    .font(.caption)
                                    .foregroundStyle(Color.swapAccent)
                            } else {
                                Text("\(template.durationWeeks) weeks \u{2022} \(template.author)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(template.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let start = planStartDate {
                        Text("Training starts \(start.formatted(date: .long, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

                Button {
                    createPlan()
                } label: {
                    if planStore.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Plan")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.swapAccent)
                .controlSize(.large)
                .disabled(!canCreatePlan || planStore.isLoading)
                .padding(.horizontal, 32)

                Button("Skip for now") {
                    withAnimation { currentPage = 3 }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 48)
            }
        }
        .alert("Error", isPresented: $showingPlanError) {
            Button("OK") {}
        } message: {
            Text(planErrorMessage)
        }
    }

    // MARK: - Page 4: All Set

    private var allSetPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.swapAccent)

            VStack(spacing: 8) {
                Text("You're All Set!")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("Your training journey starts now.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                onComplete()
            } label: {
                Text("Start Training")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.swapAccent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .padding()
    }

    // MARK: - Plan Creation

    private func createPlan() {
        guard let template = selectedTemplate else { return }

        guard let userId = auth.currentUserId else {
            planErrorMessage = "You must be signed in to create a plan."
            showingPlanError = true
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

            if let stretchExercises = template.stretchExercises, !stretchExercises.isEmpty {
                stretchStore.initializeFromTemplate(
                    stretchExercises,
                    planId: plan.id,
                    planStartDate: plan.planStartDate,
                    totalWeeks: template.durationWeeks
                )
            }
        }

        withAnimation { currentPage = 3 }
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environment(AuthService())
        .environment(PatreonService())
        .environment(StravaService())
        .environment(OuraService())
        .environment(TrainingPlanStore())
        .environment(StrengthStore())
        .environment(HeatStore())
        .environment(StretchStore())
}
