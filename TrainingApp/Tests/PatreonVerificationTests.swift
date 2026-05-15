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

    // MARK: - Gate decision

    func testGateOffWhenToggleDisabled() {
        XCTAssertFalse(PatreonService.shouldShowGate(
            isRequired: false, isPatron: false,
            gracePeriodDaysRemaining: nil, isOnSettingsTab: false
        ))
    }

    func testGateOnWhenToggleEnabledAndNonPatron() {
        // The original bug: toggle ON + non-patron + no grace + not on settings
        // tab should always fire the gate. Pre-fix, a `!DevSignIn.isAllowed`
        // clause suppressed this in Debug builds. The pure decision must not
        // re-introduce any build-flag bypass.
        XCTAssertTrue(PatreonService.shouldShowGate(
            isRequired: true, isPatron: false,
            gracePeriodDaysRemaining: nil, isOnSettingsTab: false
        ))
    }

    func testGateOffForActivePatron() {
        XCTAssertFalse(PatreonService.shouldShowGate(
            isRequired: true, isPatron: true,
            gracePeriodDaysRemaining: nil, isOnSettingsTab: false
        ))
    }

    func testGateOffDuringGracePeriod() {
        XCTAssertFalse(PatreonService.shouldShowGate(
            isRequired: true, isPatron: false,
            gracePeriodDaysRemaining: 3, isOnSettingsTab: false
        ))
    }

    func testGateOffOnSettingsTab() {
        // Settings tab must stay reachable so the user can disable Patreon
        // even when every other condition would fire the gate.
        XCTAssertFalse(PatreonService.shouldShowGate(
            isRequired: true, isPatron: false,
            gracePeriodDaysRemaining: nil, isOnSettingsTab: true
        ))
    }
}
