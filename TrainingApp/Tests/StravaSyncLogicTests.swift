import XCTest
@testable import Training

/// Regression tests for the pull-to-refresh sync logic that broke in 1.2.1:
/// the incremental cutoff window, merge-on-sync, and the merge-by-recency rule
/// that keeps a concurrent Supabase load from wiping freshly synced activities.
final class StravaSyncLogicTests: XCTestCase {

    // MARK: - Incremental cutoff

    func testCutoffIsNilWithoutPriorSync() {
        XCTAssertNil(StravaService.incrementalCutoff(lastSync: nil),
                     "No prior sync must fall back to the full window, not a bogus date")
    }

    func testCutoffTrails48HoursBehindLastSync() {
        let lastSync = Date(timeIntervalSince1970: 1_700_000_000)
        let cutoff = StravaService.incrementalCutoff(lastSync: lastSync)
        XCTAssertEqual(cutoff, lastSync.addingTimeInterval(-48 * 60 * 60))
    }

    func testCutoffNeverExcludesARunFinishedAfterLastSync() {
        // The exact 1.2.1 user scenario: sync, run the next day, pull again.
        let lastSync = Date().addingTimeInterval(-24 * 60 * 60)
        let runStart = Date().addingTimeInterval(-60 * 60)
        let cutoff = StravaService.incrementalCutoff(lastSync: lastSync)!
        XCTAssertLessThan(cutoff, runStart, "A new run must start after the cutoff or sync misses it")
    }

    // MARK: - merged(existing:incoming:)

    func testMergedReplacesSameStravaIdAndKeepsTheRest() {
        let old = activity(stravaId: 1, name: "Old", daysAgo: 3)
        let kept = activity(stravaId: 2, name: "Kept", daysAgo: 5)
        let updated = activity(stravaId: 1, name: "Updated", daysAgo: 3)

        let result = StravaService.merged(existing: [old, kept], incoming: [updated])

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first(where: { $0.stravaId == 1 })?.name, "Updated")
        XCTAssertEqual(result.first(where: { $0.stravaId == 2 })?.name, "Kept")
    }

    func testMergedSortsNewestFirst() {
        let result = StravaService.merged(
            existing: [activity(stravaId: 1, name: "older", daysAgo: 10)],
            incoming: [activity(stravaId: 2, name: "newer", daysAgo: 1)]
        )
        XCTAssertEqual(result.map(\.stravaId), [2, 1])
    }

    func testMergedToleratesDuplicateIdsWithoutCrashing() {
        let dupeA = activity(stravaId: 7, name: "a", daysAgo: 1)
        let dupeB = activity(stravaId: 7, name: "b", daysAgo: 1)
        let result = StravaService.merged(existing: [dupeA, dupeB], incoming: [])
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - mergedByRecency (Supabase load vs in-memory)

    func testStaleSupabaseLoadCannotWipeFreshlySyncedActivity() {
        // Pull-to-refresh fetched a run and its upsert is still in flight;
        // a concurrent loadActivities returns rows without it.
        let freshRun = activity(stravaId: 99, name: "Morning Run", daysAgo: 0, syncedSecondsAgo: 1)
        let oldRow = activity(stravaId: 1, name: "Last Week", daysAgo: 7, syncedSecondsAgo: 86_400)

        let result = StravaService.mergedByRecency(local: [freshRun, oldRow], remote: [oldRow])

        XCTAssertTrue(result.contains(where: { $0.stravaId == 99 }),
                      "A just-synced run must survive a concurrent stale Supabase load")
    }

    func testNewerRemoteRowWinsOverOlderLocalCopy() {
        var localCopy = activity(stravaId: 5, name: "Run", daysAgo: 1, syncedSecondsAgo: 3_600)
        localCopy.matchedSessionId = nil
        var remoteCopy = activity(stravaId: 5, name: "Run", daysAgo: 1, syncedSecondsAgo: 60)
        let match = UUID()
        remoteCopy.matchedSessionId = match

        let result = StravaService.mergedByRecency(local: [localCopy], remote: [remoteCopy])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].matchedSessionId, match)
    }

    // MARK: - autoMatchActivities crash regression

    /// 1.2.3 pull-to-refresh crash: autoMatchActivities built its session
    /// lookup with Dictionary(uniqueKeysWithValues:), which traps the moment
    /// planStore.sessions contains a duplicate row (cache-reconcile/swap-replay
    /// edge cases). It must tolerate duplicates and still match.
    @MainActor
    func testAutoMatchToleratesDuplicateSessionsWithoutCrashing() {
        let strava = StravaService()
        strava.applyDemoActivities([activity(stravaId: 1, name: "Run", daysAgo: 0, onLocalToday: true)])

        let session = plannedSession(on: Date())
        strava.autoMatchActivities(sessions: [session, session])

        XCTAssertEqual(strava.activities.first?.matchedSessionId, session.id,
                       "Duplicate sessions must dedupe, not trap, and the run still matches")
    }

    // MARK: - formattedPace trap safety

    func testFormattedPaceSurvivesPathologicalValues() {
        for pace: Double? in [nil, 0, -5, .infinity, .nan, 1e308] {
            var run = activity(stravaId: 1, name: "Run", daysAgo: 0)
            run.averagePacePerKm = pace
            XCTAssertEqual(run.formattedPace, "—",
                           "Pace \(String(describing: pace)) must render as a dash, not trap Int(_:)")
        }
    }

    func testFormattedPaceStillFormatsNormalValues() {
        var run = activity(stravaId: 1, name: "Run", daysAgo: 0)
        run.averagePacePerKm = 6.0 // 6:00 /km ≈ 9:39 /mi
        XCTAssertEqual(run.formattedPace, "9:39 /mi")
    }

    // MARK: - Helpers

    private func plannedSession(on date: Date) -> PlannedSession {
        PlannedSession(
            id: UUID(),
            planId: UUID(),
            weekNumber: 1,
            dayOfWeek: 1,
            scheduledDate: date,
            workoutType: .easy,
            targetDistanceKm: 10,
            targetPaceDescription: nil,
            notes: nil,
            sortOrder: 1
        )
    }

    /// Noon UTC carrying today's *local* (y, m, d): `isOnLocalDay` reads the
    /// activity's startDateLocal with a UTC calendar, so this matches a
    /// session scheduled "today" in every device timezone.
    private func utcNoonMatchingLocalToday() -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 12
        return utc.date(from: comps)!
    }

    private func activity(
        stravaId: Int64,
        name: String,
        daysAgo: Int,
        syncedSecondsAgo: TimeInterval = 0,
        onLocalToday: Bool = false
    ) -> StravaActivity {
        let date = onLocalToday
            ? utcNoonMatchingLocalToday()
            : Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return StravaActivity(
            id: UUID(),
            userId: UUID(),
            stravaId: stravaId,
            activityDate: date,
            startDateLocal: date,
            timeZoneIdentifier: TimeZone.current.identifier,
            name: name,
            distanceKm: 10,
            movingTimeSeconds: 3600,
            elapsedTimeSeconds: 3700,
            averagePacePerKm: 6,
            averageHr: 140,
            elevationGainM: 100,
            mapPolyline: nil,
            activityType: "Run",
            matchedSessionId: nil,
            syncedAt: Date().addingTimeInterval(-syncedSecondsAgo)
        )
    }
}
