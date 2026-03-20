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

            PlanCalendarView()
                .tabItem {
                    Label("Plan", systemImage: "calendar.badge.clock")
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
}
