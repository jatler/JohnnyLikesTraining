import XCTest
@testable import Training

final class ProgressionEngineTests: XCTestCase {

    private func makeExercise(
        sets: Int = 3,
        reps: Int = 10,
        weightKg: Double? = 20.0,
        isBodyweight: Bool = false
    ) -> StrengthTemplateExercise {
        StrengthTemplateExercise(
            id: UUID(),
            templateId: UUID(),
            dayOfWeek: 1,
            exerciseName: "Test Exercise",
            targetSets: sets,
            targetReps: reps,
            targetWeightKg: weightKg,
            targetRpe: nil,
            isBodyweight: isBodyweight,
            isTimed: false,
            sortOrder: 1,
            notes: nil
        )
    }

    private func makeLog(reps: Int, sessionId: UUID = UUID()) -> StrengthLog {
        StrengthLog(
            id: UUID(),
            sessionId: sessionId,
            setNumber: 1,
            actualReps: reps,
            actualWeightKg: 20.0,
            rpe: nil,
            completedAt: Date(),
            notes: nil
        )
    }

    private func makeOuraDaily(readinessScore: Int) -> OuraDaily {
        OuraDaily(
            id: UUID(),
            userId: UUID(),
            date: Date(),
            readinessScore: readinessScore,
            sleepScore: nil,
            hrvAverage: nil,
            restingHr: nil,
            temperatureDeviation: nil,
            syncedAt: Date()
        )
    }

    // MARK: - Deload Detection

    func testDeloadWeekDetection() {
        XCTAssertFalse(ProgressionEngine.isDeloadWeek(1))
        XCTAssertFalse(ProgressionEngine.isDeloadWeek(2))
        XCTAssertFalse(ProgressionEngine.isDeloadWeek(3))
        XCTAssertTrue(ProgressionEngine.isDeloadWeek(4))
        XCTAssertFalse(ProgressionEngine.isDeloadWeek(5))
        XCTAssertTrue(ProgressionEngine.isDeloadWeek(8))
        XCTAssertTrue(ProgressionEngine.isDeloadWeek(12))
        XCTAssertFalse(ProgressionEngine.isDeloadWeek(0))
    }

    func testDeloadWeekCustomFrequency() {
        let config = ProgressionEngine.Config(deloadFrequency: 3)
        XCTAssertFalse(ProgressionEngine.isDeloadWeek(1, config: config))
        XCTAssertTrue(ProgressionEngine.isDeloadWeek(3, config: config))
        XCTAssertTrue(ProgressionEngine.isDeloadWeek(6, config: config))
    }

    // MARK: - Deload Suggestion on Deload Week

    func testDeloadWeekSuggestion() {
        let exercise = makeExercise(sets: 3, reps: 10, weightKg: 20.0)

        let suggestion = ProgressionEngine.suggest(
            for: exercise,
            logs: [],
            weeklyRunDistanceKm: 40,
            recentReadiness: [],
            currentWeek: 4
        )

        XCTAssertNotNil(suggestion)
        XCTAssertTrue(suggestion!.reason.contains("Deload"))
        XCTAssertLessThan(suggestion!.suggestedSets, exercise.targetSets)
    }

    // MARK: - Weight Suggestions

    func testRepIncreaseWhenAllRepsHit() {
        let exercise = makeExercise(sets: 3, reps: 10, weightKg: 20.0)
        let logs = [makeLog(reps: 10), makeLog(reps: 10), makeLog(reps: 12)]

        let suggestion = ProgressionEngine.suggest(
            for: exercise,
            logs: logs,
            weeklyRunDistanceKm: 40,
            recentReadiness: [],
            currentWeek: 3
        )

        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion!.suggestedReps, 12) // 10 + 2
    }

    func testWeightIncreaseAtTopOfRepRange() {
        let config = ProgressionEngine.Config(repRangeTop: 12)
        let exercise = makeExercise(sets: 3, reps: 12, weightKg: 20.0)
        let logs = [makeLog(reps: 12), makeLog(reps: 12)]

        let suggestion = ProgressionEngine.suggest(
            for: exercise,
            logs: logs,
            weeklyRunDistanceKm: 40,
            recentReadiness: [],
            currentWeek: 3,
            config: config
        )

        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion!.suggestedWeightKg, 22.5) // 20 + 2.5
        XCTAssertEqual(suggestion!.suggestedReps, 8) // reset to bottom
    }

    func testNoSuggestionWhenRepsNotHit() {
        let exercise = makeExercise(sets: 3, reps: 10)
        let logs = [makeLog(reps: 8), makeLog(reps: 10)] // didn't hit all reps

        let suggestion = ProgressionEngine.suggest(
            for: exercise,
            logs: logs,
            weeklyRunDistanceKm: 40,
            recentReadiness: [],
            currentWeek: 3
        )

        XCTAssertNil(suggestion)
    }

    func testNoSuggestionWithNoLogs() {
        let exercise = makeExercise()

        let suggestion = ProgressionEngine.suggest(
            for: exercise,
            logs: [],
            weeklyRunDistanceKm: 40,
            recentReadiness: [],
            currentWeek: 3
        )

        XCTAssertNil(suggestion)
    }

    // MARK: - Low Readiness

    func testLowReadinessMaintainsLoad() {
        let exercise = makeExercise()
        let readiness = [makeOuraDaily(readinessScore: 45), makeOuraDaily(readinessScore: 50)]

        let suggestion = ProgressionEngine.suggest(
            for: exercise,
            logs: [],
            weeklyRunDistanceKm: 40,
            recentReadiness: readiness,
            currentWeek: 3
        )

        XCTAssertNotNil(suggestion)
        XCTAssertTrue(suggestion!.reason.contains("Recovery low"))
        XCTAssertEqual(suggestion!.suggestedSets, exercise.targetSets)
        XCTAssertEqual(suggestion!.suggestedReps, exercise.targetReps)
    }

    // MARK: - High Mileage

    func testHighMileageReducesSets() {
        let exercise = makeExercise(sets: 4)

        let suggestion = ProgressionEngine.suggest(
            for: exercise,
            logs: [],
            weeklyRunDistanceKm: 90, // above 80km threshold
            recentReadiness: [],
            currentWeek: 3
        )

        XCTAssertNotNil(suggestion)
        XCTAssertTrue(suggestion!.reason.contains("High running volume"))
        XCTAssertLessThan(suggestion!.suggestedSets, exercise.targetSets)
    }

    // MARK: - Apply Deload

    func testApplyDeload() {
        let result = ProgressionEngine.applyDeload(sets: 4, reps: 10, weightKg: 30.0)

        XCTAssertLessThan(result.sets, 4)
        XCTAssertEqual(result.reps, 10) // reps unchanged
        XCTAssertEqual(result.weightKg, 30.0) // weight unchanged
    }

    // MARK: - Weekly Run Distance

    func testWeeklyRunDistance() {
        let sessions = [
            PlannedSession(
                id: UUID(), planId: UUID(), weekNumber: 1, dayOfWeek: 1,
                scheduledDate: Date(), workoutType: .easy,
                targetDistanceKm: 8.0, targetPaceDescription: nil,
                notes: nil, sortOrder: 1
            ),
            PlannedSession(
                id: UUID(), planId: UUID(), weekNumber: 1, dayOfWeek: 3,
                scheduledDate: Date(), workoutType: .tempo,
                targetDistanceKm: 10.0, targetPaceDescription: nil,
                notes: nil, sortOrder: 2
            ),
            PlannedSession(
                id: UUID(), planId: UUID(), weekNumber: 2, dayOfWeek: 1,
                scheduledDate: Date(), workoutType: .easy,
                targetDistanceKm: 8.0, targetPaceDescription: nil,
                notes: nil, sortOrder: 3
            ),
        ]

        let week1Total = ProgressionEngine.weeklyRunDistance(sessions: sessions, weekNumber: 1)
        XCTAssertEqual(week1Total, 18.0, accuracy: 0.01)

        let week2Total = ProgressionEngine.weeklyRunDistance(sessions: sessions, weekNumber: 2)
        XCTAssertEqual(week2Total, 8.0, accuracy: 0.01)
    }

    // MARK: - Distance Formatter

    func testDistanceFormatter() {
        let mi = DistanceFormatter.miles(from: 10.0)
        XCTAssertEqual(mi, 6.21371, accuracy: 0.001)

        let formatted = DistanceFormatter.formatted(km: 10.0)
        XCTAssertTrue(formatted.contains("mi"))
        XCTAssertTrue(formatted.contains("6.2"))
    }
}
