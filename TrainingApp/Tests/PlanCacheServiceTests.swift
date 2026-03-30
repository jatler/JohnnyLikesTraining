import XCTest
@testable import Training

final class PlanCacheServiceTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        PlanCacheService.clear()
    }

    func testSaveAndLoadRoundtrip() {
        let plan = TrainingPlan(
            id: UUID(),
            userId: UUID(),
            name: "Test Plan",
            raceDate: Date(),
            planStartDate: Date(),
            templateId: "test",
            createdAt: Date()
        )
        let session = PlannedSession(
            id: UUID(),
            planId: plan.id,
            scheduledDate: Date(),
            weekNumber: 1,
            dayOfWeek: 1,
            sortOrder: 1,
            workoutType: .easy,
            targetDistanceKm: 10.0,
            targetPaceDescription: "Easy effort",
            notes: "Test notes"
        )

        PlanCacheService.save(plan: plan, sessions: [session])

        let cached = PlanCacheService.loadCached()
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.plan.id, plan.id)
        XCTAssertEqual(cached?.plan.name, "Test Plan")
        XCTAssertEqual(cached?.sessions.count, 1)
        XCTAssertEqual(cached?.sessions.first?.id, session.id)
    }

    func testClearRemovesCachedData() {
        let plan = TrainingPlan(
            id: UUID(),
            userId: UUID(),
            name: "Clear Test",
            raceDate: Date(),
            planStartDate: Date(),
            templateId: "test",
            createdAt: Date()
        )
        PlanCacheService.save(plan: plan, sessions: [])
        XCTAssertNotNil(PlanCacheService.loadCached())

        PlanCacheService.clear()
        XCTAssertNil(PlanCacheService.loadCached())
    }

    func testLoadReturnsNilWhenNoCache() {
        PlanCacheService.clear()
        XCTAssertNil(PlanCacheService.loadCached())
    }

    func testSkipsSwapsOverridesRoundtrip() {
        let planId = UUID()
        let sessionId = UUID()
        let plan = TrainingPlan(
            id: planId,
            userId: UUID(),
            name: "Cache Test",
            raceDate: Date(),
            planStartDate: Date(),
            templateId: "test",
            createdAt: Date()
        )

        let skip = SessionSkip(
            id: UUID(),
            sessionId: sessionId,
            reason: "Injury",
            skippedAt: Date()
        )

        PlanCacheService.save(plan: plan, sessions: [], skips: [skip], swaps: [], overrides: [])

        let cached = PlanCacheService.loadCached()
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.skips.count, 1)
        XCTAssertEqual(cached?.skips.first?.sessionId, sessionId)
        XCTAssertEqual(cached?.skips.first?.reason, "Injury")
        XCTAssertEqual(cached?.swaps.count, 0)
        XCTAssertEqual(cached?.overrides.count, 0)
    }
}
