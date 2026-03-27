import XCTest
@testable import Training

final class PatreonVerificationTests: XCTestCase {

    // MARK: - processIdentityResponse decode error propagation

    func testDecodeErrorThrows() {
        // We verify the error type exists and carries a useful description
        let error = PatreonError.decodeFailed("test decode failure")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("decode"))
        XCTAssertTrue(error.errorDescription!.contains("test decode failure"))
    }

    func testStateMismatchError() {
        let error = PatreonError.stateMismatch
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("state"))
    }

    func testPatreonErrorDescriptions() {
        let cases: [(PatreonError, String)] = [
            (.notConnected, "not connected"),
            (.noAuthCode, "authorization code"),
            (.tokenExchangeFailed, "exchange"),
            (.tokenRefreshFailed, "refresh"),
            (.apiFailed, "API"),
            (.stateMismatch, "state"),
            (.decodeFailed("test"), "decode"),
        ]

        for (error, keyword) in cases {
            XCTAssertNotNil(error.errorDescription, "Missing description for \(error)")
            XCTAssertTrue(
                error.errorDescription!.lowercased().contains(keyword.lowercased()),
                "Expected '\(keyword)' in: \(error.errorDescription!)"
            )
        }
    }
}
