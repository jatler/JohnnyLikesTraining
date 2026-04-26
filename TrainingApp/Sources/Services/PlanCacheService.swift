import Foundation

enum PlanCacheService {
    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static var planURL: URL { cacheDirectory.appendingPathComponent("cached_plan.json") }
    private static var sessionsURL: URL { cacheDirectory.appendingPathComponent("cached_sessions.json") }
    private static var skipsURL: URL { cacheDirectory.appendingPathComponent("cached_skips.json") }
    private static var swapsURL: URL { cacheDirectory.appendingPathComponent("cached_swaps.json") }
    private static var overridesURL: URL { cacheDirectory.appendingPathComponent("cached_overrides.json") }
    private static var pendingSwapsURL: URL { cacheDirectory.appendingPathComponent("cached_pending_swaps.json") }

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

    static func save(
        plan: TrainingPlan,
        sessions: [PlannedSession],
        skips: [SessionSkip] = [],
        swaps: [SessionSwap] = [],
        overrides: [SessionOverride] = []
    ) {
        do {
            try encoder.encode(plan).write(to: planURL, options: .atomic)
            try encoder.encode(sessions).write(to: sessionsURL, options: .atomic)
            try encoder.encode(skips).write(to: skipsURL, options: .atomic)
            try encoder.encode(swaps).write(to: swapsURL, options: .atomic)
            try encoder.encode(overrides).write(to: overridesURL, options: .atomic)
        } catch {
            // Cache write failure is non-critical
        }
    }

    static func loadCached() -> (plan: TrainingPlan, sessions: [PlannedSession], skips: [SessionSkip], swaps: [SessionSwap], overrides: [SessionOverride])? {
        guard FileManager.default.fileExists(atPath: planURL.path) else { return nil }

        do {
            let plan = try decoder.decode(TrainingPlan.self, from: Data(contentsOf: planURL))
            let sessions = try decoder.decode([PlannedSession].self, from: Data(contentsOf: sessionsURL))
            let skips = (try? decoder.decode([SessionSkip].self, from: Data(contentsOf: skipsURL))) ?? []
            let swaps = (try? decoder.decode([SessionSwap].self, from: Data(contentsOf: swapsURL))) ?? []
            let overrides = (try? decoder.decode([SessionOverride].self, from: Data(contentsOf: overridesURL))) ?? []

            return (plan, sessions, skips, swaps, overrides)
        } catch {
            return nil
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: planURL)
        try? FileManager.default.removeItem(at: sessionsURL)
        try? FileManager.default.removeItem(at: skipsURL)
        try? FileManager.default.removeItem(at: swapsURL)
        try? FileManager.default.removeItem(at: overridesURL)
        try? FileManager.default.removeItem(at: pendingSwapsURL)
    }

    // MARK: - Pending swap queue
    //
    // Swaps that haven't been confirmed by Supabase yet (offline, app suspended
    // mid-write, or transient failure). Stored separately so they survive app
    // restarts and can be replayed before the next loadPlan fetch — otherwise
    // the fresh Supabase rows would clobber the local cache and the swap would
    // appear to revert.

    static func savePendingSwaps(_ pending: [PendingSwap]) {
        do {
            let data = try encoder.encode(pending)
            try data.write(to: pendingSwapsURL, options: .atomic)
        } catch {
            // Cache write failure is non-critical — pending swap is still in memory.
        }
    }

    static func loadPendingSwaps() -> [PendingSwap] {
        guard FileManager.default.fileExists(atPath: pendingSwapsURL.path) else { return [] }
        return (try? decoder.decode([PendingSwap].self, from: Data(contentsOf: pendingSwapsURL))) ?? []
    }
}
