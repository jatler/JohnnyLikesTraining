import XCTest
@testable import Training

final class ProgressionEngineTests: XCTestCase {

    // ProgressionEngine has been removed. Strength workouts are now
    // sourced directly from coach notes in the training plan.

    // MARK: - Distance Formatter (preserved)

    func testDistanceFormatter() {
        let mi = DistanceFormatter.miles(from: 10.0)
        XCTAssertEqual(mi, 6.21371, accuracy: 0.001)

        let formatted = DistanceFormatter.formatted(km: 10.0)
        XCTAssertTrue(formatted.contains("mi"))
        XCTAssertTrue(formatted.contains("6.2"))
    }
}
