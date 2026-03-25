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
    private var authSession: ASWebAuthenticationSession?

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
                    continuation.resume(throwing: OuraError.noAuthCode)
                    return
                }
                continuation.resume(returning: code)
            }
            self.authSession?.prefersEphemeralWebBrowserSession = false
            self.authSession?.presentationContextProvider = ASWebAuthPresentationContext.shared
            self.authSession?.start()
        }

        try await exchangeCodeForToken(code)
    }

    private func exchangeCodeForToken(_ code: String) async throws {
        let url = URL(string: Config.ouraTokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        #if DEBUG
        print("Oura client_id: [\(Config.ouraClientId)]")
        print("Oura client_secret: [\(Config.ouraClientSecret)]")
        print("Oura redirect_uri: [\(Config.ouraRedirectURI)]")
        #endif

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Config.ouraClientId),
            URLQueryItem(name: "client_secret", value: Config.ouraClientSecret),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: Config.ouraRedirectURI)
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("Oura token exchange failed (\(status)): \(body)")
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

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Config.ouraClientId),
            URLQueryItem(name: "client_secret", value: Config.ouraClientSecret),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            print("Oura token refresh failed: \(body)")
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

        let sleepPeriods = try await fetchSleepPeriods(
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

        for entry in sleepPeriods {
            let dateStr = entry.day
            let hrv = entry.averageHrv.map(Double.init)
            if merged[dateStr] != nil {
                merged[dateStr]?.restingHr = entry.lowestHeartRate
                merged[dateStr]?.hrvAverage = hrv
            } else {
                let date = formatter.date(from: dateStr) ?? Date()
                merged[dateStr] = OuraDaily(
                    id: UUID(),
                    userId: userId,
                    date: date,
                    readinessScore: nil,
                    sleepScore: nil,
                    hrvAverage: hrv,
                    restingHr: entry.lowestHeartRate,
                    temperatureDeviation: nil,
                    syncedAt: Date()
                )
            }
        }

        // When today has readiness/sleep scores but no HRV/RHR (sleep period
        // not processed yet), fill forward from the most recent sleep period.
        let todayStr = formatter.string(from: Date())
        if var todayEntry = merged[todayStr],
           todayEntry.hrvAverage == nil || todayEntry.restingHr == nil {
            let mostRecent = sleepPeriods
                .sorted(by: { $0.day > $1.day })
                .first
            if let recent = mostRecent {
                if todayEntry.hrvAverage == nil {
                    todayEntry.hrvAverage = recent.averageHrv.map(Double.init)
                }
                if todayEntry.restingHr == nil {
                    todayEntry.restingHr = recent.lowestHeartRate
                }
                merged[todayStr] = todayEntry
            }
        }

        #if DEBUG
        let withHrv = merged.values.filter { $0.hrvAverage != nil }.count
        let withRhr = merged.values.filter { $0.restingHr != nil }.count
        print("Oura merged: \(merged.count) days, \(withHrv) with HRV, \(withRhr) with RHR")
        if withHrv == 0 && withRhr == 0 && !sleepPeriods.isEmpty {
            print("⚠️ Sleep periods fetched but no HRV/RHR data — user may need to disconnect & reconnect Oura to grant heartrate scope")
        }
        #endif

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

    private func fetchSleepPeriods(accessToken: String, start: String, end: String) async throws -> [OuraSleepPeriodEntry] {
        var allPeriods: [OuraSleepPeriodEntry] = []
        var nextToken: String? = nil

        repeat {
            var components = URLComponents(string: "\(Config.ouraBaseURL)/usercollection/sleep")!
            components.queryItems = [
                URLQueryItem(name: "start_date", value: start),
                URLQueryItem(name: "end_date", value: end)
            ]
            if let token = nextToken {
                components.queryItems?.append(URLQueryItem(name: "next_token", value: token))
            }

            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("Oura sleep periods fetch failed (\(status)): \(body)")
                return []
            }

            #if DEBUG
            if allPeriods.isEmpty, let raw = String(data: data, encoding: .utf8) {
                let preview = raw.prefix(1500)
                print("Oura /usercollection/sleep raw response (\(data.count) bytes): \(preview)")
            }
            #endif

            let result: OuraListResponse<OuraSleepPeriodEntry>
            do {
                result = try JSONDecoder().decode(OuraListResponse<OuraSleepPeriodEntry>.self, from: data)
            } catch {
                print("Oura sleep periods decode error: \(error)")
                return []
            }

            allPeriods.append(contentsOf: result.data)
            nextToken = result.nextToken
        } while nextToken != nil

        let validTypes: Set<String> = ["long_sleep", "sleep", "late_nap"]
        let filtered = allPeriods.filter { validTypes.contains($0.type ?? "") }

        #if DEBUG
        print("Oura sleep periods: \(allPeriods.count) total, \(filtered.count) after type filter")
        for p in filtered.prefix(5) {
            print("  \(p.day) [\(p.type ?? "?")] HR=\(p.lowestHeartRate.map(String.init) ?? "nil") HRV=\(p.averageHrv.map(String.init) ?? "nil") dur=\(p.totalSleepDuration.map(String.init) ?? "nil")")
        }
        #endif

        // Multiple sleep periods can exist per day (main sleep, naps).
        // Keep only the longest period per day for resting HR / HRV.
        var bestByDay: [String: OuraSleepPeriodEntry] = [:]
        for period in filtered {
            if let existing = bestByDay[period.day] {
                if (period.totalSleepDuration ?? 0) > (existing.totalSleepDuration ?? 0) {
                    bestByDay[period.day] = period
                }
            } else {
                bestByDay[period.day] = period
            }
        }
        return Array(bestByDay.values)
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
        do {
            _ = try await supabase.auth.session
        } catch {
            print("Oura persist skipped — no valid Supabase session: \(error)")
            return
        }

        for entry in data {
            do {
                try await supabase.from("oura_daily")
                    .upsert(entry, onConflict: "user_id,date")
                    .execute()
            } catch {
                print("Failed to persist Oura data for \(entry.date): \(error)")
            }
        }
    }
}

// MARK: - Oura API Response Models

private struct OuraListResponse<T: Decodable>: Decodable {
    let data: [T]
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
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

private struct OuraSleepPeriodEntry: Decodable {
    let day: String
    let lowestHeartRate: Int?
    let averageHrv: Int?
    let totalSleepDuration: Int?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case day, type
        case lowestHeartRate = "lowest_heart_rate"
        case averageHrv = "average_hrv"
        case totalSleepDuration = "total_sleep_duration"
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
