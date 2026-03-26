import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(OuraService.self) private var oura
    @Environment(PatreonService.self) private var patreon

    @State private var showingSignOutAlert = false
    @State private var showingDisconnectStrava = false
    @State private var showingDisconnectOura = false
    @State private var showingDisconnectPatreon = false
    @State private var showingDeletePlan = false
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            List {
                gracePeriodBanner
                patreonSection
                stravaSection
                ouraSection
                planSection
                accountSection
                aboutSection
            }
            .navigationTitle("Settings")
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An unexpected error occurred.")
            }
        }
    }

    // MARK: - Grace Period Banner

    @ViewBuilder
    private var gracePeriodBanner: some View {
        if let daysLeft = patreon.gracePeriodDaysRemaining {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your access expires in \(daysLeft) day\(daysLeft == 1 ? "" : "s")")
                            .font(.subheadline.bold())
                        Link("Resubscribe on Patreon ↗", destination: BrandKit.patreonURL)
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Patreon

    private var patreonSection: some View {
        Section {
            if patreon.isConnected {
                HStack {
                    Label("SWAP Patreon", systemImage: "star.circle.fill")
                        .foregroundStyle(Color.swapAccent)
                    Spacer()
                    Text("Connected")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                if let lastVerified = patreon.lastVerifiedAt {
                    HStack {
                        Text("Last verified")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(lastVerified.formatted(.relative(presentation: .named)))
                    }
                    .font(.subheadline)
                }

                Button("Disconnect Patreon", role: .destructive) {
                    showingDisconnectPatreon = true
                }
                .alert("Disconnect Patreon?", isPresented: $showingDisconnectPatreon) {
                    Button("Cancel", role: .cancel) {}
                    Button("Disconnect", role: .destructive) { patreon.disconnect() }
                } message: {
                    Text("You'll lose access to SWAP training plans.")
                }
            } else {
                Button {
                    connectPatreon()
                } label: {
                    HStack {
                        Label("Connect Patreon", systemImage: "star.circle.fill")
                            .foregroundStyle(Color.swapAccent)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Patreon")
        } footer: {
            if !patreon.isConnected {
                Text("Connect your SWAP Patreon account to unlock all training plans.")
            }
        }
    }

    // MARK: - Strava

    private var stravaSection: some View {
        Section {
            if strava.isConnected {
                HStack {
                    Label("Strava", systemImage: "figure.run")
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("Connected")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                if let name = strava.athleteName {
                    HStack {
                        Text("Athlete")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(name)
                    }
                    .font(.subheadline)
                }

                if let lastSync = strava.lastSyncDate {
                    HStack {
                        Text("Last sync")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(lastSync.formatted(.relative(presentation: .named)))
                    }
                    .font(.subheadline)
                }

                Button {
                    syncStrava()
                } label: {
                    HStack {
                        Label("Sync Activities", systemImage: "arrow.clockwise")
                        if strava.isSyncing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(strava.isSyncing)

                Button("Disconnect Strava", role: .destructive) {
                    showingDisconnectStrava = true
                }
                .alert("Disconnect Strava?", isPresented: $showingDisconnectStrava) {
                    Button("Cancel", role: .cancel) {}
                    Button("Disconnect", role: .destructive) { Task { await strava.disconnect() } }
                } message: {
                    Text("Your synced activities will be removed from the app.")
                }
            } else {
                Button {
                    connectStrava()
                } label: {
                    HStack {
                        Label("Connect Strava", systemImage: "figure.run")
                            .foregroundStyle(.orange)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Strava")
        } footer: {
            if !strava.isConnected {
                Text("Connect Strava to automatically import your runs and compare plan vs. actual.")
            }
        }
    }

    // MARK: - Oura

    private var ouraSection: some View {
        Section {
            if oura.isConnected {
                HStack {
                    Label("Oura Ring", systemImage: "heart.circle")
                        .foregroundStyle(.purple)
                    Spacer()
                    Text("Connected")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                if let lastSync = oura.lastSyncDate {
                    HStack {
                        Text("Last sync")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(lastSync.formatted(.relative(presentation: .named)))
                    }
                    .font(.subheadline)
                }

                Button {
                    syncOura()
                } label: {
                    HStack {
                        Label("Sync Recovery Data", systemImage: "arrow.clockwise")
                        if oura.isSyncing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(oura.isSyncing)

                Button("Disconnect Oura", role: .destructive) {
                    showingDisconnectOura = true
                }
                .alert("Disconnect Oura?", isPresented: $showingDisconnectOura) {
                    Button("Cancel", role: .cancel) {}
                    Button("Disconnect", role: .destructive) { oura.disconnect() }
                } message: {
                    Text("Your recovery data will no longer sync.")
                }
            } else {
                Button {
                    connectOura()
                } label: {
                    HStack {
                        Label("Connect Oura Ring", systemImage: "heart.circle")
                            .foregroundStyle(.purple)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Oura")
        } footer: {
            if !oura.isConnected {
                Text("Connect your Oura Ring to see readiness scores and get smart swap suggestions.")
            }
        }
    }

    // MARK: - Plan

    private var planSection: some View {
        Section("Training Plan") {
            if planStore.hasPlan {
                if let plan = planStore.activePlan {
                    HStack {
                        Text("Plan")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(plan.name)
                            .font(.subheadline)
                    }

                    HStack {
                        Text("Race Date")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(plan.raceDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                    }

                    HStack {
                        Text("Sessions")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(planStore.sessions.count)")
                            .font(.subheadline)
                    }
                }

                Button("Delete Plan", role: .destructive) {
                    showingDeletePlan = true
                }
                .alert("Delete Training Plan?", isPresented: $showingDeletePlan) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) { planStore.clearPlan() }
                } message: {
                    Text("This will permanently delete your plan and all associated swaps and skips.")
                }
            } else {
                Text("No active plan")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section("Account") {
            Button("Sign Out", role: .destructive) {
                showingSignOutAlert = true
            }
            .alert("Sign Out?", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task { try? await auth.signOut() }
                }
            } message: {
                Text("You'll need to sign in again to access your training data.")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func connectPatreon() {
        Task {
            do {
                try await patreon.authorize()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func connectStrava() {
        Task {
            do {
                try await strava.authorize()
                if let userId = auth.currentUserId {
                    try await strava.syncActivities(userId: userId)
                    strava.autoMatchActivities(sessions: planStore.sessions)
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func connectOura() {
        Task {
            do {
                try await oura.authorize()
                if let userId = auth.currentUserId {
                    try await oura.syncDaily(userId: userId)
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func syncStrava() {
        Task {
            do {
                guard let userId = auth.currentUserId else { return }
                try await strava.syncActivities(userId: userId)
                strava.autoMatchActivities(sessions: planStore.sessions)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func syncOura() {
        Task {
            do {
                guard let userId = auth.currentUserId else { return }
                try await oura.syncDaily(userId: userId)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthService())
        .environment(TrainingPlanStore())
        .environment(StravaService())
        .environment(OuraService())
        .environment(PatreonService())
}
