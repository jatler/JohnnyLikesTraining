import Auth
import Foundation
import Supabase
import XCTest
@testable import Training

/// Regression tests for the 1.2.4 lockout: a Supabase outage (paused project,
/// 5xx, no network) made `refreshIfNeeded` treat the failure as a revoked
/// refresh token, sign the user out, and strand them on a sign-in screen that
/// couldn't succeed either. Only an explicit rejection from the auth endpoint
/// may sign the user out.
final class AuthSessionFailureTests: XCTestCase {

    private func apiError(status: Int, code: ErrorCode = .unknown) -> AuthError {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.supabase.co/auth/v1/token")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        return .api(message: "test", errorCode: code, underlyingData: Data(), underlyingResponse: response)
    }

    // MARK: - Transient: keep the cached session

    func testNoNetworkIsTransient() {
        XCTAssertTrue(AuthService.isTransientSessionFailure(URLError(.notConnectedToInternet)))
        XCTAssertTrue(AuthService.isTransientSessionFailure(URLError(.cannotFindHost)))
        XCTAssertTrue(AuthService.isTransientSessionFailure(URLError(.timedOut)))
    }

    func testServerErrorsAreTransient() {
        XCTAssertTrue(AuthService.isTransientSessionFailure(apiError(status: 500, code: .unexpectedFailure)))
        XCTAssertTrue(AuthService.isTransientSessionFailure(apiError(status: 502)))
        XCTAssertTrue(AuthService.isTransientSessionFailure(apiError(status: 503)))
        // Supabase's gateway answers for a paused project with a 5xx.
        XCTAssertTrue(AuthService.isTransientSessionFailure(apiError(status: 540)))
    }

    func testRateLimitAndTimeoutStatusesAreTransient() {
        XCTAssertTrue(AuthService.isTransientSessionFailure(apiError(status: 429, code: .overRequestRateLimit)))
        XCTAssertTrue(AuthService.isTransientSessionFailure(apiError(status: 408, code: .requestTimeout)))
    }

    func testUnrecognisedErrorsAreTransient() {
        // A paused project can serve an HTML holding page, which surfaces as a
        // decoding failure — no verdict on the token, so don't sign out.
        struct Garbage: Error {}
        XCTAssertTrue(AuthService.isTransientSessionFailure(Garbage()))
    }

    // MARK: - Rejection: sign-in required

    func testMissingSessionRequiresSignIn() {
        XCTAssertFalse(AuthService.isTransientSessionFailure(AuthError.sessionMissing))
    }

    func testRevokedRefreshTokenRequiresSignIn() {
        XCTAssertFalse(AuthService.isTransientSessionFailure(apiError(status: 400, code: .refreshTokenNotFound)))
        XCTAssertFalse(AuthService.isTransientSessionFailure(apiError(status: 400, code: .refreshTokenAlreadyUsed)))
        XCTAssertFalse(AuthService.isTransientSessionFailure(apiError(status: 401, code: .badJWT)))
        XCTAssertFalse(AuthService.isTransientSessionFailure(apiError(status: 403, code: .userBanned)))
    }
}
