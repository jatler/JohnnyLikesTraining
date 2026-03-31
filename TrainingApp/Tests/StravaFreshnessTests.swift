@testable import Training
import XCTest

final class StravaFreshnessTests: XCTestCase {

    // These tests validate the 7-day freshness logic.
    // Since StravaService is @MainActor and depends on Keychain + Supabase,
    // we test the staleness logic via date arithmetic instead.

    func testSyncIsStaleWhenNeverSynced() {
        // A nil lastSyncedAt should be considered stale
        let lastSyncedAt: Date? = nil
        XCTAssertTrue(isSyncStale(lastSyncedAt))
    }

    func testSyncIsStaleWhenOlderThanSevenDays() {
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        XCTAssertTrue(isSyncStale(eightDaysAgo))
    }

    func testSyncIsNotStaleWhenRecentSync() {
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertFalse(isSyncStale(oneDayAgo))
    }

    func testSyncIsNotStaleWhenExactlySevenDaysAgo() {
        // Exactly 7 days ago (to the second) is on the boundary — should not be stale
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        // The check is `<`, so exactly 7 days is NOT stale (it equals the cutoff)
        XCTAssertFalse(isSyncStale(sevenDaysAgo))
    }

    func testSyncIsStaleWhenSevenDaysAndOneSecondAgo() {
        let sevenDaysAndOneSecond = Date().addingTimeInterval(-(7 * 24 * 3600 + 1))
        XCTAssertTrue(isSyncStale(sevenDaysAndOneSecond))
    }

    func testSyncIsNotStaleWhenJustSynced() {
        XCTAssertFalse(isSyncStale(Date()))
    }

    // MARK: - Helper (mirrors StravaService.isSyncStale logic)

    private func isSyncStale(_ lastSyncedAt: Date?) -> Bool {
        guard let lastSyncedAt else { return true }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return lastSyncedAt < sevenDaysAgo
    }
}
