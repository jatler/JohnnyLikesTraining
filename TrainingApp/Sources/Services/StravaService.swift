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
    private var pendingOAuthState: String?

    private static let importableActivityTypes: Set<String> = [
        "Run", "TrailRun", "VirtualRun",
        "WeightTraining", "Crossfit", "Yoga",
        "Ride", "MountainBikeRide", "GravelRide", "EBikeRide", "VirtualRide",
        "CrossCountrySkiing", "BackcountrySki", "NordicSki", "AlpineSki", "Snowboard",
        "Elliptical", "Hike", "RockClimbing",
        "Rowing", "StairStepper", "Swim", "Walk"
    ]

    init() {
        isConnected = KeychainService.get(.stravaAccessToken) != nil

        #if DEBUG && targetEnvironment(simulator)
        if false && !Config.stravaDevRefreshToken.isEmpty { // TODO: re-enable after getting fresh token
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

        let state = UUID().uuidString
        pendingOAuthState = state

        var components = URLComponents(string: Config.stravaAuthorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Config.stravaClientId),
            URLQueryItem(name: "redirect_uri", value: Config.stravaRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Config.stravaScope),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "state", value: state)
        ]

        print("[Strava OAuth] Authorize URL: \(components.url!)")
        print("[Strava OAuth] Client ID: \(Config.stravaClientId.prefix(4))***")

        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            self.authSession = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: "http"
            ) { [weak self] callbackURL, error in
                self?.authSession = nil
                if let error {
                    let nsError = error as NSError
                    print("[Strava OAuth] Error domain: \(nsError.domain), code: \(nsError.code), description: \(nsError.localizedDescription)")
                    if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                        print("[Strava OAuth] Underlying: domain=\(underlying.domain), code=\(underlying.code)")
                    }
                    continuation.resume(throwing: error)
                    return
                }
                guard let url = callbackURL else {
                    continuation.resume(throwing: StravaError.noAuthCode)
                    return
                }
                let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                let returnedState = params?.first(where: { $0.name == "state" })?.value
                guard returnedState == self?.pendingOAuthState else {
                    continuation.resume(throwing: StravaError.stateMismatch)
                    return
                }
                guard let code = params?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: StravaError.noAuthCode)
                    return
                }
                continuation.resume(returning: code)
            }
            self.authSession?.prefersEphemeralWebBrowserSession = true
            self.authSession?.presentationContextProvider = ASWebAuthPresentationContext.shared
            let started = self.authSession?.start() ?? false
            print("[Strava OAuth] Session started: \(started)")
        }

        pendingOAuthState = nil
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
            KeychainService.deleteAll(for: .strava)
            isConnected = false
            throw StravaError.tokenRefreshFailed
        }

        let token = try JSONDecoder().decode(StravaTokenResponse.self, from: data)
        saveTokens(token)
    }

    private func saveTokens(_ token: StravaTokenResponse) {
        #if DEBUG
        print("🔑 Strava tokens saved")
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

    /// Disconnect from Strava: deauthorize the token with Strava, then purge all
    /// imported data per the Strava API Agreement requirement to delete user data
    /// when access is revoked.
    func disconnect(userId: UUID?) async {
        if let accessToken = KeychainService.get(.stravaAccessToken) {
            var request = URLRequest(url: URL(string: "https://www.strava.com/oauth/deauthorize")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: request)
        }
        await purgeData(userId: userId)
    }

    /// Delete every trace of Strava data tied to this user: Supabase rows, Keychain
    /// tokens, local cache, in-memory state. Safe to call when not connected.
    /// Called by sign-out and disconnect to comply with the Strava API Agreement.
    func purgeData(userId: UUID?) async {
        KeychainService.deleteAll(for: .strava)
        isConnected = false
        activities = []
        lastSyncDate = nil
        athleteName = nil
        LocalCacheService.remove(key: "strava_activities")

        guard let userId else { return }
        _ = await SupabaseService.shared.execute(
            table: "strava_activities",
            operation: "delete_all_for_user"
        ) {
            try await supabase
                .from("strava_activities")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()
        }
    }

    #if DEBUG
    /// Inject synthesized activities for App Store screenshot generation. Marks
    /// the service as connected so UI that gates on connection state renders.
    func applyDemoActivities(_ demo: [StravaActivity]) {
        activities = demo
        isConnected = true
    }
    #endif

    // MARK: - Local Cache

    func saveToCache() {
        LocalCacheService.save(activities, key: "strava_activities")
    }

    @discardableResult
    func loadFromCache() -> Bool {
        guard let cached = LocalCacheService.load([StravaActivity].self, key: "strava_activities"), !cached.isEmpty else { return false }
        activities = cached
        return true
    }

    // MARK: - Fetch Activities

    func syncActivities(userId: UUID, after: Date? = nil, merge: Bool = false) async throws {
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
        if merge {
            var existingById = Dictionary(uniqueKeysWithValues: activities.map { ($0.stravaId, $0) })
            for activity in mapped {
                existingById[activity.stravaId] = activity
            }
            activities = existingById.values.sorted { $0.activityDate > $1.activityDate }
        } else {
            activities = mapped
        }
        lastSyncDate = Date()
        saveToCache()

        // Don't block the sync return on the Supabase upsert — the in-memory
        // + on-disk cache is already updated, so the UI is current. Pull-to-
        // refresh shouldn't wait for a network round-trip the user can't see.
        Task { await persistActivities(mapped, userId: userId) }
    }

    // MARK: - Auto-Match

    func autoMatchActivities(sessions: [PlannedSession]) {
        let sessionsById = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        var changed: [StravaActivity] = []
        for i in activities.indices {
            let originalMatchId = activities[i].matchedSessionId
            // Validate any existing match — the prior code path used
            // `Calendar.current.isDate(_:inSameDayAs:)` against `localCalendarDay`
            // (a UTC-encoded midnight) which silently shifted matches by ±1 day for
            // users in non-UTC timezones. Stale wrong matches need to be cleared so
            // the new isOnLocalDay logic re-matches correctly.
            if let matchedId = originalMatchId,
               let matchedSession = sessionsById[matchedId],
               activities[i].isOnLocalDay(matchedSession.scheduledDate) {
                continue   // existing match is still correct
            }

            // Either no match yet, or the current match is wrong — re-evaluate.
            activities[i].matchedSessionId = nil

            // Match by the activity's *local* calendar day (the timezone where it
            // was recorded), so a run logged in LA lands on that LA calendar day
            // even if the user is currently in a different timezone.
            let activity = activities[i]
            let sameDaySessions = sessions.filter { activity.isOnLocalDay($0.scheduledDate) }
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

            if activities[i].matchedSessionId != originalMatchId {
                changed.append(activities[i])
            }
        }

        // Save updated matches to local cache + Supabase
        if !changed.isEmpty {
            saveToCache()
            Task {
                for activity in changed {
                    do {
                        try await supabase.from("strava_activities")
                            .upsert(activity, onConflict: "strava_id")
                            .execute()
                    } catch {
                        #if DEBUG
                        print("Failed to persist match for activity \(activity.stravaId): \(error)")
                        #endif
                    }
                }
            }
        }
    }

    func activity(for sessionId: UUID) -> StravaActivity? {
        activities.first { $0.matchedSessionId == sessionId }
    }

    func activities(on date: Date) -> [StravaActivity] {
        activities.filter { $0.isOnLocalDay(date) }
    }

    /// All running activities (Run, TrailRun, VirtualRun) on a given calendar day
    /// — interpreted in each activity's own timezone. Used wherever the UI needs
    /// to sum the day's mileage across multiple runs (doubles days).
    func runActivities(on date: Date) -> [StravaActivity] {
        activities(on: date).filter(\.isRun)
    }

    // MARK: - Load from Supabase

    func loadActivities(userId: UUID) async {
        do {
            let loaded: [StravaActivity] = try await supabase
                .from("strava_activities")
                .select()
                .eq("user_id", value: userId)
                .order("activity_date", ascending: false)
                .execute()
                .value
            #if DEBUG
            print("Supabase loaded \(loaded.count) Strava activities (had \(activities.count) in memory)")
            #endif
            // Don't overwrite existing data with empty Supabase result
            if !loaded.isEmpty || activities.isEmpty {
                activities = loaded
                saveToCache()
            }
        } catch {
            print("Failed to load Strava activities: \(error)")
        }
    }

    // MARK: - Persistence

    private func persistActivities(_ activities: [StravaActivity], userId: UUID) async {
        guard !activities.isEmpty else { return }
        do {
            try await supabase.from("strava_activities")
                .upsert(activities, onConflict: "strava_id")
                .execute()
            #if DEBUG
            print("Persisted \(activities.count) Strava activities to Supabase")
            #endif
        } catch {
            print("Failed to persist Strava activities: \(error)")
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
    let startDateLocal: Date?
    let timezone: String?
    let averageHeartrate: Double?
    let totalElevationGain: Double?
    let averageSpeed: Double?
    let map: StravaMap?

    enum CodingKeys: String, CodingKey {
        case id, name, distance, type, map, timezone
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case startDate = "start_date"
        case startDateLocal = "start_date_local"
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

        // Strava emits timezone as "(GMT-08:00) America/Los_Angeles" — grab the IANA half.
        let tzIdentifier = timezone?.split(separator: " ").last.map(String.init)

        return StravaActivity(
            id: UUID(),
            userId: userId,
            stravaId: id,
            activityDate: startDate,
            startDateLocal: startDateLocal,
            timeZoneIdentifier: tzIdentifier,
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
    case stateMismatch

    var errorDescription: String? {
        switch self {
        case .missingCredentials: "Strava API credentials not configured."
        case .notConnected: "Strava is not connected."
        case .noAuthCode: "No authorization code received from Strava."
        case .tokenExchangeFailed: "Failed to exchange authorization code for tokens."
        case .tokenRefreshFailed: "Failed to refresh Strava access token."
        case .apiFailed: "Strava API request failed."
        case .stateMismatch: "OAuth state parameter mismatch — possible CSRF attack."
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
