@testable import Training
import XCTest

final class OAuthTokenExchangerTests: XCTestCase {

    // MARK: - Mock

    struct MockOAuthTokenExchanger: OAuthTokenExchanger {
        var exchangeResult: Result<OAuthTokenResponse, Error> = .failure(OAuthTokenError.requestFailed(statusCode: 500))
        var refreshResult: Result<OAuthTokenResponse, Error> = .failure(OAuthTokenError.requestFailed(statusCode: 500))

        func exchangeCode(_ code: String, config: OAuthConfig) async throws -> OAuthTokenResponse {
            try exchangeResult.get()
        }

        func refreshToken(_ refreshToken: String, config: OAuthConfig) async throws -> OAuthTokenResponse {
            try refreshResult.get()
        }
    }

    // MARK: - Helpers

    private var sampleConfig: OAuthConfig {
        OAuthConfig(
            provider: .strava,
            authorizeURL: "https://example.com/authorize",
            tokenURL: "https://example.com/token",
            clientId: "test-client-id",
            redirectURI: "training://callback",
            scope: "read",
            callbackScheme: "training",
            prefersEphemeral: true,
            accessTokenKey: .stravaAccessToken,
            refreshTokenKey: .stravaRefreshToken,
            expiresAtKey: .stravaExpiresAt
        )
    }

    private var successResponse: OAuthTokenResponse {
        OAuthTokenResponse(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token",
            expiresIn: 3600,
            expiresAt: nil
        )
    }

    // MARK: - Tests

    func testMockExchangeCodeSuccess() async throws {
        var mock = MockOAuthTokenExchanger()
        mock.exchangeResult = .success(successResponse)

        let response = try await mock.exchangeCode("test-code", config: sampleConfig)
        XCTAssertEqual(response.accessToken, "test-access-token")
        XCTAssertEqual(response.refreshToken, "test-refresh-token")
        XCTAssertEqual(response.expiresIn, 3600)
    }

    func testMockExchangeCodeFailure() async {
        let mock = MockOAuthTokenExchanger()

        do {
            _ = try await mock.exchangeCode("test-code", config: sampleConfig)
            XCTFail("Expected error")
        } catch {
            guard let tokenError = error as? OAuthTokenError else {
                XCTFail("Expected OAuthTokenError, got \(error)")
                return
            }
            if case .requestFailed(let code) = tokenError {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected requestFailed error")
            }
        }
    }

    func testMockRefreshTokenSuccess() async throws {
        var mock = MockOAuthTokenExchanger()
        mock.refreshResult = .success(successResponse)

        let response = try await mock.refreshToken("test-refresh", config: sampleConfig)
        XCTAssertEqual(response.accessToken, "test-access-token")
    }

    func testMockRefreshTokenFailure() async {
        let mock = MockOAuthTokenExchanger()

        do {
            _ = try await mock.refreshToken("test-refresh", config: sampleConfig)
            XCTFail("Expected error")
        } catch {
            guard let tokenError = error as? OAuthTokenError else {
                XCTFail("Expected OAuthTokenError")
                return
            }
            if case .requestFailed(let code) = tokenError {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected requestFailed error")
            }
        }
    }

    func testEdgeFunctionExchangerBuildsCorrectURL() {
        let exchanger = EdgeFunctionOAuthTokenExchanger(edgeFunctionBaseURL: "https://test.supabase.co/functions/v1")
        // Verify the exchanger stores the base URL correctly
        XCTAssertEqual(exchanger.edgeFunctionBaseURL, "https://test.supabase.co/functions/v1")
    }
}
