import Foundation

@MainActor
@Observable
final class HeatStore {

    private(set) var sessions: [HeatSession] = []
    private(set) var logs: [HeatLog] = []
    private(set) var isLoading = false
    var lastError: String?

    private let supabase = SupabaseService.shared.client
    private var isOffline: Bool { SupabaseService.shared.isOffline }

    var hasSessions: Bool { !sessions.isEmpty }

    // MARK: - Query Helpers

    func sessions(for date: Date) -> [HeatSession] {
        sessions.filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: date) }
    }

    func sessions(for weekNumber: Int) -> [HeatSession] {
        sessions
            .filter { $0.weekNumber == weekNumber }
            .sorted { $0.dayOfWeek < $1.dayOfWeek }
    }

    func log(for sessionId: UUID) -> HeatLog? {
        logs.first { $0.sessionId == sessionId }
    }

    func isComplete(_ sessionId: UUID) -> Bool {
        logs.contains { $0.sessionId == sessionId }
    }

    func hasHeat(on date: Date) -> Bool {
        !sessions(for: date).isEmpty
    }

    func isHeatComplete(on date: Date) -> Bool {
        let daySessions = sessions(for: date)
        guard !daySessions.isEmpty else { return false }
        return daySessions.allSatisfy { isComplete($0.id) }
    }

    // MARK: - Initialize from Template

    func initializeFromTemplate(
        _ heatTemplates: [HeatSessionTemplate],
        planId: UUID,
        planStartDate: Date,
        totalWeeks: Int
    ) {
        let calendar = Calendar.current
        var newSessions: [HeatSession] = []

        for week in 1...totalWeeks {
            for template in heatTemplates {
                let dayOffset = (week - 1) * 7 + (template.day - 1)
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: planStartDate) else { continue }

                newSessions.append(HeatSession(
                    id: UUID(),
                    planId: planId,
                    scheduledDate: date,
                    weekNumber: week,
                    dayOfWeek: template.day,
                    sessionType: HeatType(rawValue: template.sessionType) ?? .sauna,
                    targetDurationMinutes: template.targetDurationMinutes,
                    notes: template.notes
                ))
            }
        }

        sessions = newSessions
        saveToCache()
        Task { await persistAllSessions(planId: planId) }
    }

    // MARK: - Log a Session

    func logSession(
        sessionId: UUID,
        durationMinutes: Int,
        sessionType: HeatType,
        notes: String? = nil
    ) {
        let log = HeatLog(
            id: UUID(),
            sessionId: sessionId,
            actualDurationMinutes: durationMinutes,
            sessionType: sessionType,
            completedAt: Date(),
            notes: notes
        )
        logs.append(log)
        saveToCache()
        Task { await persistLog(log) }
    }

    func addDay(
        dayOfWeek: Int,
        sessionType: HeatType,
        durationMinutes: Int,
        notes: String?,
        planId: UUID,
        planStartDate: Date,
        totalWeeks: Int
    ) {
        let calendar = Calendar.current
        var newSessions: [HeatSession] = []

        for week in 1...totalWeeks {
            let dayOffset = (week - 1) * 7 + (dayOfWeek - 1)
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: planStartDate) else { continue }

            newSessions.append(HeatSession(
                id: UUID(),
                planId: planId,
                scheduledDate: date,
                weekNumber: week,
                dayOfWeek: dayOfWeek,
                sessionType: sessionType,
                targetDurationMinutes: durationMinutes,
                notes: notes
            ))
        }

        sessions.append(contentsOf: newSessions)
        saveToCache()
        Task { await persistAllSessions(planId: planId) }
    }

    func removeDay(_ dayOfWeek: Int) {
        let removedIds = Set(sessions.filter { $0.dayOfWeek == dayOfWeek }.map(\.id))
        sessions.removeAll { $0.dayOfWeek == dayOfWeek }
        logs.removeAll { removedIds.contains($0.sessionId) }
        saveToCache()
        guard !isOffline else { return }

        if let planId = sessions.first?.planId {
            Task { await persistAllSessions(planId: planId) }
        } else {
            Task {
                for id in removedIds {
                    let result = await SupabaseService.shared.execute(table: "heat_sessions", operation: "delete") {
                        try await supabase.from("heat_sessions")
                            .delete()
                            .eq("id", value: id)
                            .execute()
                    }
                    if case .failure(let err) = result, !err.isRetryable {
                        lastError = err.userFacing
                    }
                }
            }
        }
    }

    // MARK: - Edit Sessions

    func updateSession(_ session: HeatSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        var updated = session
        updated.isTemplateOverride = true
        sessions[index] = updated
        saveToCache()
        Task { await persistSessionUpdate(updated) }
    }

    func updateAllSessions(dayOfWeek: Int, sessionType: HeatType, durationMinutes: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        for i in sessions.indices where sessions[i].dayOfWeek == dayOfWeek
            && !sessions[i].isTemplateOverride
            && sessions[i].scheduledDate >= today {
            sessions[i].sessionType = sessionType
            sessions[i].targetDurationMinutes = durationMinutes
        }
        saveToCache()
        if let planId = sessions.first?.planId {
            Task { await persistAllSessions(planId: planId) }
        }
    }

    private func persistSessionUpdate(_ session: HeatSession) async {
        guard !isOffline else { return }
        let result = await SupabaseService.shared.execute(table: "heat_sessions", operation: "upsert") {
            try await supabase.from("heat_sessions")
                .upsert(session, onConflict: "id")
                .execute()
        }
        if case .failure(let err) = result, !err.isRetryable {
            lastError = err.userFacing
        }
    }

    // MARK: - Skip / Unskip

    func skipSession(_ sessionId: UUID, reason: String?) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].isSkipped = true
        sessions[index].skipReason = reason
        saveToCache()
        Task { await persistSessionUpdate(sessions[index]) }
    }

    func unskipSession(_ sessionId: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].isSkipped = false
        sessions[index].skipReason = nil
        saveToCache()
        Task { await persistSessionUpdate(sessions[index]) }
    }

    func isSkipped(_ sessionId: UUID) -> Bool {
        sessions.first(where: { $0.id == sessionId })?.isSkipped ?? false
    }

    // MARK: - Move to a Different Day

    func moveToDay(_ sessionId: UUID, dayOfWeek newDay: Int) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        let oldDay = sessions[index].dayOfWeek
        guard newDay != oldDay, (1...7).contains(newDay) else { return }
        let delta = newDay - oldDay
        let calendar = Calendar.current
        guard let newDate = calendar.date(byAdding: .day, value: delta, to: sessions[index].scheduledDate) else { return }
        sessions[index].dayOfWeek = newDay
        sessions[index].scheduledDate = newDate
        saveToCache()
        Task { await persistSessionUpdate(sessions[index]) }
    }

    func deleteLog(_ sessionId: UUID) {
        guard let log = logs.first(where: { $0.sessionId == sessionId }) else { return }
        logs.removeAll { $0.sessionId == sessionId }
        saveToCache()
        guard !isOffline else { return }

        Task {
            let result = await SupabaseService.shared.execute(table: "heat_logs", operation: "delete") {
                try await supabase.from("heat_logs")
                    .delete()
                    .eq("id", value: log.id)
                    .execute()
            }
            if case .failure(let err) = result, !err.isRetryable {
                lastError = err.userFacing
            }
        }
    }

    // MARK: - Load from Supabase

    func loadData(planId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        guard !isOffline else { return }

        let result = await SupabaseService.shared.execute(table: "heat_sessions", operation: "select") {
            () -> ([HeatSession], [HeatLog]) in
            let loadedSessions: [HeatSession] = try await supabase
                .from("heat_sessions")
                .select()
                .eq("plan_id", value: planId)
                .order("scheduled_date")
                .execute()
                .value

            var loadedLogs: [HeatLog] = []
            if !loadedSessions.isEmpty {
                let sessionIds = loadedSessions.map { $0.id.uuidString }
                loadedLogs = try await supabase
                    .from("heat_logs")
                    .select()
                    .in("session_id", values: sessionIds)
                    .order("completed_at")
                    .execute()
                    .value
            }
            return (loadedSessions, loadedLogs)
        }
        switch result {
        case .success(let (loadedSessions, loadedLogs)):
            sessions = loadedSessions
            logs = loadedLogs
            saveToCache()
        case .failure(let err):
            if !err.isRetryable {
                lastError = err.userFacing
            }
        }
    }

    // MARK: - Local Cache

    func saveToCache() {
        LocalCacheService.save(sessions, key: "heat_sessions")
        LocalCacheService.save(logs, key: "heat_logs")
    }

    @discardableResult
    func loadFromCache() -> Bool {
        guard let cached = LocalCacheService.load([HeatSession].self, key: "heat_sessions"), !cached.isEmpty else { return false }
        sessions = cached
        logs = LocalCacheService.load([HeatLog].self, key: "heat_logs") ?? []
        return true
    }

    private func clearCache() {
        LocalCacheService.remove(key: "heat_sessions")
        LocalCacheService.remove(key: "heat_logs")
    }

    // MARK: - Clear

    func clearAll() {
        sessions = []
        logs = []
        clearCache()
    }

    // MARK: - Persistence

    private func persistAllSessions(planId: UUID) async {
        guard !isOffline, !sessions.isEmpty else { return }
        // Background bulk-sync — silent on retryable failure (cache holds truth).
        // Surface only non-retryable PostgREST errors so the user knows when
        // it's a real problem (RLS, constraint violation).
        let result = await SupabaseService.shared.execute(table: "heat_sessions", operation: "upsert") {
            try await supabase.from("heat_sessions")
                .upsert(sessions, onConflict: "id")
                .execute()
        }
        if case .failure(let err) = result, !err.isRetryable {
            lastError = err.userFacing
        }
    }

    private func persistLog(_ log: HeatLog) async {
        guard !isOffline else { return }
        let result = await SupabaseService.shared.execute(table: "heat_logs", operation: "insert") {
            try await supabase.from("heat_logs").insert(log).execute()
        }
        if case .failure(let err) = result, !err.isRetryable {
            lastError = err.userFacing
        }
    }
}
