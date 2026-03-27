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
    @Environment(StrengthStore.self) private var strengthStore
    @Environment(HeatStore.self) private var heatStore
    @Environment(StretchStore.self) private var stretchStore

    @State private var dataLoaded = false

    var body: some View {
        TabView {
            Group {
                if dataLoaded || planStore.hasPlan {
                    TodayView()
                } else {
                    SkeletonLoadingView()
                }
            }
            .tabItem {
                Label("Today", systemImage: "sun.max.fill")
            }

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
        .tint(Color.swapAccent)
        .task {
            guard let userId = auth.currentUserId else { return }
            if !planStore.hasPlan {
                await planStore.loadPlan(userId: userId)
            }
            dataLoaded = true
            if let plan = planStore.activePlan {
                async let strengthLoad: () = {
                    if !strengthStore.hasTemplate {
                        await strengthStore.loadData(planId: plan.id)
                    }
                }()
                async let heatLoad: () = {
                    if !heatStore.hasSessions {
                        await heatStore.loadData(planId: plan.id)
                    }
                }()
                async let stretchLoad: () = {
                    if !stretchStore.hasTemplate {
                        await stretchStore.loadData(planId: plan.id)
                    }
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

                if strava.isConnected {
                    strava.autoMatchActivities(sessions: planStore.sessions)
                }
                if let week = planStore.currentWeekNumber {
                    strengthStore.computeSuggestions(
                        runningSessions: planStore.sessions,
                        ouraData: oura.dailyData,
                        currentWeek: week
                    )
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

private struct SkeletonLoadingView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Session card skeleton
                    skeletonCard(height: 160)

                    // Recovery card skeleton
                    skeletonCard(height: 80)

                    // Strength section skeleton
                    skeletonCard(height: 100)
                }
                .padding()
            }
            .navigationTitle("Today")
        }
    }

    private func skeletonCard(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemGray5))
            .frame(height: height)
            .shimmering()
    }
}

private extension View {
    func shimmering() -> some View {
        self
            .redacted(reason: .placeholder)
            .opacity(0.6)
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
