import Foundation
import Security

enum KeychainService {
    private static let serviceName = "com.jatler.Training"

    enum Key: String {
        case stravaAccessToken = "strava_access_token"
        case stravaRefreshToken = "strava_refresh_token"
        case stravaExpiresAt = "strava_expires_at"
        case stravaAthleteId = "strava_athlete_id"
        case ouraAccessToken = "oura_access_token"
        case ouraRefreshToken = "oura_refresh_token"
        case ouraExpiresAt = "oura_expires_at"
    }

    static func save(_ value: String, for key: Key) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue
        ]

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func deleteAll(for provider: OAuthProvider) {
        switch provider {
        case .strava:
            delete(.stravaAccessToken)
            delete(.stravaRefreshToken)
            delete(.stravaExpiresAt)
            delete(.stravaAthleteId)
        case .oura:
            delete(.ouraAccessToken)
            delete(.ouraRefreshToken)
            delete(.ouraExpiresAt)
        }
    }
}

enum OAuthProvider: String, Codable {
    case strava, oura
}
