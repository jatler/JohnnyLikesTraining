import XCTest
@testable import Training

/// Regression test for the bug where marking a heat session complete on one
/// week's Monday lit up every Monday across the plan.
///
/// Root cause was in StrengthTemplateView.heatRows(for:): it iterated
/// heatDaysFromSessions() (deduped to one row per dayOfWeek) and used that
/// canonical session.id for completion lookups on every week's page. The fix
/// resolves a week-specific session via
/// `heatStore.sessions.first { $0.weekNumber == week && $0.dayOfWeek == day }`
/// before reading isComplete / logging / tapping. This test pins that primitive.
@MainActor
final class HeatPerWeekTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Skip Supabase writes triggered by initializeFromTemplate/logSession.
        SupabaseService.shared.isOffline = true
    }

    func testEachWeekHasItsOwnSessionId() {
        let store = HeatStore()
        let planId = UUID()
        let startDate = Calendar.current.startOfDay(for: Date())

        store.initializeFromTemplate(
            [HeatSessionTemplate(day: 1, sessionType: "sauna", targetDurationMinutes: 25, notes: nil)],
            planId: planId,
            planStartDate: startDate,
            totalWeeks: 4
        )

        XCTAssertEqual(store.sessions.count, 4, "Expected one Monday session per week.")
        let ids = Set(store.sessions.map(\.id))
        XCTAssertEqual(ids.count, 4, "Each weekly Monday session must have a distinct UUID.")
    }

    func testLoggingOneWeekDoesNotMarkOtherWeeksComplete() {
        let store = HeatStore()
        let planId = UUID()
        let startDate = Calendar.current.startOfDay(for: Date())

        store.initializeFromTemplate(
            [HeatSessionTemplate(day: 1, sessionType: "sauna", targetDurationMinutes: 25, notes: nil)],
            planId: planId,
            planStartDate: startDate,
            totalWeeks: 4
        )

        let week2Monday = store.sessions.first { $0.weekNumber == 2 && $0.dayOfWeek == 1 }
        let week3Monday = store.sessions.first { $0.weekNumber == 3 && $0.dayOfWeek == 1 }
        XCTAssertNotNil(week2Monday)
        XCTAssertNotNil(week3Monday)
        XCTAssertNotEqual(week2Monday!.id, week3Monday!.id)

        store.logSession(
            sessionId: week2Monday!.id,
            durationMinutes: 25,
            sessionType: .sauna,
            notes: nil
        )

        XCTAssertTrue(store.isComplete(week2Monday!.id),
                      "Logged week must be complete.")
        XCTAssertFalse(store.isComplete(week3Monday!.id),
                       "Logging week 2 must not mark week 3 complete — the original bug.")
    }
}
