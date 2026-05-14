import SwiftUI

@main
struct TrainingApp: App {
    @State private var authService = AuthService()
    @State private var planStore = TrainingPlanStore()
    @State private var stravaService = StravaService()
    @State private var ouraService = OuraService()
    @State private var patreonService = PatreonService()
    @State private var strengthStore = StrengthStore()
    @State private var heatStore = HeatStore()
    @State private var stretchStore = StretchStore()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Route 401/403 from any Supabase write back into AuthService.
        // SupabaseService can't import AuthService directly without a cycle,
        // so we wire the callback at the top of the dependency graph.
        // We try to recover by refreshing the session; if that fails the
        // user is bounced to SignInView (refreshIfNeeded flips isAuthenticated).
        let auth = AuthService()
        SupabaseService.shared.onAuthFailure = { [weak auth] in
            Task { @MainActor in
                await auth?.refreshIfNeeded()
            }
        }
        _authService = State(initialValue: auth)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(planStore)
                .environment(stravaService)
                .environment(ouraService)
                .environment(patreonService)
                .environment(strengthStore)
                .environment(heatStore)
                .environment(stretchStore)
                .onChange(of: scenePhase) { _, phase in
                    // Refresh the Supabase session whenever the app returns to
                    // the foreground. Without this, a user who backgrounds the
                    // app overnight comes back to a stale JWT and every write
                    // silently 401s.
                    if phase == .active {
                        Task { await authService.refreshIfNeeded() }
                    }
                }
        }
    }
}
