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
            sourceFileName: "test.json",
            createdAt: Date()
        )
        let session = PlannedSession(
            id: UUID(),
            planId: plan.id,
            weekNumber: 1,
            dayOfWeek: 1,
            scheduledDate: Date(),
            workoutType: .easy,
            targetDistanceKm: 10.0,
            targetPaceDescription: "Easy effort",
            notes: "Test notes",
            sortOrder: 1
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
            sourceFileName: "test.json",
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
            sourceFileName: "test.json",
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

    // MARK: - Pending swap queue
    //
    // The pending-swap queue is the durability fix for the "swap reverts on
    // restart" bug. A swap that hasn't yet been confirmed by Supabase must
    // survive a full app restart so it can be replayed before the next fetch.

    func testPendingSwapsRoundtrip() {
        let planId = UUID()
        let sessionAId = UUID()
        let sessionBId = UUID()

        let pending = PendingSwap(
            swap: SessionSwap(
                id: UUID(),
                planId: planId,
                sessionAId: sessionAId,
                sessionBId: sessionBId,
                reason: "Knee felt off",
                swappedAt: Date()
            ),
            sessionAUpdate: SessionFieldSnapshot(
                sessionId: sessionAId,
                workoutType: .easy,
                targetDistanceKm: 10.0,
                targetPaceDescription: "Easy effort",
                notes: "From swap"
            ),
            sessionBUpdate: SessionFieldSnapshot(
                sessionId: sessionBId,
                workoutType: .tempo,
                targetDistanceKm: 8.0,
                targetPaceDescription: "Tempo effort",
                notes: nil
            ),
            strengthMoves: [
                StrengthDateMove(
                    sessionId: UUID(),
                    scheduledDate: Date(),
                    dayOfWeek: 3
                )
            ]
        )

        PlanCacheService.savePendingSwaps([pending])

        let loaded = PlanCacheService.loadPendingSwaps()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.swap.sessionAId, sessionAId)
        XCTAssertEqual(loaded.first?.swap.sessionBId, sessionBId)
        XCTAssertEqual(loaded.first?.sessionAUpdate.workoutType, .easy)
        XCTAssertEqual(loaded.first?.sessionBUpdate.workoutType, .tempo)
        XCTAssertEqual(loaded.first?.sessionAUpdate.targetDistanceKm, 10.0)
        XCTAssertEqual(loaded.first?.strengthMoves.count, 1)
    }

    func testPendingSwapsLoadEmptyWhenNoFile() {
        PlanCacheService.clear()
        XCTAssertTrue(PlanCacheService.loadPendingSwaps().isEmpty)
    }

    func testClearAlsoClearsPendingSwaps() {
        let pending = PendingSwap(
            swap: SessionSwap(
                id: UUID(),
                planId: UUID(),
                sessionAId: UUID(),
                sessionBId: UUID(),
                reason: nil,
                swappedAt: Date()
            ),
            sessionAUpdate: SessionFieldSnapshot(
                sessionId: UUID(),
                workoutType: .easy,
                targetDistanceKm: nil,
                targetPaceDescription: nil,
                notes: nil
            ),
            sessionBUpdate: SessionFieldSnapshot(
                sessionId: UUID(),
                workoutType: .rest,
                targetDistanceKm: nil,
                targetPaceDescription: nil,
                notes: nil
            ),
            strengthMoves: []
        )
        PlanCacheService.savePendingSwaps([pending])
        XCTAssertEqual(PlanCacheService.loadPendingSwaps().count, 1)

        PlanCacheService.clear()
        XCTAssertTrue(PlanCacheService.loadPendingSwaps().isEmpty)
    }
}
