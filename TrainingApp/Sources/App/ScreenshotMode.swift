import Foundation
import SwiftUI

enum AppTab: String, Hashable {
    case week, progress, strength, settings
}

#if DEBUG

/// Launch-arg–driven helpers for generating App Store screenshots from a fresh
/// simulator. Only active in DEBUG builds when `-screenshotMode 1` is present.
///
/// Usage:
///   xcrun simctl launch booted com.jatler.Training \
///     -screenshotMode 1 -startTab week
///
/// Supported tabs: week, progress, strength, settings
enum ScreenshotMode {
    static var isEnabled: Bool {
        return UserDefaults.standard.integer(forKey: "screenshotMode") == 1
    }

    static var initialTab: AppTab {
        let name = UserDefaults.standard.string(forKey: "startTab") ?? "week"
        return AppTab(rawValue: name.lowercased()) ?? .week
    }

    /// Mid-training plan: starts 10 weeks before "today" so screenshots land
    /// on week 11 of the 16-week Champion Plan — peak training, plenty of
    /// completed and upcoming workouts in view. Also seeds strength/heat/stretch
    /// from the template (which the live app only does when online).
    @MainActor
    static func seedPlan(
        planStore: TrainingPlanStore,
        strengthStore: StrengthStore,
        heatStore: HeatStore,
        stretchStore: StretchStore,
        strava: StravaService,
        userId: UUID
    ) {
        guard let template = PlanTemplateService.shared.template(withId: "champion_100k") else {
            return
        }

        if !planStore.hasPlan {
            let today = Calendar.current.startOfDay(for: Date())
            let raceDate = Calendar.current.date(byAdding: .weekOfYear, value: 6, to: today) ?? today
            planStore.createPlan(
                raceName: "Tahoe Rim Trail 100K",
                raceDate: raceDate,
                template: template,
                userId: userId
            )
        }

        guard let plan = planStore.activePlan else { return }

        if !strengthStore.hasSessions {
            strengthStore.initializeFromPlannedSessions(planStore.sessions, planId: plan.id)
        }
        if !heatStore.hasSessions, let heat = template.heatSessions, !heat.isEmpty {
            heatStore.initializeFromTemplate(
                heat,
                planId: plan.id,
                planStartDate: plan.planStartDate,
                totalWeeks: template.durationWeeks
            )
        }
        if !stretchStore.hasTemplate, let stretches = template.stretchExercises, !stretches.isEmpty {
            stretchStore.initializeFromTemplate(
                stretches,
                planId: plan.id,
                planStartDate: plan.planStartDate,
                totalWeeks: template.durationWeeks
            )
        }

        // Synthesize "completed" Strava activities for past run sessions so the
        // Progress dashboard shows real bars and stats instead of an empty chart.
        if strava.activities.isEmpty {
            let today = Calendar.current.startOfDay(for: Date())
            let pastRunSessions = planStore.sessions.filter { s in
                s.scheduledDate < today &&
                    s.workoutType != .strength &&
                    s.workoutType != .rest &&
                    (s.targetDistanceKm ?? 0) > 0
            }
            let demoActivities: [StravaActivity] = pastRunSessions.map { session in
                let km = session.targetDistanceKm ?? 0
                let secondsPerKm: Double
                switch session.workoutType {
                case .tempo: secondsPerKm = 280
                case .intervals: secondsPerKm = 260
                case .longRun: secondsPerKm = 420
                case .recovery: secondsPerKm = 460
                default: secondsPerKm = 380
                }
                let movingSec = Int(km * secondsPerKm)
                return StravaActivity(
                    id: UUID(),
                    userId: userId,
                    stravaId: Int64.random(in: 10_000_000...99_999_999),
                    activityDate: session.scheduledDate,
                    startDateLocal: session.scheduledDate,
                    timeZoneIdentifier: TimeZone.current.identifier,
                    name: session.workoutType.rawValue.capitalized + " Run",
                    distanceKm: km,
                    movingTimeSeconds: movingSec,
                    elapsedTimeSeconds: movingSec + 60,
                    averagePacePerKm: secondsPerKm,
                    averageHr: 142,
                    elevationGainM: km * 8,
                    mapPolyline: nil,
                    activityType: "Run",
                    matchedSessionId: session.id,
                    syncedAt: Date()
                )
            }
            strava.applyDemoActivities(demoActivities)
        }
    }
}

#endif
