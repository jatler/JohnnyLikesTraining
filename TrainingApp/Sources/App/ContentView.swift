import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView("Loading\u{2026}")
            } else if auth.isAuthenticated {
                MainTabView()
            } else {
                SignInView()
            }
        }
        .animation(.easeOut(duration: 0.3), value: auth.isAuthenticated)
    }
}

struct MainTabView: View {
    @Environment(AuthService.self) private var auth
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(OuraService.self) private var oura
    @Environment(PatreonService.self) private var patreon
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(StretchStore.self) private var stretchStore

    /// True while a non-patron, non-grace, non-dev-bypass user is using the app.
    /// Gate stays presented until `isPatron` flips true (or grace period starts).
    private var shouldShowPatreonGate: Bool {
        !patreon.isPatron
            && patreon.gracePeriodDaysRemaining == nil
            && !DevSignIn.isAllowed
    }

    var body: some View {
        TabView {
            WeekView()
                .tabItem {
                    Label("Week", systemImage: "calendar")
                }

            ProgressDashboardView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }

            StrengthTemplateView()
                .tabItem {
                    Label("Strength", systemImage: "dumbbell.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(Color.trailGreen)
        .sheet(isPresented: Binding(
            get: { shouldShowPatreonGate },
            // Drag-to-dismiss is a no-op: the gate stays visible until the
            // user becomes a patron (or hits the grace window). The sheet
            // re-evaluates against `shouldShowPatreonGate` on every state
            // change, so SwiftUI handles the actual dismissal automatically.
            set: { _ in }
        )) {
            PatreonGateView()
        }
        .task {
            guard let userId = auth.currentUserId else { return }

            // Refresh patron status if the cached verification is older than
            // 7 days. Without this the gate would never re-evaluate after a
            // membership lapse until the user manually disconnected.
            if patreon.isConnected {
                try? await patreon.verifyMembershipIfStale()
            }

            if !planStore.hasPlan {
                await planStore.loadPlan(userId: userId)
            }

            // Load from local cache first for instant display
            strengthStore.loadFromCache()
            heatStore.loadFromCache()
            stretchStore.loadFromCache()
            strava.loadFromCache()
            oura.loadFromCache()

            // Then refresh from Supabase in background
            if let plan = planStore.activePlan {
                async let strengthLoad: () = {
                    await strengthStore.loadData(planId: plan.id)
                }()
                async let heatLoad: () = {
                    await heatStore.loadData(planId: plan.id)
                }()
                async let stretchLoad: () = {
                    await stretchStore.loadData(planId: plan.id)
                }()
                async let stravaLoad: () = {
                    if strava.isConnected {
                        await strava.loadActivities(userId: userId)
                    }
                }()
                async let ouraLoad: () = {
                    if oura.isConnected {
                        await oura.loadDailyData(userId: userId)
                    }
                }()

                _ = await (strengthLoad, heatLoad, stretchLoad, stravaLoad, ouraLoad)

                // If stores are still empty after loading from Supabase,
                // re-initialize from the bundled template (handles plans created
                // before strength/heat/stretch were added to the template).
                // Skip if offline — don't create duplicates that conflict on reconnect.
                if !SupabaseService.shared.isOffline {
                    if !strengthStore.hasSessions {
                        strengthStore.initializeFromPlannedSessions(
                            planStore.sessions,
                            planId: plan.id
                        )
                    }
                }
                if !SupabaseService.shared.isOffline, let template = planStore.currentTemplate {
                    if !heatStore.hasSessions,
                       let heatTemplates = template.heatSessions, !heatTemplates.isEmpty {
                        heatStore.initializeFromTemplate(
                            heatTemplates,
                            planId: plan.id,
                            planStartDate: plan.planStartDate,
                            totalWeeks: template.durationWeeks
                        )
                    }
                    if !stretchStore.hasTemplate,
                       let stretchExercises = template.stretchExercises, !stretchExercises.isEmpty {
                        stretchStore.initializeFromTemplate(
                            stretchExercises,
                            planId: plan.id,
                            planStartDate: plan.planStartDate,
                            totalWeeks: template.durationWeeks
                        )
                    }
                }

                #if DEBUG
                print("Relaunch: strava.isConnected=\(strava.isConnected) activities=\(strava.activities.count) sessions=\(planStore.sessions.count)")
                #endif
                if strava.isConnected {
                    strava.autoMatchActivities(sessions: planStore.sessions)
                    #if DEBUG
                    let matched = strava.activities.filter { $0.matchedSessionId != nil }.count
                    print("Relaunch: matched \(matched)/\(strava.activities.count) activities")
                    #endif
                }
            } else {
                if strava.isConnected {
                    await strava.loadActivities(userId: userId)
                    strava.autoMatchActivities(sessions: planStore.sessions)
                }
                if oura.isConnected {
                    await oura.loadDailyData(userId: userId)
                }
            }
        }
    }
}

#Preview("Authenticated") {
    ContentView()
        .environment(AuthService())
        .environment(TrainingPlanStore())
        .environment(StravaService())
        .environment(OuraService())
        .environment(PatreonService())
        .environment(StrengthStore())
        .environment(HeatStore())
        .environment(StretchStore())
}
