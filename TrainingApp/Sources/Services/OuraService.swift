import AuthenticationServices
import Foundation

@MainActor
@Observable
final class OuraService {
    private(set) var isConnected = false
    private(set) var isSyncing = false
    private(set) var dailyData: [OuraDaily] = []
    private(set) var lastSyncDate: Date?

    private let supabase = SupabaseService.shared.client

    init() {
        isConnected = KeychainService.get(.ouraAccessToken) != nil
    }

    // MARK: - OAuth2 Flow

    func authorize() async throws {
        guard !Config.ouraClientId.isEmpty,
              Config.ouraClientId != "YOUR_OURA_CLIENT_ID" else {
            throw OuraError.missingCredentials
        }

        var components = URLComponents(string: Config.ouraAuthorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Config.ouraClientId),
            URLQueryItem(name: "redirect_uri", value: Config.ouraRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Config.ouraScope),
            URLQueryItem(name: "state", value: UUID().uuidString)
        ]

        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: "training"
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url = callbackURL,
                      let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: OuraError.noAuthCode)
                    return
                }
                continuation.resume(returning: code)
            }
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = ASWebAuthPresentationContext.shared
            session.start()
        }

        try await exchangeCodeForToken(code)
    }

    private func exchangeCodeForToken(_ code: String) async throws {
        let url = URL(string: Config.ouraTokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "client_id=\(Config.ouraClientId)",
            "client_secret=\(Config.ouraClientSecret)",
            "code=\(code)",
            "grant_type=authorization_code",
            "redirect_uri=\(Config.ouraRedirectURI)"
        ].joined(separator: "&")
        request.httpBody = Data(params.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OuraError.tokenExchangeFailed
        }

        let token = try JSONDecoder().decode(OuraTokenResponse.self, from: data)
        saveTokens(token)
        isConnected = true
    }

    private func refreshTokenIfNeeded() async throws {
        guard let expiresStr = KeychainService.get(.ouraExpiresAt),
              let expiresAt = Double(expiresStr),
              let refreshToken = KeychainService.get(.ouraRefreshToken) else {
            throw OuraError.notConnected
        }

        if Date().timeIntervalSince1970 < expiresAt - 300 { return }

        let url = URL(string: Config.ouraTokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "client_id=\(Config.ouraClientId)",
            "client_secret=\(Config.ouraClientSecret)",
            "refresh_token=\(refreshToken)",
            "grant_type=refresh_token"
        ].joined(separator: "&")
        request.httpBody = Data(params.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OuraError.tokenRefreshFailed
        }

        let token = try JSONDecoder().decode(OuraTokenResponse.self, from: data)
        saveTokens(token)
    }

    private func saveTokens(_ token: OuraTokenResponse) {
        KeychainService.save(token.accessToken, for: .ouraAccessToken)
        if let refresh = token.refreshToken {
            KeychainService.save(refresh, for: .ouraRefreshToken)
        }
        let expiresAt = Date().timeIntervalSince1970 + Double(token.expiresIn)
        KeychainService.save(String(expiresAt), for: .ouraExpiresAt)
    }

    // MARK: - Disconnect

    func disconnect() {
        KeychainService.deleteAll(for: .oura)
        isConnected = false
        dailyData = []
        lastSyncDate = nil
    }

    // MARK: - Sync Readiness & Sleep

    func syncDaily(userId: UUID, days: Int = 30) async throws {
        guard isConnected else { throw OuraError.notConnected }
        isSyncing = true
        defer { isSyncing = false }

        try await refreshTokenIfNeeded()

        guard let accessToken = KeychainService.get(.ouraAccessToken) else {
            throw OuraError.notConnected
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!

        let readinessData = try await fetchReadiness(
            accessToken: accessToken,
            start: formatter.string(from: startDate),
            end: formatter.string(from: endDate)
        )

        let sleepData = try await fetchSleep(
            accessToken: accessToken,
            start: formatter.string(from: startDate),
            end: formatter.string(from: endDate)
        )

        let heartRateData = try await fetchHeartRate(
            accessToken: accessToken,
            start: formatter.string(from: startDate),
            end: formatter.string(from: endDate)
        )

        var merged: [String: OuraDaily] = [:]

        for entry in readinessData {
            let dateStr = entry.day
            let date = formatter.date(from: dateStr) ?? Date()
            merged[dateStr] = OuraDaily(
                id: UUID(),
                userId: userId,
                date: date,
                readinessScore: entry.score,
                sleepScore: nil,
                hrvAverage: nil,
                restingHr: nil,
                temperatureDeviation: entry.temperatureDeviation,
                syncedAt: Date()
            )
        }

        for entry in sleepData {
            let dateStr = entry.day
            if merged[dateStr] != nil {
                merged[dateStr]?.sleepScore = entry.score
            } else {
                let date = formatter.date(from: dateStr) ?? Date()
                merged[dateStr] = OuraDaily(
                    id: UUID(),
                    userId: userId,
                    date: date,
                    readinessScore: nil,
                    sleepScore: entry.score,
                    hrvAverage: nil,
                    restingHr: nil,
                    temperatureDeviation: nil,
                    syncedAt: Date()
                )
            }
        }

        for entry in heartRateData {
            let dateStr = entry.day
            if merged[dateStr] != nil {
                merged[dateStr]?.restingHr = entry.lowestRestingHr
                merged[dateStr]?.hrvAverage = entry.hrvAverage
            }
        }

        dailyData = merged.values.sorted { $0.date < $1.date }
        lastSyncDate = Date()

        await persistDailyData(Array(merged.values), userId: userId)
    }

    // MARK: - API Calls

    private func fetchReadiness(accessToken: String, start: String, end: String) async throws -> [OuraReadinessEntry] {
        var components = URLComponents(string: "\(Config.ouraBaseURL)/usercollection/daily_readiness")!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: start),
            URLQueryItem(name: "end_date", value: end)
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OuraError.apiFailed
        }

        let result = try JSONDecoder().decode(OuraListResponse<OuraReadinessEntry>.self, from: data)
        return result.data
    }

    private func fetchSleep(accessToken: String, start: String, end: String) async throws -> [OuraSleepEntry] {
        var components = URLComponents(string: "\(Config.ouraBaseURL)/usercollection/daily_sleep")!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: start),
            URLQueryItem(name: "end_date", value: end)
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OuraError.apiFailed
        }

        let result = try JSONDecoder().decode(OuraListResponse<OuraSleepEntry>.self, from: data)
        return result.data
    }

    private func fetchHeartRate(accessToken: String, start: String, end: String) async throws -> [OuraHeartRateEntry] {
        var components = URLComponents(string: "\(Config.ouraBaseURL)/usercollection/daily_cardiovascular_age")!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: start),
            URLQueryItem(name: "end_date", value: end)
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let result = try? JSONDecoder().decode(OuraListResponse<OuraHeartRateEntry>.self, from: data)
        return result?.data ?? []
    }

    // MARK: - Query Helpers

    func todayReadiness() -> OuraDaily? {
        dailyData.first { Calendar.current.isDateInToday($0.date) }
    }

    func data(for date: Date) -> OuraDaily? {
        dailyData.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func recentReadiness(days: Int = 7) -> [OuraDaily] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return dailyData
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Load from Supabase

    func loadDailyData(userId: UUID) async {
        do {
            dailyData = try await supabase
                .from("oura_daily")
                .select()
                .eq("user_id", value: userId)
                .order("date", ascending: false)
                .limit(90)
                .execute()
                .value
        } catch {
            print("Failed to load Oura daily data: \(error)")
        }
    }

    // MARK: - Persistence

    private func persistDailyData(_ data: [OuraDaily], userId: UUID) async {
        for entry in data {
            do {
                try await supabase.from("oura_daily")
                    .upsert(entry, onConflict: "user_id,date")
                    .execute()
            } catch {
                print("Failed to persist Oura data: \(error)")
            }
        }
    }
}

// MARK: - Oura API Response Models

private struct OuraListResponse<T: Decodable>: Decodable {
    let data: [T]
}

private struct OuraReadinessEntry: Decodable {
    let day: String
    let score: Int?
    let temperatureDeviation: Double?

    enum CodingKeys: String, CodingKey {
        case day, score
        case temperatureDeviation = "temperature_deviation"
    }
}

private struct OuraSleepEntry: Decodable {
    let day: String
    let score: Int?
}

private struct OuraHeartRateEntry: Decodable {
    let day: String
    let lowestRestingHr: Int?
    let hrvAverage: Double?

    enum CodingKeys: String, CodingKey {
        case day
        case lowestRestingHr = "lowest_resting_heart_rate"
        case hrvAverage = "average_hrv"
    }
}

private struct OuraTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

enum OuraError: LocalizedError {
    case missingCredentials
    case notConnected
    case noAuthCode
    case tokenExchangeFailed
    case tokenRefreshFailed
    case apiFailed

    var errorDescription: String? {
        switch self {
        case .missingCredentials: "Oura API credentials not configured."
        case .notConnected: "Oura is not connected."
        case .noAuthCode: "No authorization code received from Oura."
        case .tokenExchangeFailed: "Failed to exchange authorization code for tokens."
        case .tokenRefreshFailed: "Failed to refresh Oura access token."
        case .apiFailed: "Oura API request failed."
        }
    }
}
