import XCTest

/// Regression coverage for WeekView pull-to-refresh. This gesture has broken
/// three separate times (lost in the TodayView redesign, swallowed by short
/// weeks without .scrollBounceBehavior(.always), and reported dead again after
/// the 1.2.1 perf pass), so it gets a real UI test: launch in screenshot mode,
/// drag the week list down, and verify WeekView.sync() actually ran via the
/// marker file the DEBUG build writes to the path we hand it.
final class PullToRefreshUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPullToRefreshTriggersSync() throws {
        let marker = NSTemporaryDirectory() + "ptr_sync_fired_\(UUID().uuidString).txt"

        let app = XCUIApplication()
        app.launchArguments = ["-screenshotMode", "1", "-startTab", "week"]
        // Simulator apps share the host filesystem, so the app process can
        // write straight to the runner's temp dir.
        app.launchEnvironment["PTR_SYNC_MARKER"] = marker
        app.launch()

        // Week list is inside a paging TabView; grab the visible page's scroll view.
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 10), "Week scroll view should appear")

        // A plain swipeDown() is too fast for UIRefreshControl to arm — use a
        // slow tracked drag from the top third of the list well past the
        // refresh threshold.
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.4))
        start.press(forDuration: 0.2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)

        // sync() writes the marker as its first statement; give it a moment.
        let deadline = Date().addingTimeInterval(10)
        var fired = false
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: marker) {
                fired = true
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        try? FileManager.default.removeItem(atPath: marker)
        XCTAssertTrue(fired, "Pull-to-refresh drag should invoke WeekView.sync() (marker file missing)")
    }
}
