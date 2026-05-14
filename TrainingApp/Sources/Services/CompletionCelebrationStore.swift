import Foundation

/// Tracks which session completions have already been "celebrated" (i.e. the
/// burst animation has played for the user). Persisted in UserDefaults so the
/// celebration doesn't replay on every tab swipe or app relaunch — only the
/// first time a session is observed with a matched Strava activity.
@MainActor
final class CompletionCelebrationStore {
    static let shared = CompletionCelebrationStore()

    private let defaultsKey = "celebratedSessionIds"
    private var ids: Set<UUID>

    private init() {
        let raw = UserDefaults.standard.array(forKey: defaultsKey) as? [String] ?? []
        self.ids = Set(raw.compactMap { UUID(uuidString: $0) })
    }

    func contains(_ id: UUID) -> Bool {
        ids.contains(id)
    }

    func mark(_ id: UUID) {
        guard !ids.contains(id) else { return }
        ids.insert(id)
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: defaultsKey)
    }
}
