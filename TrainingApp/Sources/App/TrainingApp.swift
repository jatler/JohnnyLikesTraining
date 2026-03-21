import SwiftUI

@main
struct TrainingApp: App {
    @State private var authService = AuthService()
    @State private var planStore = TrainingPlanStore()
    @State private var stravaService = StravaService()
    @State private var ouraService = OuraService()
    @State private var strengthStore = StrengthStore()
    @State private var heatStore = HeatStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(planStore)
                .environment(stravaService)
                .environment(ouraService)
                .environment(strengthStore)
                .environment(heatStore)
        }
    }
}
