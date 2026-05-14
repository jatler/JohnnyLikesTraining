import Foundation

@MainActor
@Observable
final class StretchStore {

    private(set) var template: StretchTemplate?
    private(set) var exercises: [StretchTemplateExercise] = []
    private(set) var sessions: [StretchSession] = []
    private(set) var logs: [StretchLog] = []
    private(set) var isLoading = false
    var lastError: String?

    private let supabase = SupabaseService.shared.client
    private var isOffline: Bool { SupabaseService.shared.isOffline }

    var hasTemplate: Bool { template != nil }

    // MARK: - Query Helpers

    func exercises(for dayOfWeek: Int) -> [StretchTemplateExercise] {
        exercises
            .filter { $0.dayOfWeek == dayOfWeek }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var daysWithExercises: [Int] {
        Array(Set(exercises.map(\.dayOfWeek))).sorted()
    }

    func sessions(for date: Date) -> [StretchSession] {
        sessions
            .filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: date) }
            .sorted { $0.stretchName < $1.stretchName }
    }

    func sessions(for weekNumber: Int, dayOfWeek: Int) -> [StretchSession] {
        sessions
            .filter { $0.weekNumber == weekNumber && $0.dayOfWeek == dayOfWeek }
            .sorted { $0.stretchName < $1.stretchName }
    }

    func isComplete(_ sessionId: UUID) -> Bool {
        logs.contains { $0.sessionId == sessionId }
    }

    func completedCount(for date: Date) -> Int {
        let daySessions = sessions(for: date)
        return daySessions.filter { isComplete($0.id) }.count
    }

    func totalCount(for date: Date) -> Int {
        sessions(for: date).count
    }

    func hasStretch(on date: Date) -> Bool {
        !sessions(for: date).isEmpty
    }

    func isAllComplete(on date: Date) -> Bool {
        let daySessions = sessions(for: date)
        guard !daySessions.isEmpty else { return false }
        return daySessions.allSatisfy { isComplete($0.id) }
    }

    func createBlankTemplate(planId: UUID) {
        let now = Date()
        let templateId = UUID()
        template = StretchTemplate(
            id: templateId,
            planId: planId,
            createdAt: now,
            updatedAt: now
        )
        exercises = []
        sessions = []
        saveToCache()
        Task { await persistTemplate() }
    }

    // MARK: - Initialize from Template

    func initializeFromTemplate(
        _ stretchExercises: [StretchExerciseTemplate],
        planId: UUID,
        planStartDate: Date,
        totalWeeks: Int
    ) {
        let now = Date()
        let templateId = UUID()

        let newTemplate = StretchTemplate(
            id: templateId,
            planId: planId,
            createdAt: now,
            updatedAt: now
        )

        let newExercises = stretchExercises.map { ex in
            StretchTemplateExercise(
                id: UUID(),
                templateId: templateId,
                dayOfWeek: ex.day,
                stretchName: ex.stretchName,
                holdSeconds: ex.holdSeconds,
                sets: ex.sets,
                isBilateral: ex.isBilateral,
                sortOrder: ex.sortOrder,
                notes: ex.notes
            )
        }

        template = newTemplate
        exercises = newExercises
        sessions = generateAllSessions(
            exercises: newExercises,
            planId: planId,
            planStartDate: planStartDate,
            totalWeeks: totalWeeks
        )
        saveToCache()

        Task { await persistTemplate() }
    }

    // MARK: - Generate Sessions from Exercises

    private func generateAllSessions(
        exercises: [StretchTemplateExercise],
        planId: UUID,
        planStartDate: Date,
        totalWeeks: Int
    ) -> [StretchSession] {
        let calendar = Calendar.current
        var result: [StretchSession] = []

        for week in 1...totalWeeks {
            for exercise in exercises {
                let dayOffset = (week - 1) * 7 + (exercise.dayOfWeek - 1)
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: planStartDate) else { continue }

                result.append(StretchSession(
                    id: UUID(),
                    planId: planId,
                    templateExerciseId: exercise.id,
                    scheduledDate: date,
                    weekNumber: week,
                    dayOfWeek: exercise.dayOfWeek,
                    stretchName: exercise.stretchName,
                    prescribedHoldSeconds: exercise.holdSeconds,
                    prescribedSets: exercise.sets,
                    isBilateral: exercise.isBilateral
                ))
            }
        }

        return result
    }

    // MARK: - Template Exercise Management

    func addExercise(
        dayOfWeek: Int,
        name: String,
        holdSeconds: Int,
        sets: Int,
        isBilateral: Bool,
        notes: String?
    ) {
        guard let templateId = template?.id else { return }

        let sortOrder = exercises.filter { $0.dayOfWeek == dayOfWeek }.count + 1
        let exercise = StretchTemplateExercise(
            id: UUID(),
            templateId: templateId,
            dayOfWeek: dayOfWeek,
            stretchName: name,
            holdSeconds: holdSeconds,
            sets: sets,
            isBilateral: isBilateral,
            sortOrder: sortOrder,
            notes: notes
        )

        exercises.append(exercise)
        regenerateFutureSessions(for: exercise)
        saveToCache()

        Task { await persistNewExercise(exercise) }
    }

    func updateExercise(_ exercise: StretchTemplateExercise) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        exercises[index] = exercise
        template?.updatedAt = Date()

        regenerateFutureSessions(for: exercise)
        saveToCache()

        Task { await persistExerciseUpdate(exercise) }
    }

    func removeExercise(_ exercise: StretchTemplateExercise) {
        exercises.removeAll { $0.id == exercise.id }

        let removedIds = Set(
            sessions
                .filter { $0.templateExerciseId == exercise.id }
                .map(\.id)
        )
        sessions.removeAll { $0.templateExerciseId == exercise.id }
        logs.removeAll { removedIds.contains($0.sessionId) }
        saveToCache()

        Task { await persistExerciseDelete(exercise) }
    }

    // MARK: - Log Completion

    func logCompletion(sessionId: UUID, notes: String? = nil) {
        guard !isComplete(sessionId) else { return }
        let log = StretchLog(
            id: UUID(),
            sessionId: sessionId,
            completedAt: Date(),
            notes: notes
        )
        logs.append(log)
        saveToCache()
        Task { await persistLog(log) }
    }

    func removeLog(sessionId: UUID) {
        guard let log = logs.first(where: { $0.sessionId == sessionId }) else { return }
        logs.removeAll { $0.sessionId == sessionId }
        saveToCache()
        guard !isOffline else { return }

        Task {
            let result = await SupabaseService.shared.execute(table: "stretch_logs", operation: "delete") {
                try await supabase.from("stretch_logs")
                    .delete()
                    .eq("id", value: log.id)
                    .execute()
            }
            if case .failure(let err) = result, !err.isRetryable {
                lastError = err.userFacing
            }
        }
    }

    // MARK: - Regenerate Future Sessions

    private func regenerateFutureSessions(for exercise: StretchTemplateExercise) {
        guard let plan = template,
              let planId = Optional(plan.planId) else { return }

        let today = Calendar.current.startOfDay(for: Date())

        sessions.removeAll { session in
            session.templateExerciseId == exercise.id
                && session.scheduledDate >= today
        }

        let allWeeks: Set<Int>
        if let maxWeek = sessions.map(\.weekNumber).max() {
            allWeeks = Set(1...maxWeek)
        } else {
            allWeeks = []
        }

        let calendar = Calendar.current
        for week in allWeeks.sorted() {
            guard let existingSession = sessions.first(where: { $0.weekNumber == week }),
                  let weekStart = calendar.date(
                    byAdding: .day,
                    value: -(existingSession.dayOfWeek - 1),
                    to: existingSession.scheduledDate
                  ),
                  let date = calendar.date(byAdding: .day, value: exercise.dayOfWeek - 1, to: weekStart)
            else { continue }

            guard date >= today else { continue }

            let newSession = StretchSession(
                id: UUID(),
                planId: planId,
                templateExerciseId: exercise.id,
                scheduledDate: date,
                weekNumber: week,
                dayOfWeek: exercise.dayOfWeek,
                stretchName: exercise.stretchName,
                prescribedHoldSeconds: exercise.holdSeconds,
                prescribedSets: exercise.sets,
                isBilateral: exercise.isBilateral
            )
            sessions.append(newSession)
        }

        Task { await persistAllSessions() }
    }

    // MARK: - Load from Supabase

    func loadData(planId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        guard !isOffline else { return }

        let result = await SupabaseService.shared.execute(table: "stretch_templates", operation: "select") {
            () -> (StretchTemplate?, [StretchTemplateExercise], [StretchSession], [StretchLog]) in
            let templates: [StretchTemplate] = try await supabase
                .from("stretch_templates")
                .select()
                .eq("plan_id", value: planId)
                .limit(1)
                .execute()
                .value

            guard let tmpl = templates.first else {
                return (nil, [], [], [])
            }

            let loadedExercises: [StretchTemplateExercise] = try await supabase
                .from("stretch_template_exercises")
                .select()
                .eq("template_id", value: tmpl.id)
                .order("sort_order")
                .execute()
                .value

            let loadedSessions: [StretchSession] = try await supabase
                .from("stretch_sessions")
                .select()
                .eq("plan_id", value: planId)
                .order("scheduled_date")
                .execute()
                .value

            var loadedLogs: [StretchLog] = []
            if !loadedSessions.isEmpty {
                let sessionIds = loadedSessions.map { $0.id.uuidString }
                loadedLogs = try await supabase
                    .from("stretch_logs")
                    .select()
                    .in("session_id", values: sessionIds)
                    .order("completed_at")
                    .execute()
                    .value
            }
            return (tmpl, loadedExercises, loadedSessions, loadedLogs)
        }
        switch result {
        case .success(let (loadedTemplate, loadedExercises, loadedSessions, loadedLogs)):
            guard let loadedTemplate else { return }
            template = loadedTemplate
            exercises = loadedExercises
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
        LocalCacheService.save(template, key: "stretch_template")
        LocalCacheService.save(exercises, key: "stretch_exercises")
        LocalCacheService.save(sessions, key: "stretch_sessions")
        LocalCacheService.save(logs, key: "stretch_logs")
    }

    @discardableResult
    func loadFromCache() -> Bool {
        guard let cached = LocalCacheService.load(StretchTemplate.self, key: "stretch_template") else { return false }
        template = cached
        exercises = LocalCacheService.load([StretchTemplateExercise].self, key: "stretch_exercises") ?? []
        sessions = LocalCacheService.load([StretchSession].self, key: "stretch_sessions") ?? []
        logs = LocalCacheService.load([StretchLog].self, key: "stretch_logs") ?? []
        return true
    }

    private func clearCache() {
        LocalCacheService.remove(key: "stretch_template")
        LocalCacheService.remove(key: "stretch_exercises")
        LocalCacheService.remove(key: "stretch_sessions")
        LocalCacheService.remove(key: "stretch_logs")
    }

    // MARK: - Clear

    func clearAll() {
        template = nil
        exercises = []
        sessions = []
        logs = []
        clearCache()
    }

    // MARK: - Persistence

    private func persistTemplate() async {
        guard !isOffline, let template else { return }
        let result = await SupabaseService.shared.execute(table: "stretch_templates", operation: "upsert") {
            () -> Void in
            try await supabase.from("stretch_templates")
                .upsert(template, onConflict: "id")
                .execute()
            if !exercises.isEmpty {
                try await supabase.from("stretch_template_exercises")
                    .upsert(exercises, onConflict: "id")
                    .execute()
            }
            if !sessions.isEmpty {
                try await supabase.from("stretch_sessions")
                    .upsert(sessions, onConflict: "id")
                    .execute()
            }
        }
        if case .failure(let err) = result, !err.isRetryable {
            lastError = err.userFacing
        }
    }

    private func persistExerciseUpdate(_ exercise: StretchTemplateExercise) async {
        guard !isOffline else { return }
        let result = await SupabaseService.shared.execute(table: "stretch_template_exercises", operation: "update") {
            try await supabase.from("stretch_template_exercises")
                .update(exercise)
                .eq("id", value: exercise.id)
                .execute()
        }
        if case .failure(let err) = result, !err.isRetryable {
            lastError = err.userFacing
        }
    }

    private func persistNewExercise(_ exercise: StretchTemplateExercise) async {
        guard !isOffline else { return }
        let result = await SupabaseService.shared.execute(table: "stretch_template_exercises", operation: "insert") {
            try await supabase.from("stretch_template_exercises").insert(exercise).execute()
        }
        switch result {
        case .success:
            await persistAllSessions()
        case .failure(let err):
            if !err.isRetryable {
                lastError = err.userFacing
            }
        }
    }

    private func persistExerciseDelete(_ exercise: StretchTemplateExercise) async {
        guard !isOffline else { return }
        let result = await SupabaseService.shared.execute(table: "stretch_template_exercises", operation: "delete") {
            () -> Void in
            try await supabase.from("stretch_template_exercises")
                .delete()
                .eq("id", value: exercise.id)
                .execute()

            try await supabase.from("stretch_sessions")
                .delete()
                .eq("template_exercise_id", value: exercise.id)
                .execute()
        }
        if case .failure(let err) = result, !err.isRetryable {
            lastError = err.userFacing
        }
    }

    private func persistAllSessions() async {
        guard !isOffline, template?.planId != nil, !sessions.isEmpty else { return }
        let result = await SupabaseService.shared.execute(table: "stretch_sessions", operation: "upsert") {
            try await supabase.from("stretch_sessions")
                .upsert(sessions, onConflict: "id")
                .execute()
        }
        if case .failure(let err) = result, !err.isRetryable {
            lastError = err.userFacing
        }
    }

    private func persistLog(_ log: StretchLog) async {
        guard !isOffline else { return }
        let result = await SupabaseService.shared.execute(table: "stretch_logs", operation: "insert") {
            try await supabase.from("stretch_logs").insert(log).execute()
        }
        if case .failure(let err) = result, !err.isRetryable {
            lastError = err.userFacing
        }
    }
}
