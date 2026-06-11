import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var auth
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StrengthStore.self) private var screenshotStrengthStore
    @Environment(HeatStore.self) private var screenshotHeatStore
    @Environment(StretchStore.self) private var screenshotStretchStore
    @Environment(StravaService.self) private var screenshotStrava

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
        .onAppear {
            #if DEBUG
            if ScreenshotMode.isEnabled {
                if !auth.isAuthenticated { auth.devSignIn() }
                if let userId = auth.currentUserId {
                    ScreenshotMode.seedPlan(
                        planStore: planStore,
                        strengthStore: screenshotStrengthStore,
                        heatStore: screenshotHeatStore,
                        stretchStore: screenshotStretchStore,
                        strava: screenshotStrava,
                        userId: userId
                    )
                }
            }
            #endif
        }
    }
}

struct MainTabView: View {
    @Environment(AuthService.self) private var auth
    @Environment(TrainingPlanStore.self) private var planStore
    @Environment(StravaService.self) private var strava
    @Environment(OuraService.self) private var oura
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(StretchStore.self) private var stretchStore

    @State private var selectedTab: AppTab = {
        #if DEBUG
        ScreenshotMode.isEnabled ? ScreenshotMode.initialTab : .week
        #else
        .week
        #endif
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            WeekView()
                .tabItem { Label("Week", systemImage: "calendar") }
                .tag(AppTab.week)

            ProgressDashboardView()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                .tag(AppTab.progress)

            StrengthTemplateView()
                .tabItem { Label("Strength", systemImage: "dumbbell.fill") }
                .tag(AppTab.strength)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(Color.trailGreen)
        .task {
            // Local caches FIRST, before any network. The plan, the synced
            // activities (with their saved session matches), and every store's
            // last-known state are already on disk — rendering them must not
            // wait on the auth round-trip or the Supabase plan fetch, or the
            // Week tab sits without its completion checks for seconds on a
            // cold start.
            planStore.loadCachedPlan()
            strengthStore.loadFromCache()
            heatStore.loadFromCache()
            stretchStore.loadFromCache()
            strava.loadFromCache()
            oura.loadFromCache()
            if strava.isConnected {
                // Cached activities carry matchedSessionId from the last run,
                // but re-validate against cached sessions so stale matches
                // don't flash.
                strava.autoMatchActivities(sessions: planStore.sessions)
            }

            // Refresh the Supabase session before any per-store network load.
            // The SDK emits the persisted session as "current" at startup even
            // when the access token is past expiry; without this refresh,
            // every subsequent write 401s and surfaces as "Failed to save X."
            await auth.refreshIfNeeded()

            guard let userId = auth.currentUserId else { return }

            // Reconcile the cached plan with Supabase (swaps, skips, overrides
            // may have changed on another device). The cache is already on
            // screen, so this await no longer blocks first render.
            await planStore.loadPlan(userId: userId)

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
        .environment(StrengthStore())
        .environment(HeatStore())
        .environment(StretchStore())
}
