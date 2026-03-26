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
        }
    }
}
