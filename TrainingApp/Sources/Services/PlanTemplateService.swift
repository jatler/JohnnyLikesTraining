import Foundation

final class PlanTemplateService {

    static let shared = PlanTemplateService()

    private init() {}

    // MARK: - Available Templates

    /// All bundled plan templates the user can choose from.
    var availableTemplates: [TrainingPlanTemplate] {
        var templates: [TrainingPlanTemplate] = []
        if let champion = loadBundledTemplate(named: "champion_plan_100k") {
            templates.append(champion)
        }
        if let winter = loadBundledTemplate(named: "winter_plan_10w") {
            templates.append(winter)
        }
        return templates
    }

    // MARK: - Load from Bundle

    func loadBundledTemplate(named name: String) -> TrainingPlanTemplate? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            assertionFailure("Missing bundled template: \(name).json")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(TrainingPlanTemplate.self, from: data)
        } catch {
            assertionFailure("Failed to decode template \(name): \(error)")
            return nil
        }
    }

    // MARK: - Generate Plan from Template

    /// Creates a `TrainingPlan` and its `PlannedSession`s from a template,
    /// back-calculating the start date from the race date.
    func generatePlan(
        from template: TrainingPlanTemplate,
        userId: UUID,
        raceName: String,
        raceDate: Date
    ) -> (plan: TrainingPlan, sessions: [PlannedSession]) {

        let calendar = Calendar.current

        // Race day falls on Saturday of the final week.
        // Week N starts on Monday, so Saturday = Monday + 5.
        // Plan start (Week 1 Monday) = raceDate - ((durationWeeks - 1) * 7 + 5) days
        let daysBeforeRace = (template.durationWeeks - 1) * 7 + 5
        guard let planStart = calendar.date(byAdding: .day, value: -daysBeforeRace, to: raceDate) else {
            fatalError("Could not compute plan start date")
        }

        let planId = UUID()
        let now = Date()

        let plan = TrainingPlan(
            id: planId,
            userId: userId,
            name: raceName,
            raceDate: raceDate,
            planStartDate: planStart,
            sourceFileName: "\(template.id).json",
            createdAt: now
        )

        let sessions: [PlannedSession] = template.sessions.enumerated().map { index, session in
            let dayOffset = (session.week - 1) * 7 + (session.day - 1)
            let scheduledDate = calendar.date(byAdding: .day, value: dayOffset, to: planStart)!

            return PlannedSession(
                id: UUID(),
                planId: planId,
                weekNumber: session.week,
                dayOfWeek: session.day,
                scheduledDate: scheduledDate,
                workoutType: session.workoutType,
                targetDistanceKm: session.targetDistanceKm,
                targetPaceDescription: session.paceDescription,
                notes: session.notes,
                sortOrder: index + 1
            )
        }

        return (plan, sessions)
    }

}
