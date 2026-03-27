import Foundation

@MainActor
@Observable
final class TrainingPlanStore {

    private(set) var activePlan: TrainingPlan?
    private(set) var sessions: [PlannedSession] = []
    private(set) var skips: [SessionSkip] = []
    private(set) var swaps: [SessionSwap] = []
    private(set) var overrides: [SessionOverride] = []
    private(set) var isLoading = false
    var lastError: String?

    private let supabase = SupabaseService.shared.client

    var hasPlan: Bool { activePlan != nil }

    // MARK: - Computed Helpers

    var todaySessions: [PlannedSession] {
        let today = Calendar.current.startOfDay(for: Date())
        return sessions
            .filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: today) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func sessions(for weekNumber: Int) -> [PlannedSession] {
        sessions
            .filter { $0.weekNumber == weekNumber }
            .sorted { ($0.dayOfWeek, $0.sortOrder) < ($1.dayOfWeek, $1.sortOrder) }
    }

    var currentWeekNumber: Int? {
        guard let plan = activePlan else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: plan.planStartDate)
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        guard days >= 0 else { return nil }
        let week = (days / 7) + 1
        return week <= totalWeeks ? week : nil
    }

    var allWeekNumbers: [Int] {
        Array(Set(sessions.map(\.weekNumber))).sorted()
    }

    var totalWeeks: Int {
        allWeekNumbers.max() ?? 0
    }

    var currentTemplate: TrainingPlanTemplate? {
        guard let sourceFile = activePlan?.sourceFileName else { return nil }
        let templateId = sourceFile.replacingOccurrences(of: ".json", with: "")
        return PlanTemplateService.shared.availableTemplates.first { $0.id == templateId }
    }

    func sessions(for date: Date) -> [PlannedSession] {
        sessions
            .filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: date) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func strengthSession(for session: PlannedSession) -> PlannedSession? {
        sessions.first {
            $0.weekNumber == session.weekNumber
                && $0.dayOfWeek == session.dayOfWeek
                && $0.workoutType == .strength
                && $0.id != session.id
        }
    }

    func isSkipped(_ sessionId: UUID) -> Bool {
        skips.contains { $0.sessionId == sessionId }
    }

    func isOverridden(_ sessionId: UUID) -> Bool {
        overrides.contains { $0.sessionId == sessionId }
    }

    func override(for sessionId: UUID) -> SessionOverride? {
        overrides.first { $0.sessionId == sessionId }
    }

    /// Nearest easy, recovery, or rest day in the same week — for quick swap.
    func nearestEasyDay(for session: PlannedSession) -> PlannedSession? {
        sessions(for: session.weekNumber)
            .filter { $0.id != session.id
                && ($0.workoutType == .easy || $0.workoutType == .rest || $0.workoutType == .recovery)
                && !isSkipped($0.id)
            }
            .min { abs($0.dayOfWeek - session.dayOfWeek) < abs($1.dayOfWeek - session.dayOfWeek) }
    }

    // MARK: - Create Plan

    func createPlan(
        raceName: String,
        raceDate: Date,
        template: TrainingPlanTemplate,
        userId: UUID
    ) {
        isLoading = true
        defer { isLoading = false }

        let result = PlanTemplateService.shared.generatePlan(
            from: template,
            userId: userId,
            raceName: raceName,
            raceDate: raceDate
        )

        activePlan = result.plan
        sessions = result.sessions
        skips = []
        swaps = []

        Task { await persistNewPlan() }
    }

    // MARK: - Edit Plan

    func updateRaceName(_ name: String) {
        guard let plan = activePlan else { return }
        activePlan?.name = name

        Task {
            do {
                try await supabase.from("training_plans")
                    .update(PlanNameUpdate(name: name))
                    .eq("id", value: plan.id)
                    .execute()
            } catch {
                lastError = "Failed to save race name."
            }
        }
    }

    func updateRaceDate(_ newDate: Date, template: TrainingPlanTemplate) {
        guard activePlan != nil else { return }

        let calendar = Calendar.current
        let daysBeforeRace = (template.durationWeeks - 1) * 7 + 5
        guard let newStart = calendar.date(byAdding: .day, value: -daysBeforeRace, to: newDate) else { return }

        activePlan?.raceDate = newDate
        activePlan?.planStartDate = newStart

        for i in sessions.indices {
            let dayOffset = (sessions[i].weekNumber - 1) * 7 + (sessions[i].dayOfWeek - 1)
            sessions[i].scheduledDate = calendar.date(byAdding: .day, value: dayOffset, to: newStart)!
        }

        Task { await persistDateUpdate() }
    }

    func replacePlan(
        raceName: String,
        raceDate: Date,
        template: TrainingPlanTemplate,
        userId: UUID
    ) {
        let oldPlanId = activePlan?.id

        createPlan(raceName: raceName, raceDate: raceDate, template: template, userId: userId)

        if let oldId = oldPlanId {
            Task {
                do {
                    try await supabase.from("training_plans")
                        .delete()
                        .eq("id", value: oldId)
                        .execute()
                } catch {
                    lastError = "Failed to delete old plan."
                }
            }
        }
    }

    // MARK: - Swap Sessions

    func swapSessions(_ sessionA: PlannedSession, with sessionB: PlannedSession, reason: String? = nil) {
        guard let indexA = sessions.firstIndex(where: { $0.id == sessionA.id }),
              let indexB = sessions.firstIndex(where: { $0.id == sessionB.id }),
              let planId = activePlan?.id else { return }

        let tempDate = sessions[indexA].scheduledDate
        let tempDay = sessions[indexA].dayOfWeek

        sessions[indexA].scheduledDate = sessions[indexB].scheduledDate
        sessions[indexA].dayOfWeek = sessions[indexB].dayOfWeek

        sessions[indexB].scheduledDate = tempDate
        sessions[indexB].dayOfWeek = tempDay

        let swap = SessionSwap(
            id: UUID(),
            planId: planId,
            sessionAId: sessionA.id,
            sessionBId: sessionB.id,
            reason: reason,
            swappedAt: Date()
        )
        swaps.append(swap)

        let updatedA = sessions[indexA]
        let updatedB = sessions[indexB]
        Task { await persistSwap(swap, sessionA: updatedA, sessionB: updatedB) }
    }

    // MARK: - Skip / Unskip

    func skipSession(_ sessionId: UUID, reason: String? = nil) {
        guard !isSkipped(sessionId) else { return }

        let skip = SessionSkip(
            id: UUID(),
            sessionId: sessionId,
            reason: reason,
            skippedAt: Date()
        )
        skips.append(skip)

        Task { await persistSkip(skip) }
    }

    func unskipSession(_ sessionId: UUID) {
        guard let index = skips.firstIndex(where: { $0.sessionId == sessionId }) else { return }
        let skip = skips.remove(at: index)

        Task {
            do {
                try await supabase.from("session_skips")
                    .delete()
                    .eq("id", value: skip.id)
                    .execute()
            } catch {
                lastError = "Failed to delete skip."
            }
        }
    }

    // MARK: - Override Session (Manual Edit)

    func overrideSession(
        _ sessionId: UUID,
        workoutType: WorkoutType?,
        distanceKm: Double?,
        paceDescription: String?,
        notes: String?,
        reason: String?,
        propagateToSameDay: Bool = false
    ) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        let original = sessions[index]

        if !isOverridden(sessionId) {
            let overrideRecord = SessionOverride(
                id: UUID(),
                sessionId: sessionId,
                originalWorkoutType: original.workoutType,
                originalTargetDistanceKm: original.targetDistanceKm,
                originalTargetPaceDescription: original.targetPaceDescription,
                originalNotes: original.notes,
                overrideReason: reason,
                overriddenAt: Date()
            )
            overrides.append(overrideRecord)
            Task { await persistOverride(overrideRecord) }
        }

        if let wt = workoutType { sessions[index].workoutType = wt }
        if let d = distanceKm { sessions[index].targetDistanceKm = d }
        sessions[index].targetPaceDescription = paceDescription
        sessions[index].notes = notes

        Task { await persistSessionFieldUpdate(sessions[index]) }

        if propagateToSameDay {
            let dayOfWeek = original.dayOfWeek
            let otherSessions = sessions.enumerated().filter {
                $0.element.dayOfWeek == dayOfWeek
                    && $0.element.id != sessionId
                    && $0.element.workoutType != .strength
            }

            for (otherIndex, otherSession) in otherSessions {
                if !isOverridden(otherSession.id) {
                    let overrideRecord = SessionOverride(
                        id: UUID(),
                        sessionId: otherSession.id,
                        originalWorkoutType: otherSession.workoutType,
                        originalTargetDistanceKm: otherSession.targetDistanceKm,
                        originalTargetPaceDescription: otherSession.targetPaceDescription,
                        originalNotes: otherSession.notes,
                        overrideReason: reason,
                        overriddenAt: Date()
                    )
                    overrides.append(overrideRecord)
                    Task { await persistOverride(overrideRecord) }
                }

                if let wt = workoutType { sessions[otherIndex].workoutType = wt }
                if let d = distanceKm { sessions[otherIndex].targetDistanceKm = d }
                sessions[otherIndex].targetPaceDescription = paceDescription
                sessions[otherIndex].notes = notes

                Task { await persistSessionFieldUpdate(sessions[otherIndex]) }
            }
        }
    }

    func resetToOriginal(_ sessionId: UUID) {
        guard let overrideIndex = overrides.firstIndex(where: { $0.sessionId == sessionId }),
              let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }) else { return }

        let original = overrides[overrideIndex]

        if let wt = original.originalWorkoutType {
            sessions[sessionIndex].workoutType = wt
        }
        sessions[sessionIndex].targetDistanceKm = original.originalTargetDistanceKm
        sessions[sessionIndex].targetPaceDescription = original.originalTargetPaceDescription
        sessions[sessionIndex].notes = original.originalNotes

        let overrideId = overrides[overrideIndex].id
        overrides.remove(at: overrideIndex)

        Task {
            await persistSessionFieldUpdate(sessions[sessionIndex])
            do {
                try await supabase.from("session_overrides")
                    .delete()
                    .eq("id", value: overrideId)
                    .execute()
            } catch {
                lastError = "Failed to delete override."
            }
        }
    }

    // MARK: - Load from Supabase

    func loadPlan(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let plans: [TrainingPlan] = try await supabase
                .from("training_plans")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            guard let plan = plans.first else { return }
            activePlan = plan

            sessions = try await supabase
                .from("planned_sessions")
                .select()
                .eq("plan_id", value: plan.id)
                .order("sort_order")
                .execute()
                .value

            if !sessions.isEmpty {
                let sessionIds = sessions.map { $0.id.uuidString }

                skips = try await supabase
                    .from("session_skips")
                    .select()
                    .in("session_id", values: sessionIds)
                    .execute()
                    .value

                swaps = try await supabase
                    .from("session_swaps")
                    .select()
                    .eq("plan_id", value: plan.id)
                    .execute()
                    .value

                overrides = try await supabase
                    .from("session_overrides")
                    .select()
                    .in("session_id", values: sessionIds)
                    .execute()
                    .value
            }

            reconcileNotesFromBundledTemplateIfNeeded()
        } catch {
            lastError = "Failed to load plan."
        }
    }

    /// If the bundled template for this plan has longer `notes` than Supabase (e.g. after a template update), backfill without touching user-overridden sessions.
    private func reconcileNotesFromBundledTemplateIfNeeded() {
        guard let template = currentTemplate else { return }

        var templateNotesByKey: [String: String] = [:]
        for row in template.sessions {
            let key = "\(row.week)-\(row.day)-\(row.workoutType.rawValue)"
            if let n = row.notes, !n.isEmpty {
                templateNotesByKey[key] = n
            }
        }

        var persisted: [PlannedSession] = []

        for index in sessions.indices {
            let s = sessions[index]
            if isOverridden(s.id) { continue }

            let key = "\(s.weekNumber)-\(s.dayOfWeek)-\(s.workoutType.rawValue)"
            guard let bundled = templateNotesByKey[key], !bundled.isEmpty else { continue }

            let current = s.notes ?? ""
            guard bundled.count > current.count else { continue }

            sessions[index].notes = bundled
            persisted.append(sessions[index])
        }

        guard !persisted.isEmpty else { return }

        Task {
            for s in persisted {
                await persistSessionFieldUpdate(s)
            }
        }
    }

    // MARK: - Clear Plan

    func clearPlan() {
        let oldPlanId = activePlan?.id
        activePlan = nil
        sessions = []
        skips = []
        swaps = []
        overrides = []

        if let oldId = oldPlanId {
            Task {
                do {
                    try await supabase.from("training_plans")
                        .delete()
                        .eq("id", value: oldId)
                        .execute()
                } catch {
                    lastError = "Failed to delete plan."
                }
            }
        }
    }

    // MARK: - Supabase Persistence Helpers

    private func persistNewPlan() async {
        guard let plan = activePlan else { return }
        do {
            try await supabase.from("training_plans").insert(plan).execute()
            try await supabase.from("planned_sessions").insert(sessions).execute()
        } catch {
            lastError = "Failed to save new plan."
        }
    }

    private func persistDateUpdate() async {
        guard let plan = activePlan else { return }
        do {
            try await supabase.from("training_plans")
                .update(PlanDateUpdate(raceDate: plan.raceDate, planStartDate: plan.planStartDate))
                .eq("id", value: plan.id)
                .execute()

            for session in sessions {
                try await supabase.from("planned_sessions")
                    .update(SessionDateUpdate(scheduledDate: session.scheduledDate, dayOfWeek: session.dayOfWeek))
                    .eq("id", value: session.id)
                    .execute()
            }
        } catch {
            lastError = "Failed to save date update."
        }
    }

    private func persistSwap(_ swap: SessionSwap, sessionA: PlannedSession, sessionB: PlannedSession) async {
        do {
            try await supabase.from("session_swaps").insert(swap).execute()

            try await supabase.from("planned_sessions")
                .update(SessionDateUpdate(scheduledDate: sessionA.scheduledDate, dayOfWeek: sessionA.dayOfWeek))
                .eq("id", value: sessionA.id)
                .execute()

            try await supabase.from("planned_sessions")
                .update(SessionDateUpdate(scheduledDate: sessionB.scheduledDate, dayOfWeek: sessionB.dayOfWeek))
                .eq("id", value: sessionB.id)
                .execute()
        } catch {
            lastError = "Failed to save swap."
        }
    }

    private func persistSkip(_ skip: SessionSkip) async {
        do {
            try await supabase.from("session_skips").insert(skip).execute()
        } catch {
            lastError = "Failed to save skip."
        }
    }

    private func persistOverride(_ override: SessionOverride) async {
        do {
            try await supabase.from("session_overrides").insert(override).execute()
        } catch {
            lastError = "Failed to save override."
        }
    }

    private func persistSessionFieldUpdate(_ session: PlannedSession) async {
        do {
            try await supabase.from("planned_sessions")
                .update(SessionFieldUpdate(
                    workoutType: session.workoutType,
                    targetDistanceKm: session.targetDistanceKm,
                    targetPaceDescription: session.targetPaceDescription,
                    notes: session.notes
                ))
                .eq("id", value: session.id)
                .execute()
        } catch {
            lastError = "Failed to save session update."
        }
    }
}

// MARK: - Supabase Update DTOs

private struct PlanNameUpdate: Encodable {
    let name: String
}

private struct PlanDateUpdate: Encodable {
    let raceDate: Date
    let planStartDate: Date

    enum CodingKeys: String, CodingKey {
        case raceDate = "race_date"
        case planStartDate = "plan_start_date"
    }
}

private struct SessionDateUpdate: Encodable {
    let scheduledDate: Date
    let dayOfWeek: Int

    enum CodingKeys: String, CodingKey {
        case scheduledDate = "scheduled_date"
        case dayOfWeek = "day_of_week"
    }
}

private struct SessionFieldUpdate: Encodable {
    let workoutType: WorkoutType
    let targetDistanceKm: Double?
    let targetPaceDescription: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case workoutType = "workout_type"
        case targetDistanceKm = "target_distance_km"
        case targetPaceDescription = "target_pace_description"
        case notes
    }
}
