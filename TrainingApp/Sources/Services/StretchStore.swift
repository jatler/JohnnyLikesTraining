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

        Task { await persistNewExercise(exercise) }
    }

    func updateExercise(_ exercise: StretchTemplateExercise) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        exercises[index] = exercise
        template?.updatedAt = Date()

        regenerateFutureSessions(for: exercise)

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
        Task { await persistLog(log) }
    }

    func removeLog(sessionId: UUID) {
        guard let log = logs.first(where: { $0.sessionId == sessionId }) else { return }
        logs.removeAll { $0.sessionId == sessionId }
        Task {
            do {
                try await supabase.from("stretch_logs")
                    .delete()
                    .eq("id", value: log.id)
                    .execute()
            } catch {
                lastError = "Failed to delete stretch log."
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

        do {
            let templates: [StretchTemplate] = try await supabase
                .from("stretch_templates")
                .select()
                .eq("plan_id", value: planId)
                .limit(1)
                .execute()
                .value

            guard let tmpl = templates.first else { return }
            template = tmpl

            exercises = try await supabase
                .from("stretch_template_exercises")
                .select()
                .eq("template_id", value: tmpl.id)
                .order("sort_order")
                .execute()
                .value

            sessions = try await supabase
                .from("stretch_sessions")
                .select()
                .eq("plan_id", value: planId)
                .order("scheduled_date")
                .execute()
                .value

            if !sessions.isEmpty {
                let sessionIds = sessions.map { $0.id.uuidString }
                logs = try await supabase
                    .from("stretch_logs")
                    .select()
                    .in("session_id", values: sessionIds)
                    .order("completed_at")
                    .execute()
                    .value
            }
        } catch {
            lastError = "Failed to load stretch data."
        }
    }

    // MARK: - Clear

    func clearAll() {
        template = nil
        exercises = []
        sessions = []
        logs = []
    }

    // MARK: - Persistence

    private func persistTemplate() async {
        guard let template else { return }
        do {
            try await supabase.from("stretch_templates").insert(template).execute()
            if !exercises.isEmpty {
                try await supabase.from("stretch_template_exercises").insert(exercises).execute()
            }
            if !sessions.isEmpty {
                try await supabase.from("stretch_sessions").insert(sessions).execute()
            }
        } catch {
            lastError = "Failed to save stretch template."
        }
    }

    private func persistExerciseUpdate(_ exercise: StretchTemplateExercise) async {
        do {
            try await supabase.from("stretch_template_exercises")
                .update(exercise)
                .eq("id", value: exercise.id)
                .execute()
        } catch {
            lastError = "Failed to save stretch exercise update."
        }
    }

    private func persistNewExercise(_ exercise: StretchTemplateExercise) async {
        do {
            try await supabase.from("stretch_template_exercises").insert(exercise).execute()
            await persistAllSessions()
        } catch {
            lastError = "Failed to save new stretch exercise."
        }
    }

    private func persistExerciseDelete(_ exercise: StretchTemplateExercise) async {
        do {
            try await supabase.from("stretch_template_exercises")
                .delete()
                .eq("id", value: exercise.id)
                .execute()

            try await supabase.from("stretch_sessions")
                .delete()
                .eq("template_exercise_id", value: exercise.id)
                .execute()
        } catch {
            lastError = "Failed to delete stretch exercise."
        }
    }

    private func persistAllSessions() async {
        guard let planId = template?.planId else { return }
        do {
            try await supabase.from("stretch_sessions")
                .delete()
                .eq("plan_id", value: planId)
                .execute()

            if !sessions.isEmpty {
                try await supabase.from("stretch_sessions").insert(sessions).execute()
            }
        } catch {
            lastError = "Failed to save stretch sessions."
        }
    }

    private func persistLog(_ log: StretchLog) async {
        do {
            try await supabase.from("stretch_logs").insert(log).execute()
        } catch {
            lastError = "Failed to save stretch log."
        }
    }
}
