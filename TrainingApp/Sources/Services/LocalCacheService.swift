import Foundation

enum LocalCacheService {
    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func save<T: Encodable>(_ value: T, key: String) {
        let url = cacheDirectory.appendingPathComponent("cache_\(key).json")
        do {
            try encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            // Non-critical, but log it — a silent write failure means stale
            // data on next cold start with no trail to explain it.
            print("LocalCacheService: failed to write cache_\(key).json: \(error)")
        }
    }

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let url = cacheDirectory.appendingPathComponent("cache_\(key).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    static func remove(key: String) {
        let url = cacheDirectory.appendingPathComponent("cache_\(key).json")
        try? FileManager.default.removeItem(at: url)
    }

    static func clearAll() {
        let keys = [
            "strava_activities", "oura_daily",
            "strength_template", "strength_exercises", "strength_sessions", "strength_logs",
            "heat_sessions", "heat_logs",
            "stretch_template", "stretch_exercises", "stretch_sessions", "stretch_logs"
        ]
        for key in keys {
            remove(key: key)
        }
    }
}
