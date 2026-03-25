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
        .animation(.easeInOut, value: auth.isAuthenticated)
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

    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }

            WeekView()
                .tabItem {
                    Label("Week", systemImage: "calendar")
                }

            StrengthTemplateView()
                .tabItem {
                    Label("Strength", systemImage: "dumbbell.fill")
                }

            ProgressDashboardView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .task {
            guard let userId = auth.currentUserId else { return }
            if !planStore.hasPlan {
                await planStore.loadPlan(userId: userId)
            }
            if let plan = planStore.activePlan {
                if !strengthStore.hasTemplate {
                    await strengthStore.loadData(planId: plan.id)
                }
                if !heatStore.hasSessions {
                    await heatStore.loadData(planId: plan.id)
                }
                if !stretchStore.hasTemplate {
                    await stretchStore.loadData(planId: plan.id)
                }
                if let week = planStore.currentWeekNumber {
                    strengthStore.computeSuggestions(
                        runningSessions: planStore.sessions,
                        ouraData: oura.dailyData,
                        currentWeek: week
                    )
                }
            }
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
