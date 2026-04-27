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
    @State private var showingPatreonGatePreview = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 16) {
                        gracePeriodBanner
                        sectionCard(label: "PATREON") { patreonSection }
                        if DevSignIn.isAllowed {
                            sectionCard(label: "PATREON DEBUG") { patreonDebugSection }
                        }
                        sectionCard(label: "STRAVA") { stravaSection }
                        sectionCard(label: "OURA") { ouraSection }
                        sectionCard(label: "TRAINING PLAN") { planSection }
                        sectionCard(label: "ACCOUNT") { accountSection }
                        sectionCard(label: "ABOUT") { aboutSection }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .padding(.bottom, 20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An unexpected error occurred.")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(TrailFont.tabHeading)
                .foregroundStyle(.white)

            // Hidden spacer line so the green band height matches Week / Progress /
            // Strength (all of which carry a meta line below the title).
            Text(" ")
                .font(TrailFont.data)
                .tracking(0.5)
                .foregroundStyle(.clear)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.trailGreen)
        .background(Color.trailGreen.ignoresSafeArea(edges: .top))
    }

    // MARK: - Card chrome

    @ViewBuilder
    private func sectionCard<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TrailFont.data).tracking(0.5)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        }
    }

    // MARK: - Row helpers

    /// Info row where the value is a datum (count, version string, numeric — renders in mono).
    private func infoRow(_ label: String, _ value: String) -> some View {
        infoRowBase(label: label, value: value, valueFont: TrailFont.data)
    }

    /// Info row where the value is prose (race name, athlete name — renders in SF body).
    private func infoRowText(_ label: String, _ value: String) -> some View {
        infoRowBase(label: label, value: value, valueFont: TrailFont.body)
    }

    private func infoRowBase(label: String, value: String, valueFont: Font) -> some View {
        HStack {
            Text(label)
                .font(TrailFont.body)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(valueFont)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func buttonRow(_ label: String, icon: String? = nil, color: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(color)
                        .frame(width: 24)
                }
                Text(label)
                    .font(TrailFont.body)
                    .foregroundStyle(color)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func linkRow<Label: View>(_ label: String, icon: String = "arrow.up.right.square", destination: URL, @ViewBuilder leading: () -> Label) -> some View {
        Link(destination: destination) {
            HStack(spacing: 10) {
                leading()
                Text(label)
                    .font(TrailFont.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: icon)
                    .font(TrailFont.meta)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private func divider() -> some View {
        Divider().padding(.leading, 14)
    }

    // MARK: - Grace Period Banner

    @ViewBuilder
    private var gracePeriodBanner: some View {
        if let daysLeft = patreon.gracePeriodDaysRemaining {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 20))
                    .frame(width: 43, height: 43)
                    .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your access expires in \(daysLeft) day\(daysLeft == 1 ? "" : "s")")
                        .font(TrailFont.body)
                    Link("Resubscribe on Patreon ↗", destination: BrandKit.patreonURL)
                        .font(TrailFont.data)
                        .foregroundStyle(.yellow)
                }
                Spacer()
            }
            .padding(14)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.yellow.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        }
    }

    // MARK: - Patreon

    @ViewBuilder
    private var patreonSection: some View {
        @Bindable var patreon = patreon
        Toggle(isOn: $patreon.isRequired) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Require Patreon").font(TrailFont.body)
                Text("Gate the app behind a SWAP $5+ membership")
                    .font(TrailFont.meta)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(Color.trailGreen)
        .padding(.horizontal, 14).padding(.vertical, 12)

        if patreon.isConnected {
            divider()
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(Color.trailGreen)
                        .font(.system(size: 16))
                    Text("SWAP Patreon").font(TrailFont.body)
                }
                Spacer()
                Text("Connected").font(TrailFont.data).foregroundStyle(.green)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)

            if let lastVerified = patreon.lastVerifiedAt {
                divider()
                infoRow("Last verified", lastVerified.formatted(.relative(presentation: .named)))
            }

            divider()
            buttonRow("Disconnect Patreon", color: .red) { showingDisconnectPatreon = true }
                .alert("Disconnect Patreon?", isPresented: $showingDisconnectPatreon) {
                    Button("Cancel", role: .cancel) {}
                    Button("Disconnect", role: .destructive) { patreon.disconnect() }
                } message: {
                    Text("You'll lose access to SWAP training plans.")
                }
        } else {
            divider()
            buttonRow("Connect Patreon", icon: "star.circle.fill", color: Color.trailGreen) { connectPatreon() }
        }
    }

    // MARK: - Patreon Debug
    //
    // Visible only on Debug builds (or Release with DEV_SIGNIN_ALLOWED=YES).
    // Surfaces the entitlement state during a live demo to David & Megan and
    // gives a one-tap "force re-verify" that hits the Patreon identity API.

    @ViewBuilder
    private var patreonDebugSection: some View {
        infoRow("Connected", patreon.isConnected ? "yes" : "no")
        divider()
        infoRow("isPatron", patreon.isPatron ? "yes" : "no")
        divider()
        infoRow(
            "Last verified",
            patreon.lastVerifiedAt?.formatted(.relative(presentation: .named)) ?? "never"
        )
        divider()
        infoRow(
            "Token expires",
            patreon.tokenExpiresAt.map { $0.formatted(.relative(presentation: .named)) } ?? "—"
        )
        divider()
        infoRow(
            "Grace period",
            patreon.gracePeriodDaysRemaining.map { "\($0)d remaining" } ?? "—"
        )
        divider()
        Button { forceReverify() } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.trailGreen)
                    .frame(width: 24)
                Text("Force re-verify").font(TrailFont.body)
                Spacer()
                if patreon.isVerifying { ProgressView() }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(!patreon.isConnected || patreon.isVerifying)

        divider()
        buttonRow("Show Patreon Gate", icon: "rectangle.on.rectangle", color: Color.trailGreen) {
            showingPatreonGatePreview = true
        }
        .sheet(isPresented: $showingPatreonGatePreview) { PatreonGateView() }
    }

    private func forceReverify() {
        Task {
            do { try await patreon.verifyMembership() }
            catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    // MARK: - Strava

    @ViewBuilder
    private var stravaSection: some View {
        if strava.isConnected {
            HStack {
                Image("PoweredByStrava")
                    .resizable().aspectRatio(contentMode: .fit).frame(height: 16)
                Spacer()
                Text("Connected").font(TrailFont.data).foregroundStyle(.green)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)

            if let name = strava.athleteName {
                divider()
                infoRowText("Athlete", name)
            }
            if let lastSync = strava.lastSyncDate {
                divider()
                infoRow("Last sync", lastSync.formatted(.relative(presentation: .named)))
            }
            divider()
            Button { syncStrava() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.trailGreen)
                        .frame(width: 24)
                    Text("Sync Activities").font(TrailFont.body)
                    Spacer()
                    if strava.isSyncing { ProgressView() }
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .disabled(strava.isSyncing)

            divider()
            buttonRow("Disconnect Strava", color: .red) { showingDisconnectStrava = true }
                .alert("Disconnect Strava?", isPresented: $showingDisconnectStrava) {
                    Button("Cancel", role: .cancel) {}
                    Button("Disconnect", role: .destructive) { Task { await strava.disconnect() } }
                } message: {
                    Text("Your synced activities will be removed from the app.")
                }
        } else {
            Button { connectStrava() } label: {
                Image("ConnectWithStrava")
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Oura

    @ViewBuilder
    private var ouraSection: some View {
        if oura.isConnected {
            HStack {
                Image("OuraLogo")
                    .resizable().aspectRatio(contentMode: .fit).frame(height: 14)
                Spacer()
                Text("Connected").font(TrailFont.data).foregroundStyle(.green)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)

            if let lastSync = oura.lastSyncDate {
                divider()
                infoRow("Last sync", lastSync.formatted(.relative(presentation: .named)))
            }
            divider()
            Button { syncOura() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.trailGreen)
                        .frame(width: 24)
                    Text("Sync Recovery Data").font(TrailFont.body)
                    Spacer()
                    if oura.isSyncing { ProgressView() }
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .disabled(oura.isSyncing)

            divider()
            buttonRow("Disconnect Oura", color: .red) { showingDisconnectOura = true }
                .alert("Disconnect Oura?", isPresented: $showingDisconnectOura) {
                    Button("Cancel", role: .cancel) {}
                    Button("Disconnect", role: .destructive) { oura.disconnect() }
                } message: {
                    Text("Your recovery data will no longer sync.")
                }
        } else {
            Button { connectOura() } label: {
                HStack(spacing: 10) {
                    Image("OuraLogo").resizable().aspectRatio(contentMode: .fit).frame(height: 14)
                    Text("Connect").font(TrailFont.body).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(TrailFont.meta)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Plan

    @ViewBuilder
    private var planSection: some View {
        if planStore.hasPlan {
            if let plan = planStore.activePlan {
                infoRowText("Plan", plan.name)
                divider()
                infoRow("Race Date", plan.raceDate.formatted(date: .abbreviated, time: .omitted))
                divider()
                infoRow("Sessions", "\(planStore.sessions.count)")
                divider()
            }
            buttonRow("Delete Plan", color: .red) { showingDeletePlan = true }
                .alert("Delete Training Plan?", isPresented: $showingDeletePlan) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) { planStore.clearPlan() }
                } message: {
                    Text("This will permanently delete your plan and all associated swaps and skips.")
                }
        } else {
            HStack {
                Text("No active plan")
                    .font(TrailFont.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        buttonRow("Sign Out", color: .red) { showingSignOutAlert = true }
            .alert("Sign Out?", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) { Task { try? await auth.signOut() } }
            } message: {
                Text("You'll need to sign in again to access your training data.")
            }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(spacing: 0) {
            infoRow("Version", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.9")
            divider()
            linkRow("Privacy Policy", destination: URL(string: "https://johnnylikestraining.com/privacy.html")!) { EmptyView() }
            divider()
            linkRow("Terms of Service", destination: URL(string: "https://johnnylikestraining.com/terms.html")!) { EmptyView() }
            divider()
            linkRow("Support", icon: "envelope", destination: URL(string: "mailto:atler.j@me.com")!) { EmptyView() }
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
