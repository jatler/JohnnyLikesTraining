import Foundation

// MARK: - OAuth Configuration

/// Configuration for an OAuth2 service
struct OAuthConfig {
    let provider: OAuthProvider
    let authorizeURL: String
    let tokenURL: String
    let clientId: String
    let redirectURI: String
    let scope: String
    let callbackScheme: String
    let prefersEphemeral: Bool

    // Keys for Keychain storage
    let accessTokenKey: KeychainService.Key
    let refreshTokenKey: KeychainService.Key
    let expiresAtKey: KeychainService.Key
}

// MARK: - Unified Token Response

/// Unified token response across all OAuth providers
struct OAuthTokenResponse {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?      // seconds from now (Oura/Patreon style)
    let expiresAt: Int?      // unix timestamp (Strava style)
}

// MARK: - Token Exchanger Protocol

/// Protocol for OAuth token exchange — enables mocking in tests
protocol OAuthTokenExchanger {
    func exchangeCode(_ code: String, config: OAuthConfig) async throws -> OAuthTokenResponse
    func refreshToken(_ refreshToken: String, config: OAuthConfig) async throws -> OAuthTokenResponse
}

// MARK: - Direct Token Exchanger

/// Default implementation that calls the provider's token URL directly, including client_secret in the request.
/// Use this when the app holds the client secret (e.g. local development).
struct DirectOAuthTokenExchanger: OAuthTokenExchanger {
    let clientSecret: String

    func exchangeCode(_ code: String, config: OAuthConfig) async throws -> OAuthTokenResponse {
        var body: [String: String] = [
            "client_id": config.clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": config.redirectURI
        ]
        // Strava does not use redirect_uri in token exchange
        if config.provider == .strava {
            body.removeValue(forKey: "redirect_uri")
        }
        return try await performTokenRequest(url: config.tokenURL, body: body, provider: config.provider)
    }

    func refreshToken(_ refreshToken: String, config: OAuthConfig) async throws -> OAuthTokenResponse {
        let body: [String: String] = [
            "client_id": config.clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        return try await performTokenRequest(url: config.tokenURL, body: body, provider: config.provider)
    }

    private func performTokenRequest(url: String, body: [String: String], provider: OAuthProvider) async throws -> OAuthTokenResponse {
        guard let requestURL = URL(string: url) else {
            throw OAuthTokenError.invalidURL
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[\(provider.rawValue)] Direct token request failed — HTTP \(status): \(responseBody)")
            throw OAuthTokenError.requestFailed(statusCode: status)
        }

        return try decodeTokenResponse(data: data, provider: provider)
    }
}

// MARK: - Edge Function Token Exchanger

/// Implementation that routes through Supabase Edge Functions (no client secret in app).
/// The edge function holds the secret and forwards the request to the provider.
struct EdgeFunctionOAuthTokenExchanger: OAuthTokenExchanger {
    let edgeFunctionBaseURL: String

    func exchangeCode(_ code: String, config: OAuthConfig) async throws -> OAuthTokenResponse {
        var body: [String: String] = [
            "code": code,
            "grant_type": "authorization_code"
        ]
        // Oura and Patreon require redirect_uri in exchange
        if config.provider == .oura || config.provider == .patreon {
            body["redirect_uri"] = config.redirectURI
        }
        let endpoint = "\(edgeFunctionBaseURL)/\(config.provider.rawValue)-token"
        return try await performTokenRequest(url: endpoint, body: body, provider: config.provider)
    }

    func refreshToken(_ refreshToken: String, config: OAuthConfig) async throws -> OAuthTokenResponse {
        let body: [String: String] = [
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        let endpoint = "\(edgeFunctionBaseURL)/\(config.provider.rawValue)-token"
        return try await performTokenRequest(url: endpoint, body: body, provider: config.provider)
    }

    private func performTokenRequest(url: String, body: [String: String], provider: OAuthProvider) async throws -> OAuthTokenResponse {
        guard let requestURL = URL(string: url) else {
            throw OAuthTokenError.invalidURL
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[\(provider.rawValue)] Edge function token request failed — HTTP \(status): \(responseBody)")
            throw OAuthTokenError.requestFailed(statusCode: status)
        }

        return try decodeTokenResponse(data: data, provider: provider)
    }
}

// MARK: - Shared Decoding

/// Decode a raw JSON token response into the unified OAuthTokenResponse.
/// Handles both `expires_in` (Oura/Patreon) and `expires_at` (Strava) styles.
private func decodeTokenResponse(data: Data, provider: OAuthProvider) throws -> OAuthTokenResponse {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw OAuthTokenError.decodeFailed
    }
    guard let accessToken = json["access_token"] as? String else {
        throw OAuthTokenError.decodeFailed
    }
    let refreshToken = json["refresh_token"] as? String
    let expiresIn = json["expires_in"] as? Int
    let expiresAt = json["expires_at"] as? Int

    return OAuthTokenResponse(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn,
        expiresAt: expiresAt
    )
}

// MARK: - Errors

enum OAuthTokenError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid token URL."
        case .requestFailed(let code):
            "Token request failed with HTTP \(code)."
        case .decodeFailed:
            "Failed to decode token response."
        }
    }
}
