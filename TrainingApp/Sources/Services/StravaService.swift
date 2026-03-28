import AuthenticationServices
import Foundation

@MainActor
@Observable
final class StravaService {
    private(set) var isConnected = false
    private(set) var isSyncing = false
    private(set) var activities: [StravaActivity] = []
    private(set) var lastSyncDate: Date?
    private(set) var athleteName: String?

    private let supabase = SupabaseService.shared.client
    private var authSession: ASWebAuthenticationSession?

    private static let importableActivityTypes: Set<String> = [
        "Run", "TrailRun", "VirtualRun",
        "WeightTraining", "Crossfit", "Yoga",
        "CrossCountrySkiing", "Elliptical", "Hike", "RockClimbing",
        "Rowing", "StairStepper", "Swim", "Walk"
    ]

    init() {
        isConnected = KeychainService.get(.stravaAccessToken) != nil

        #if DEBUG && targetEnvironment(simulator)
        if !Config.stravaDevRefreshToken.isEmpty {
            if KeychainService.get(.stravaRefreshToken) != Config.stravaDevRefreshToken {
                KeychainService.deleteAll(for: .strava)
                KeychainService.save(Config.stravaDevRefreshToken, for: .stravaRefreshToken)
                KeychainService.save("0", for: .stravaExpiresAt)
            }
            isConnected = true
        }
        #endif
    }

    // MARK: - OAuth2 Flow

    func authorize() async throws {
        guard !Config.stravaClientId.isEmpty,
              Config.stravaClientId != "YOUR_STRAVA_CLIENT_ID" else {
            throw StravaError.missingCredentials
        }

        var components = URLComponents(string: Config.stravaAuthorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Config.stravaClientId),
            URLQueryItem(name: "redirect_uri", value: Config.stravaRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Config.stravaScope),
            URLQueryItem(name: "approval_prompt", value: "auto")
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
                    continuation.resume(throwing: StravaError.noAuthCode)
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
        let url = URL(string: Config.stravaTokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": Config.stravaClientId,
            "client_secret": Config.stravaClientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            print("❌ Strava token exchange failed — HTTP \(status): \(body)")
            throw StravaError.tokenExchangeFailed
        }

        let token = try JSONDecoder().decode(StravaTokenResponse.self, from: data)
        saveTokens(token)
        isConnected = true
    }

    private func refreshTokenIfNeeded() async throws {
        guard let expiresStr = KeychainService.get(.stravaExpiresAt),
              let expiresAt = Double(expiresStr),
              let refreshToken = KeychainService.get(.stravaRefreshToken) else {
            throw StravaError.notConnected
        }

        if Date().timeIntervalSince1970 < expiresAt - 300 { return }

        let url = URL(string: Config.stravaTokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": Config.stravaClientId,
            "client_secret": Config.stravaClientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            print("❌ Strava token refresh failed — HTTP \(status): \(body)")
            throw StravaError.tokenRefreshFailed
        }

        let token = try JSONDecoder().decode(StravaTokenResponse.self, from: data)
        saveTokens(token)
    }

    private func saveTokens(_ token: StravaTokenResponse) {
        #if DEBUG
        print("🔑 Strava refresh token: \(token.refreshToken)")
        #endif
        KeychainService.save(token.accessToken, for: .stravaAccessToken)
        KeychainService.save(token.refreshToken, for: .stravaRefreshToken)
        KeychainService.save(String(token.expiresAt), for: .stravaExpiresAt)
        if let athlete = token.athlete {
            let name = [athlete.firstname, athlete.lastname]
                .compactMap { $0 }
                .joined(separator: " ")
            athleteName = name.isEmpty ? nil : name
            KeychainService.save(String(athlete.id), for: .stravaAthleteId)
        }
    }

    // MARK: - Disconnect

    func disconnect() async {
        if let accessToken = KeychainService.get(.stravaAccessToken) {
            var request = URLRequest(url: URL(string: "https://www.strava.com/oauth/deauthorize")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: request)
        }
        KeychainService.deleteAll(for: .strava)
        isConnected = false
        activities = []
        lastSyncDate = nil
        athleteName = nil
    }

    // MARK: - Fetch Activities

    func syncActivities(userId: UUID, after: Date? = nil) async throws {
        guard isConnected else { throw StravaError.notConnected }
        isSyncing = true
        defer { isSyncing = false }

        try await refreshTokenIfNeeded()

        guard let accessToken = KeychainService.get(.stravaAccessToken) else {
            throw StravaError.notConnected
        }

        let startDate = after ?? Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let epoch = Int(startDate.timeIntervalSince1970)

        var allActivities: [StravaAPIActivity] = []
        var page = 1
        let perPage = 100

        while true {
            var components = URLComponents(string: "\(Config.stravaBaseURL)/athlete/activities")!
            components.queryItems = [
                URLQueryItem(name: "after", value: String(epoch)),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(perPage))
            ]

            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let body = String(data: data, encoding: .utf8) ?? "(no body)"
                print("❌ Strava activities fetch failed — HTTP \(status): \(body)")
                throw StravaError.apiFailed
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let batch = try decoder.decode([StravaAPIActivity].self, from: data)

            let importable = batch.filter { Self.importableActivityTypes.contains($0.type) }
            allActivities.append(contentsOf: importable)

            if batch.count < perPage { break }
            page += 1
        }

        let mapped = allActivities.map { $0.toStravaActivity(userId: userId) }
        activities = mapped
        lastSyncDate = Date()

        await persistActivities(mapped, userId: userId)
    }

    // MARK: - Auto-Match

    func autoMatchActivities(sessions: [PlannedSession]) {
        for i in activities.indices {
            if activities[i].matchedSessionId != nil { continue }
            let actDate = Calendar.current.startOfDay(for: activities[i].activityDate)
            let sameDaySessions = sessions.filter {
                Calendar.current.isDate($0.scheduledDate, inSameDayAs: actDate)
            }
            let match: PlannedSession?
            if activities[i].isRun {
                match = sameDaySessions.first { $0.workoutType != .strength && $0.workoutType != .crossTrain }
                    ?? sameDaySessions.first
            } else if activities[i].isCrossTraining {
                match = sameDaySessions.first { $0.workoutType == .crossTrain }
                    ?? sameDaySessions.first
            } else {
                match = sameDaySessions.first
            }
            if let match {
                activities[i].matchedSessionId = match.id
            }
        }
    }

    func activity(for sessionId: UUID) -> StravaActivity? {
        activities.first { $0.matchedSessionId == sessionId }
    }

    func activities(on date: Date) -> [StravaActivity] {
        activities.filter { Calendar.current.isDate($0.activityDate, inSameDayAs: date) }
    }

    // MARK: - Load from Supabase

    func loadActivities(userId: UUID) async {
        do {
            activities = try await supabase
                .from("strava_activities")
                .select()
                .eq("user_id", value: userId)
                .order("activity_date", ascending: false)
                .execute()
                .value
        } catch {
            print("Failed to load Strava activities: \(error)")
        }
    }

    // MARK: - Persistence

    private func persistActivities(_ activities: [StravaActivity], userId: UUID) async {
        for activity in activities {
            do {
                try await supabase.from("strava_activities")
                    .upsert(activity, onConflict: "strava_id")
                    .execute()
            } catch {
                print("Failed to persist Strava activity \(activity.stravaId): \(error)")
            }
        }
    }
}

// MARK: - API Response Models

private struct StravaTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int
    let athlete: StravaAthlete?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case athlete
    }
}

private struct StravaAthlete: Decodable {
    let id: Int
    let firstname: String?
    let lastname: String?
}

struct StravaAPIActivity: Decodable {
    let id: Int64
    let name: String
    let distance: Double
    let movingTime: Int
    let elapsedTime: Int
    let type: String
    let startDate: Date
    let averageHeartrate: Double?
    let totalElevationGain: Double?
    let averageSpeed: Double?
    let map: StravaMap?

    enum CodingKeys: String, CodingKey {
        case id, name, distance, type, map
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case startDate = "start_date"
        case averageHeartrate = "average_heartrate"
        case totalElevationGain = "total_elevation_gain"
        case averageSpeed = "average_speed"
    }

    func toStravaActivity(userId: UUID) -> StravaActivity {
        let distanceKm = distance / 1000.0
        let pacePerKm: Double? = averageSpeed.flatMap { speed in
            guard speed > 0 else { return nil }
            return (1000.0 / speed) / 60.0
        }

        return StravaActivity(
            id: UUID(),
            userId: userId,
            stravaId: id,
            activityDate: startDate,
            name: name,
            distanceKm: distanceKm,
            movingTimeSeconds: movingTime,
            elapsedTimeSeconds: elapsedTime,
            averagePacePerKm: pacePerKm,
            averageHr: averageHeartrate.map { Int($0) },
            elevationGainM: totalElevationGain,
            mapPolyline: map?.summaryPolyline,
            activityType: type,
            matchedSessionId: nil,
            syncedAt: Date()
        )
    }
}

struct StravaMap: Decodable {
    let summaryPolyline: String?

    enum CodingKeys: String, CodingKey {
        case summaryPolyline = "summary_polyline"
    }
}

enum StravaError: LocalizedError {
    case missingCredentials
    case notConnected
    case noAuthCode
    case tokenExchangeFailed
    case tokenRefreshFailed
    case apiFailed

    var errorDescription: String? {
        switch self {
        case .missingCredentials: "Strava API credentials not configured."
        case .notConnected: "Strava is not connected."
        case .noAuthCode: "No authorization code received from Strava."
        case .tokenExchangeFailed: "Failed to exchange authorization code for tokens."
        case .tokenRefreshFailed: "Failed to refresh Strava access token."
        case .apiFailed: "Strava API request failed."
        }
    }
}

// MARK: - ASWebAuthenticationSession Helper

final class ASWebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = ASWebAuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
