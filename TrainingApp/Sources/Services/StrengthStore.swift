import Foundation

@MainActor
@Observable
final class StrengthStore {

    private(set) var sessions: [StrengthSession] = []
    private(set) var isLoading = false
    var lastError: String?

    private let supabase = SupabaseService.shared.client
    private var isOffline: Bool { SupabaseService.shared.isOffline }

    var hasSessions: Bool { !sessions.isEmpty }

    // MARK: - Query Helpers

    func sessions(for date: Date) -> [StrengthSession] {
        sessions.filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: date) }
    }

    func sessions(for weekNumber: Int, dayOfWeek: Int) -> [StrengthSession] {
        sessions.filter { $0.weekNumber == weekNumber && $0.dayOfWeek == dayOfWeek }
    }

    func sessions(for weekNumber: Int) -> [StrengthSession] {
        sessions.filter { $0.weekNumber == weekNumber }
    }

    /// Days of week (1-7) that have any strength sessions across the plan.
    var daysWithSessions: [Int] {
        Array(Set(sessions.map(\.dayOfWeek))).sorted()
    }

    /// Days of week that have strength sessions in the given week.
    func daysWithSessions(for weekNumber: Int) -> [Int] {
        Array(Set(sessions.filter { $0.weekNumber == weekNumber }.map(\.dayOfWeek))).sorted()
    }

    func isComplete(_ sessionId: UUID) -> Bool {
        sessions.first(where: { $0.id == sessionId })?.isComplete ?? false
    }

    func completedCount(for date: Date) -> Int {
        sessions(for: date).filter(\.isComplete).count
    }

    func totalCount(for date: Date) -> Int {
        sessions(for: date).count
    }

    func isDayComplete(on date: Date, stravaActivities: [StravaActivity]) -> Bool {
        let daySessions = sessions(for: date)
        guard !daySessions.isEmpty else { return false }
        if daySessions.allSatisfy(\.isComplete) { return true }
        return stravaActivities.contains {
            $0.isStrength && Calendar.current.isDate($0.activityDate, inSameDayAs: date)
        }
    }

    // MARK: - Initialize from Planned Sessions

    /// Build strength sessions from the planned sessions in the training plan.
    /// Only sessions with `workoutType == .strength` are included.
    func initializeFromPlannedSessions(
        _ plannedSessions: [PlannedSession],
        planId: UUID
    ) {
        let strengthPlanned = plannedSessions.filter { $0.workoutType == .strength }

        sessions = strengthPlanned.map { planned in
            StrengthSession(
                id: UUID(),
                planId: planId,
                plannedSessionId: planned.id,
                scheduledDate: planned.scheduledDate,
                weekNumber: planned.weekNumber,
                dayOfWeek: planned.dayOfWeek,
                coachNotes: planned.notes ?? "",
                isComplete: false
            )
        }

        saveToCache()
        Task { await persistAllSessions() }
    }

    /// Refresh coach notes from planned sessions without resetting completion state.
    func refreshFromPlannedSessions(_ plannedSessions: [PlannedSession], planId: UUID) {
        let strengthPlanned = plannedSessions.filter { $0.workoutType == .strength }
        let existingByPlannedId = Dictionary(
            uniqueKeysWithValues: sessions.compactMap { s in
                (s.plannedSessionId, s)
            }
        )

        var updated: [StrengthSession] = []
        for planned in strengthPlanned {
            if let existing = existingByPlannedId[planned.id] {
                var session = existing
                session.coachNotes = planned.notes ?? ""
                session.scheduledDate = planned.scheduledDate
                updated.append(session)
            } else {
                updated.append(StrengthSession(
                    id: UUID(),
                    planId: planId,
                    plannedSessionId: planned.id,
                    scheduledDate: planned.scheduledDate,
                    weekNumber: planned.weekNumber,
                    dayOfWeek: planned.dayOfWeek,
                    coachNotes: planned.notes ?? "",
                    isComplete: false
                ))
            }
        }

        sessions = updated
        saveToCache()
    }

    // MARK: - Toggle Completion

    func toggleComplete(_ sessionId: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].isComplete.toggle()
        saveToCache()
        Task { await persistSessionUpdate(sessions[index]) }
    }

    func markComplete(_ sessionId: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }),
              !sessions[index].isComplete else { return }
        sessions[index].isComplete = true
        saveToCache()
        Task { await persistSessionUpdate(sessions[index]) }
    }

    // MARK: - Load from Supabase

    func loadData(planId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        guard !isOffline else { return }

        do {
            sessions = try await supabase
                .from("strength_sessions")
                .select()
                .eq("plan_id", value: planId)
                .order("scheduled_date")
                .execute()
                .value

            saveToCache()
        } catch {
            lastError = "Failed to load strength data."
        }
    }

    // MARK: - Local Cache

    func saveToCache() {
        LocalCacheService.save(sessions, key: "strength_sessions")
    }

    @discardableResult
    func loadFromCache() -> Bool {
        guard let cached = LocalCacheService.load([StrengthSession].self, key: "strength_sessions") else { return false }
        sessions = cached
        return true
    }

    private func clearCache() {
        LocalCacheService.remove(key: "strength_sessions")
        // Clean up legacy cache keys
        LocalCacheService.remove(key: "strength_template")
        LocalCacheService.remove(key: "strength_exercises")
        LocalCacheService.remove(key: "strength_logs")
    }

    // MARK: - Clear

    func clearAll() {
        sessions = []
        clearCache()
    }

    // MARK: - Persistence

    private func persistAllSessions() async {
        guard !isOffline else { return }
        do {
            if !sessions.isEmpty {
                try await supabase.from("strength_sessions").upsert(sessions).execute()
            }
        } catch {
            print("Failed to persist strength sessions to Supabase: \(error)")
            lastError = "Failed to save strength sessions."
        }
    }

    private func persistSessionUpdate(_ session: StrengthSession) async {
        guard !isOffline else { return }
        do {
            try await supabase.from("strength_sessions")
                .update(session)
                .eq("id", value: session.id)
                .execute()
        } catch {
            print("Failed to persist session update to Supabase: \(error)")
            lastError = "Failed to save session update."
        }
    }
}
