import XCTest
@testable import Training

final class DistanceFormatterTests: XCTestCase {

    func testKmToMilesConversion() {
        // 1 km = 0.621371 mi
        let result = DistanceFormatter.miles(from: 1.0)
        XCTAssertEqual(result, 0.621371, accuracy: 0.0001)
    }

    func testMarathonDistance() {
        // Marathon = 42.195 km = 26.2188 mi
        let result = DistanceFormatter.miles(from: 42.195)
        XCTAssertEqual(result, 26.2188, accuracy: 0.01)
    }

    func testZeroDistance() {
        XCTAssertEqual(DistanceFormatter.miles(from: 0), 0)
    }

    func testFormattedOutput() {
        let result = DistanceFormatter.formatted(km: 16.09) // ~10 mi
        XCTAssertTrue(result.contains("mi"))
        XCTAssertTrue(result.hasPrefix("10.0") || result.hasPrefix("9.9"))
    }

    func testFormattedWithDecimals() {
        let result = DistanceFormatter.formatted(km: 8.0, decimals: 2)
        XCTAssertTrue(result.contains("mi"))
        // 8 km * 0.621371 = 4.97 mi
        XCTAssertTrue(result.hasPrefix("4.97"))
    }
}
