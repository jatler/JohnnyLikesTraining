import AuthenticationServices
import Foundation

@MainActor
@Observable
final class PatreonService {
    // MARK: - Observable State

    private(set) var isConnected = false
    private(set) var isPatron = false
    private(set) var isVerifying = false
    private(set) var lastVerifiedAt: Date?
    /// Non-nil when patron_status has lapsed but the 7-day grace window is still open.
    private(set) var gracePeriodDaysRemaining: Int?

    private var authSession: ASWebAuthenticationSession?

    // MARK: - Init

    init() {
        isConnected = KeychainService.get(.patreonAccessToken) != nil
        isPatron = KeychainService.get(.patreonIsPatron) == "true"
        if let raw = KeychainService.get(.patreonLastVerifiedAt),
           let ts = Double(raw) {
            lastVerifiedAt = Date(timeIntervalSince1970: ts)
        }
        updateGracePeriod()
    }

    // MARK: - OAuth2 Authorize

    func authorize() async throws {
        var components = URLComponents(string: Config.patreonAuthorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: Config.patreonClientId),
            URLQueryItem(name: "redirect_uri", value: Config.patreonRedirectURI),
            URLQueryItem(name: "scope", value: Config.patreonScope),
            URLQueryItem(name: "state", value: UUID().uuidString)
        ]

        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            self.authSession = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: "training"
            ) { [weak self] callbackURL, error in
                self?.authSession = nil
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url = callbackURL,
                      let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: PatreonError.noAuthCode)
                    return
                }
                continuation.resume(returning: code)
            }
            self.authSession?.prefersEphemeralWebBrowserSession = false
            self.authSession?.presentationContextProvider = ASWebAuthPresentationContext.shared
            self.authSession?.start()
        }

        try await exchangeCodeForToken(code)
        try await verifyMembership()
    }

    // MARK: - Token Exchange

    private func exchangeCodeForToken(_ code: String) async throws {
        let url = URL(string: Config.patreonTokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "client_id", value: Config.patreonClientId),
            URLQueryItem(name: "client_secret", value: Config.patreonClientSecret),
            URLQueryItem(name: "redirect_uri", value: Config.patreonRedirectURI)
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PatreonError.tokenExchangeFailed
        }

        let token = try JSONDecoder().decode(PatreonTokenResponse.self, from: data)
        saveTokens(token)
        isConnected = true
    }

    // MARK: - Membership Verification

    /// Verify membership, re-checking only if last verified > 7 days ago.
    func verifyMembershipIfStale() async throws {
        if let last = lastVerifiedAt,
           Date().timeIntervalSince(last) < 7 * 24 * 3600 {
            return // cached — still fresh
        }
        try await verifyMembership()
    }

    func verifyMembership() async throws {
        guard isConnected else { throw PatreonError.notConnected }
        isVerifying = true
        defer { isVerifying = false }

        try await refreshTokenIfNeeded()

        guard let accessToken = KeychainService.get(.patreonAccessToken) else {
            throw PatreonError.notConnected
        }

        var components = URLComponents(string: Config.patreonIdentityURL)!
        components.queryItems = [
            URLQueryItem(name: "include", value: "memberships"),
            URLQueryItem(name: "fields[member]", value: "patron_status,currently_entitled_amount_cents"),
            URLQueryItem(name: "fields[campaign]", value: "id")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            try await refreshTokenIfNeeded()
            guard let newToken = KeychainService.get(.patreonAccessToken) else {
                throw PatreonError.notConnected
            }
            request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            let (data2, _) = try await URLSession.shared.data(for: request)
            processIdentityResponse(data2)
            return
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PatreonError.apiFailed
        }

        processIdentityResponse(data)
    }

    private func processIdentityResponse(_ data: Data) {
        let campaignId = Config.patreonSwapCampaignId
        let response = try? JSONDecoder().decode(PatreonIdentityResponse.self, from: data)

        let member = response?.included?
            .filter { $0.type == "member" }
            .first { member in
                member.relationships?.campaign?.data?.id == campaignId
            }

        let patronStatus = member?.attributes?.patronStatus
        let entitledCents = member?.attributes?.currentlyEntitledAmountCents ?? 0
        let activePatron = patronStatus == "active_patron" && entitledCents >= 500

        let now = Date()
        KeychainService.save(String(now.timeIntervalSince1970), for: .patreonLastVerifiedAt)
        lastVerifiedAt = now

        if activePatron {
            isPatron = true
            KeychainService.save("true", for: .patreonIsPatron)
            // Clear grace period if they've reactivated
            KeychainService.delete(.patreonGracePeriodStart)
            gracePeriodDaysRemaining = nil
        } else {
            if isPatron {
                // Patron status just lapsed — start grace period
                let gracePeriodStart = KeychainService.get(.patreonGracePeriodStart)
                if gracePeriodStart == nil {
                    KeychainService.save(String(now.timeIntervalSince1970), for: .patreonGracePeriodStart)
                }
            }
            isPatron = false
            KeychainService.save("false", for: .patreonIsPatron)
            updateGracePeriod()
        }
    }

    private func updateGracePeriod() {
        guard let raw = KeychainService.get(.patreonGracePeriodStart),
              let ts = Double(raw) else {
            gracePeriodDaysRemaining = nil
            return
        }
        let start = Date(timeIntervalSince1970: ts)
        let elapsed = Int(Date().timeIntervalSince(start) / 86400)
        let remaining = 7 - elapsed
        if remaining > 0 {
            gracePeriodDaysRemaining = remaining
        } else {
            gracePeriodDaysRemaining = nil
            KeychainService.delete(.patreonGracePeriodStart)
        }
    }

    // MARK: - Token Refresh

    private func refreshTokenIfNeeded() async throws {
        guard let refreshToken = KeychainService.get(.patreonRefreshToken) else {
            throw PatreonError.notConnected
        }

        let url = URL(string: Config.patreonTokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: Config.patreonClientId),
            URLQueryItem(name: "client_secret", value: Config.patreonClientSecret)
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PatreonError.tokenRefreshFailed
        }

        let token = try JSONDecoder().decode(PatreonTokenResponse.self, from: data)
        saveTokens(token)
    }

    private func saveTokens(_ token: PatreonTokenResponse) {
        KeychainService.save(token.accessToken, for: .patreonAccessToken)
        if let refresh = token.refreshToken {
            KeychainService.save(refresh, for: .patreonRefreshToken)
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        KeychainService.deleteAll(for: .patreon)
        isConnected = false
        isPatron = false
        lastVerifiedAt = nil
        gracePeriodDaysRemaining = nil
    }
}

// MARK: - Patreon API Response Models

private struct PatreonTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

private struct PatreonIdentityResponse: Decodable {
    let data: PatreonUser?
    let included: [PatreonIncluded]?
}

private struct PatreonUser: Decodable {
    let id: String
    let type: String
}

private struct PatreonIncluded: Decodable {
    let id: String
    let type: String
    let attributes: PatreonMemberAttributes?
    let relationships: PatreonMemberRelationships?
}

private struct PatreonMemberAttributes: Decodable {
    let patronStatus: String?
    let currentlyEntitledAmountCents: Int?

    enum CodingKeys: String, CodingKey {
        case patronStatus = "patron_status"
        case currentlyEntitledAmountCents = "currently_entitled_amount_cents"
    }
}

private struct PatreonMemberRelationships: Decodable {
    let campaign: PatreonRelationship?
}

private struct PatreonRelationship: Decodable {
    let data: PatreonRelationshipData?
}

private struct PatreonRelationshipData: Decodable {
    let id: String
    let type: String
}

enum PatreonError: LocalizedError {
    case notConnected
    case noAuthCode
    case tokenExchangeFailed
    case tokenRefreshFailed
    case apiFailed

    var errorDescription: String? {
        switch self {
        case .notConnected: "Patreon is not connected."
        case .noAuthCode: "No authorization code received from Patreon."
        case .tokenExchangeFailed: "Failed to exchange authorization code for tokens."
        case .tokenRefreshFailed: "Failed to refresh Patreon access token."
        case .apiFailed: "Patreon API request failed."
        }
    }
}
