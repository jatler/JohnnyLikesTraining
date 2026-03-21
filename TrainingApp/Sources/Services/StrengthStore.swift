import Foundation

@MainActor
@Observable
final class StrengthStore {

    private(set) var template: StrengthTemplate?
    private(set) var exercises: [StrengthTemplateExercise] = []
    private(set) var sessions: [StrengthSession] = []
    private(set) var logs: [StrengthLog] = []
    private(set) var suggestions: [ProgressionSuggestion] = []
    private(set) var isLoading = false

    private let supabase = SupabaseService.shared.client

    var hasTemplate: Bool { template != nil }

    // MARK: - Query Helpers

    func exercises(for dayOfWeek: Int) -> [StrengthTemplateExercise] {
        exercises
            .filter { $0.dayOfWeek == dayOfWeek }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var daysWithExercises: [Int] {
        Array(Set(exercises.map(\.dayOfWeek))).sorted()
    }

    func sessions(for date: Date) -> [StrengthSession] {
        sessions
            .filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: date) }
            .sorted { $0.exerciseName < $1.exerciseName }
    }

    func sessions(for weekNumber: Int, dayOfWeek: Int) -> [StrengthSession] {
        sessions
            .filter { $0.weekNumber == weekNumber && $0.dayOfWeek == dayOfWeek }
            .sorted { $0.exerciseName < $1.exerciseName }
    }

    func logs(for sessionId: UUID) -> [StrengthLog] {
        logs
            .filter { $0.sessionId == sessionId }
            .sorted { $0.setNumber < $1.setNumber }
    }

    func allLogs(for exerciseName: String) -> [StrengthLog] {
        let matchingSessionIds = Set(
            sessions.filter { $0.exerciseName == exerciseName }.map(\.id)
        )
        return logs
            .filter { matchingSessionIds.contains($0.sessionId) }
            .sorted { $0.completedAt < $1.completedAt }
    }

    func isSessionComplete(_ sessionId: UUID) -> Bool {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return false }
        let sessionLogs = logs(for: sessionId)
        return sessionLogs.count >= session.prescribedSets
    }

    func completedExerciseCount(for date: Date) -> Int {
        let daySessions = sessions(for: date)
        return daySessions.filter { isSessionComplete($0.id) }.count
    }

    func totalExerciseCount(for date: Date) -> Int {
        sessions(for: date).count
    }

    // MARK: - Initialize from Template

    func initializeFromTemplate(
        _ strengthExercises: [StrengthExerciseTemplate],
        planId: UUID,
        planStartDate: Date,
        totalWeeks: Int
    ) {
        let now = Date()
        let templateId = UUID()

        let newTemplate = StrengthTemplate(
            id: templateId,
            planId: planId,
            createdAt: now,
            updatedAt: now
        )

        let newExercises = strengthExercises.map { ex in
            StrengthTemplateExercise(
                id: UUID(),
                templateId: templateId,
                dayOfWeek: ex.day,
                exerciseName: ex.exerciseName,
                targetSets: ex.targetSets,
                targetReps: ex.targetReps,
                targetWeightKg: ex.targetWeightKg,
                targetRpe: ex.targetRpe,
                isBodyweight: ex.isBodyweight,
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
        exercises: [StrengthTemplateExercise],
        planId: UUID,
        planStartDate: Date,
        totalWeeks: Int
    ) -> [StrengthSession] {
        let calendar = Calendar.current
        var result: [StrengthSession] = []

        for week in 1...totalWeeks {
            let isDeload = ProgressionEngine.isDeloadWeek(week)

            for exercise in exercises {
                let dayOffset = (week - 1) * 7 + (exercise.dayOfWeek - 1)
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: planStartDate) else { continue }

                var sets = exercise.targetSets
                var reps = exercise.targetReps
                let weight = exercise.targetWeightKg

                if isDeload {
                    let deloaded = ProgressionEngine.applyDeload(sets: sets, reps: reps, weightKg: weight)
                    sets = deloaded.sets
                    reps = deloaded.reps
                }

                result.append(StrengthSession(
                    id: UUID(),
                    planId: planId,
                    templateExerciseId: exercise.id,
                    scheduledDate: date,
                    weekNumber: week,
                    dayOfWeek: exercise.dayOfWeek,
                    exerciseName: exercise.exerciseName,
                    prescribedSets: sets,
                    prescribedReps: reps,
                    prescribedWeightKg: weight,
                    prescribedRpe: exercise.targetRpe,
                    isDeload: isDeload,
                    isTemplateOverride: false
                ))
            }
        }

        return result
    }

    // MARK: - Update Template Exercise

    func updateExercise(_ exercise: StrengthTemplateExercise, propagateToFuture: Bool = true) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        exercises[index] = exercise
        template?.updatedAt = Date()

        if propagateToFuture {
            regenerateFutureSessions(for: exercise)
        }

        Task { await persistExerciseUpdate(exercise) }
    }

    func addExercise(
        dayOfWeek: Int,
        name: String,
        sets: Int,
        reps: Int,
        weightKg: Double?,
        isBodyweight: Bool,
        rpe: Double?,
        notes: String?
    ) {
        guard let templateId = template?.id else { return }

        let sortOrder = exercises.filter { $0.dayOfWeek == dayOfWeek }.count + 1
        let exercise = StrengthTemplateExercise(
            id: UUID(),
            templateId: templateId,
            dayOfWeek: dayOfWeek,
            exerciseName: name,
            targetSets: sets,
            targetReps: reps,
            targetWeightKg: weightKg,
            targetRpe: rpe,
            isBodyweight: isBodyweight,
            sortOrder: sortOrder,
            notes: notes
        )

        exercises.append(exercise)
        regenerateFutureSessions(for: exercise)

        Task { await persistNewExercise(exercise) }
    }

    func removeExercise(_ exercise: StrengthTemplateExercise) {
        exercises.removeAll { $0.id == exercise.id }

        sessions.removeAll { session in
            session.templateExerciseId == exercise.id
                && !session.isTemplateOverride
                && session.scheduledDate >= Calendar.current.startOfDay(for: Date())
        }

        Task { await persistExerciseDelete(exercise) }
    }

    // MARK: - One-Off Session Edit

    func updateSession(_ session: StrengthSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        var updated = session
        updated.isTemplateOverride = true
        sessions[index] = updated

        Task { await persistSessionUpdate(updated) }
    }

    // MARK: - Log a Set

    func logSet(
        sessionId: UUID,
        setNumber: Int,
        reps: Int,
        weightKg: Double?,
        rpe: Double?,
        notes: String? = nil
    ) {
        let log = StrengthLog(
            id: UUID(),
            sessionId: sessionId,
            setNumber: setNumber,
            actualReps: reps,
            actualWeightKg: weightKg,
            rpe: rpe,
            completedAt: Date(),
            notes: notes
        )
        logs.append(log)

        Task { await persistLog(log) }
    }

    func deleteLog(_ logId: UUID) {
        logs.removeAll { $0.id == logId }

        Task {
            do {
                try await supabase.from("strength_logs")
                    .delete()
                    .eq("id", value: logId)
                    .execute()
            } catch {
                print("Failed to delete log: \(error)")
            }
        }
    }

    // MARK: - Progression Suggestions

    func computeSuggestions(
        runningSessions: [PlannedSession],
        ouraData: [OuraDaily],
        currentWeek: Int
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let recentReadiness = ouraData.filter {
            let daysBefore = calendar.dateComponents([.day], from: $0.date, to: today).day ?? 0
            return daysBefore >= 0 && daysBefore <= 7
        }

        let weeklyDistance = ProgressionEngine.weeklyRunDistance(
            sessions: runningSessions,
            weekNumber: currentWeek
        )

        var newSuggestions: [ProgressionSuggestion] = []

        for exercise in exercises {
            let recentLogs = recentLogsForExercise(exercise, weeksBack: 2)

            if let suggestion = ProgressionEngine.suggest(
                for: exercise,
                logs: recentLogs,
                weeklyRunDistanceKm: weeklyDistance,
                recentReadiness: recentReadiness,
                currentWeek: currentWeek
            ) {
                newSuggestions.append(suggestion)
            }
        }

        suggestions = newSuggestions
    }

    func acceptSuggestion(_ suggestion: ProgressionSuggestion) {
        guard let index = exercises.firstIndex(where: { $0.exerciseName == suggestion.exerciseName }) else { return }

        exercises[index].targetSets = suggestion.suggestedSets
        exercises[index].targetReps = suggestion.suggestedReps
        exercises[index].targetWeightKg = suggestion.suggestedWeightKg

        regenerateFutureSessions(for: exercises[index])
        suggestions.removeAll { $0.exerciseName == suggestion.exerciseName }

        Task { await persistExerciseUpdate(exercises[index]) }
    }

    func dismissSuggestion(_ suggestion: ProgressionSuggestion) {
        suggestions.removeAll { $0.id == suggestion.id }
    }

    // MARK: - Regenerate Future Sessions

    private func regenerateFutureSessions(for exercise: StrengthTemplateExercise) {
        guard let plan = template,
              let planId = Optional(plan.planId) else { return }

        let today = Calendar.current.startOfDay(for: Date())

        sessions.removeAll { session in
            session.templateExerciseId == exercise.id
                && !session.isTemplateOverride
                && session.scheduledDate >= today
        }

        let futureSessions = sessions.filter { $0.scheduledDate >= today }
        let futureWeeks = Set(futureSessions.map(\.weekNumber))

        let allWeeks: Set<Int>
        if let maxWeek = sessions.map(\.weekNumber).max() {
            allWeeks = Set(1...maxWeek).union(futureWeeks)
        } else {
            allWeeks = futureWeeks
        }

        let calendar = Calendar.current
        for week in allWeeks.sorted() {
            guard let existingSession = sessions.first(where: { $0.weekNumber == week }),
                  let firstSessionDate = Optional(existingSession.scheduledDate),
                  let weekStart = calendar.date(byAdding: .day, value: -(existingSession.dayOfWeek - 1), to: firstSessionDate),
                  let date = calendar.date(byAdding: .day, value: exercise.dayOfWeek - 1, to: weekStart)
            else { continue }

            guard date >= today else { continue }

            let isDeload = ProgressionEngine.isDeloadWeek(week)
            var sets = exercise.targetSets
            let reps = exercise.targetReps
            let weight = exercise.targetWeightKg

            if isDeload {
                sets = ProgressionEngine.applyDeload(sets: sets, reps: reps, weightKg: weight).sets
            }

            let newSession = StrengthSession(
                id: UUID(),
                planId: planId,
                templateExerciseId: exercise.id,
                scheduledDate: date,
                weekNumber: week,
                dayOfWeek: exercise.dayOfWeek,
                exerciseName: exercise.exerciseName,
                prescribedSets: sets,
                prescribedReps: reps,
                prescribedWeightKg: weight,
                prescribedRpe: exercise.targetRpe,
                isDeload: isDeload,
                isTemplateOverride: false
            )
            sessions.append(newSession)
        }

        Task { await persistAllSessions() }
    }

    private func recentLogsForExercise(_ exercise: StrengthTemplateExercise, weeksBack: Int) -> [StrengthLog] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let cutoff = calendar.date(byAdding: .day, value: -(weeksBack * 7), to: today) else { return [] }

        let matchingSessions = sessions.filter {
            $0.exerciseName == exercise.exerciseName
                && $0.scheduledDate >= cutoff
                && $0.scheduledDate < today
        }
        let sessionIds = Set(matchingSessions.map(\.id))
        return logs.filter { sessionIds.contains($0.sessionId) }
    }

    // MARK: - Load from Supabase

    func loadData(planId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let templates: [StrengthTemplate] = try await supabase
                .from("strength_templates")
                .select()
                .eq("plan_id", value: planId)
                .limit(1)
                .execute()
                .value

            guard let tmpl = templates.first else { return }
            template = tmpl

            exercises = try await supabase
                .from("strength_template_exercises")
                .select()
                .eq("template_id", value: tmpl.id)
                .order("sort_order")
                .execute()
                .value

            sessions = try await supabase
                .from("strength_sessions")
                .select()
                .eq("plan_id", value: planId)
                .order("scheduled_date")
                .execute()
                .value

            if !sessions.isEmpty {
                let sessionIds = sessions.map { $0.id.uuidString }
                logs = try await supabase
                    .from("strength_logs")
                    .select()
                    .in("session_id", values: sessionIds)
                    .order("completed_at")
                    .execute()
                    .value
            }
        } catch {
            print("Failed to load strength data: \(error)")
        }
    }

    // MARK: - Clear

    func clearAll() {
        template = nil
        exercises = []
        sessions = []
        logs = []
        suggestions = []
    }

    // MARK: - Persistence

    private func persistTemplate() async {
        guard let template else { return }
        do {
            try await supabase.from("strength_templates").insert(template).execute()
            if !exercises.isEmpty {
                try await supabase.from("strength_template_exercises").insert(exercises).execute()
            }
            if !sessions.isEmpty {
                try await supabase.from("strength_sessions").insert(sessions).execute()
            }
        } catch {
            print("Failed to persist strength template: \(error)")
        }
    }

    private func persistExerciseUpdate(_ exercise: StrengthTemplateExercise) async {
        do {
            try await supabase.from("strength_template_exercises")
                .update(exercise)
                .eq("id", value: exercise.id)
                .execute()
        } catch {
            print("Failed to update exercise: \(error)")
        }
    }

    private func persistNewExercise(_ exercise: StrengthTemplateExercise) async {
        do {
            try await supabase.from("strength_template_exercises").insert(exercise).execute()
            await persistAllSessions()
        } catch {
            print("Failed to persist new exercise: \(error)")
        }
    }

    private func persistExerciseDelete(_ exercise: StrengthTemplateExercise) async {
        do {
            try await supabase.from("strength_template_exercises")
                .delete()
                .eq("id", value: exercise.id)
                .execute()

            try await supabase.from("strength_sessions")
                .delete()
                .eq("template_exercise_id", value: exercise.id)
                .execute()
        } catch {
            print("Failed to delete exercise: \(error)")
        }
    }

    private func persistSessionUpdate(_ session: StrengthSession) async {
        do {
            try await supabase.from("strength_sessions")
                .update(session)
                .eq("id", value: session.id)
                .execute()
        } catch {
            print("Failed to update session: \(error)")
        }
    }

    private func persistAllSessions() async {
        guard let planId = template?.planId else { return }
        do {
            try await supabase.from("strength_sessions")
                .delete()
                .eq("plan_id", value: planId)
                .execute()

            if !sessions.isEmpty {
                try await supabase.from("strength_sessions").insert(sessions).execute()
            }
        } catch {
            print("Failed to persist sessions: \(error)")
        }
    }

    private func persistLog(_ log: StrengthLog) async {
        do {
            try await supabase.from("strength_logs").insert(log).execute()
        } catch {
            print("Failed to persist log: \(error)")
        }
    }
}
