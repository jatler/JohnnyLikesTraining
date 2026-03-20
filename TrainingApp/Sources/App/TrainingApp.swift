import SwiftUI

@main
struct TrainingApp: App {
    @State private var authService = AuthService()
    @State private var planStore = TrainingPlanStore()
    @State private var stravaService = StravaService()
    @State private var ouraService = OuraService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(planStore)
                .environment(stravaService)
                .environment(ouraService)
        }
    }
}
