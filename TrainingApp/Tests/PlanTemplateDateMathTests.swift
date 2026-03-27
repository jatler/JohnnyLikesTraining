import XCTest
@testable import Training

final class PlanTemplateDateMathTests: XCTestCase {

    private func makeTemplate(durationWeeks: Int) -> TrainingPlanTemplate {
        TrainingPlanTemplate(
            id: "test",
            name: "Test Plan",
            author: "Test",
            source: "SWAP Running",
            description: "Test",
            durationWeeks: durationWeeks,
            targetDistances: ["50K"],
            sessions: [
                SessionTemplate(week: 1, day: 1, workoutType: .easy, targetDistanceKm: 8.0, paceDescription: nil, notes: nil),
                SessionTemplate(week: 1, day: 3, workoutType: .tempo, targetDistanceKm: 10.0, paceDescription: "tempo", notes: nil),
                SessionTemplate(week: 1, day: 6, workoutType: .longRun, targetDistanceKm: 20.0, paceDescription: nil, notes: nil),
            ],
            strengthExercises: nil,
            heatSessions: nil,
            stretchExercises: nil
        )
    }

    func testRaceDateToStartDate() {
        let template = makeTemplate(durationWeeks: 16)
        let calendar = Calendar.current

        // Race on Saturday, June 6, 2026
        let raceDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 6))!

        let result = PlanTemplateService.shared.generatePlan(
            from: template,
            userId: UUID(),
            raceName: "Test Race",
            raceDate: raceDate
        )

        // Plan start should be (16-1)*7 + 5 = 110 days before race
        let daysBefore = (template.durationWeeks - 1) * 7 + 5
        let expectedStart = calendar.date(byAdding: .day, value: -daysBefore, to: raceDate)!

        XCTAssertEqual(
            calendar.startOfDay(for: result.plan.planStartDate),
            calendar.startOfDay(for: expectedStart)
        )
    }

    func testSessionDateMapping() {
        let template = makeTemplate(durationWeeks: 4)
        let calendar = Calendar.current
        let raceDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 6))!

        let result = PlanTemplateService.shared.generatePlan(
            from: template,
            userId: UUID(),
            raceName: "Test Race",
            raceDate: raceDate
        )

        let planStart = result.plan.planStartDate

        // Week 1, Day 1 should be planStart + 0 days
        let w1d1 = result.sessions.first { $0.weekNumber == 1 && $0.dayOfWeek == 1 }
        XCTAssertNotNil(w1d1)
        XCTAssertEqual(
            calendar.startOfDay(for: w1d1!.scheduledDate),
            calendar.startOfDay(for: planStart)
        )

        // Week 1, Day 3 should be planStart + 2 days
        let w1d3 = result.sessions.first { $0.weekNumber == 1 && $0.dayOfWeek == 3 }
        XCTAssertNotNil(w1d3)
        let expected = calendar.date(byAdding: .day, value: 2, to: planStart)!
        XCTAssertEqual(
            calendar.startOfDay(for: w1d3!.scheduledDate),
            calendar.startOfDay(for: expected)
        )
    }

    func testGeneratedSessionCount() {
        let template = makeTemplate(durationWeeks: 4)
        let calendar = Calendar.current
        let raceDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 6))!

        let result = PlanTemplateService.shared.generatePlan(
            from: template,
            userId: UUID(),
            raceName: "Test Race",
            raceDate: raceDate
        )

        // 3 sessions per template, but template only defines week 1 sessions
        XCTAssertEqual(result.sessions.count, 3)
    }

    func testPlanMetadata() {
        let template = makeTemplate(durationWeeks: 8)
        let calendar = Calendar.current
        let raceDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15))!
        let userId = UUID()

        let result = PlanTemplateService.shared.generatePlan(
            from: template,
            userId: userId,
            raceName: "Mountain Ultra",
            raceDate: raceDate
        )

        XCTAssertEqual(result.plan.name, "Mountain Ultra")
        XCTAssertEqual(result.plan.userId, userId)
        XCTAssertEqual(result.plan.sourceFileName, "test.json")
        XCTAssertEqual(
            calendar.startOfDay(for: result.plan.raceDate),
            calendar.startOfDay(for: raceDate)
        )
    }
}
