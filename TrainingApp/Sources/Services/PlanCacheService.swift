import Foundation

enum PlanCacheService {
    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static var planURL: URL { cacheDirectory.appendingPathComponent("cached_plan.json") }
    private static var sessionsURL: URL { cacheDirectory.appendingPathComponent("cached_sessions.json") }

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

    static func save(plan: TrainingPlan, sessions: [PlannedSession]) {
        do {
            let planData = try encoder.encode(plan)
            try planData.write(to: planURL, options: .atomic)

            let sessionsData = try encoder.encode(sessions)
            try sessionsData.write(to: sessionsURL, options: .atomic)
        } catch {
            // Cache write failure is non-critical
        }
    }

    static func loadCached() -> (plan: TrainingPlan, sessions: [PlannedSession])? {
        guard FileManager.default.fileExists(atPath: planURL.path) else { return nil }

        do {
            let planData = try Data(contentsOf: planURL)
            let plan = try decoder.decode(TrainingPlan.self, from: planData)

            let sessionsData = try Data(contentsOf: sessionsURL)
            let sessions = try decoder.decode([PlannedSession].self, from: sessionsData)

            return (plan, sessions)
        } catch {
            return nil
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: planURL)
        try? FileManager.default.removeItem(at: sessionsURL)
    }
}
