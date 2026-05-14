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

    /// Swaps awaiting confirmation from Supabase. Persisted in PlanCacheService;
    /// drained at the top of `loadPlan` so a fresh server fetch can't clobber
    /// unsynced state.
    private(set) var pendingSwaps: [PendingSwap] = PlanCacheService.loadPendingSwaps()

    private let supabase = SupabaseService.shared.client

    var hasPlan: Bool { activePlan != nil }

    private func saveToCache() {
        guard let plan = activePlan else { return }
        PlanCacheService.save(plan: plan, sessions: sessions, skips: skips, swaps: swaps, overrides: overrides)
    }

    private func savePendingSwapsToCache() {
        PlanCacheService.savePendingSwaps(pendingSwaps)
    }

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

        PlanCacheService.save(plan: result.plan, sessions: result.sessions)
        Task { await persistNewPlan() }
    }

    // MARK: - Edit Plan

    func updateRaceName(_ name: String) {
        guard let plan = activePlan else { return }
        activePlan?.name = name
        guard !isOffline else { return }

        Task {
            let result = await SupabaseService.shared.execute(table: "training_plans", operation: "update") {
                try await supabase.from("training_plans")
                    .update(PlanNameUpdate(name: name))
                    .eq("id", value: plan.id)
                    .execute()
            }
            if case .failure(let err) = result, !err.isRetryable {
                lastError = err.userFacing
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

        guard !isOffline else { return }
        if let oldId = oldPlanId {
            Task {
                let result = await SupabaseService.shared.execute(table: "training_plans", operation: "delete") {
                    try await supabase.from("training_plans")
                        .delete()
                        .eq("id", value: oldId)
                        .execute()
                }
                if case .failure(let err) = result, !err.isRetryable {
                    lastError = err.userFacing
                }
            }
        }
    }

    // MARK: - Swap Sessions

    func swapSessions(_ sessionA: PlannedSession, with sessionB: PlannedSession, reason: String? = nil) {
        guard let indexA = sessions.firstIndex(where: { $0.id == sessionA.id }),
              let indexB = sessions.firstIndex(where: { $0.id == sessionB.id }),
              let planId = activePlan?.id else { return }

        let dateA = sessions[indexA].scheduledDate
        let dayA = sessions[indexA].dayOfWeek
        let dateB = sessions[indexB].scheduledDate
        let dayB = sessions[indexB].dayOfWeek

        // Swap the coaching payload between the two sessions but leave their
        // scheduledDate / id alone. This keeps any Strava activity (matched
        // via session UUID) pinned to the day it was actually recorded on,
        // while the planned workout content moves between days.
        let workoutTypeA = sessions[indexA].workoutType
        let distanceA = sessions[indexA].targetDistanceKm
        let paceA = sessions[indexA].targetPaceDescription
        let notesA = sessions[indexA].notes

        sessions[indexA].workoutType = sessions[indexB].workoutType
        sessions[indexA].targetDistanceKm = sessions[indexB].targetDistanceKm
        sessions[indexA].targetPaceDescription = sessions[indexB].targetPaceDescription
        sessions[indexA].notes = sessions[indexB].notes

        sessions[indexB].workoutType = workoutTypeA
        sessions[indexB].targetDistanceKm = distanceA
        sessions[indexB].targetPaceDescription = paceA
        sessions[indexB].notes = notesA

        // Strength sessions are conceptually paired with the run *workout*, so
        // they follow the workout content to its new day. Move by date/day —
        // same approach as before.
        var movedStrengthIds: [UUID] = []
        for i in sessions.indices {
            guard sessions[i].workoutType == .strength else { continue }
            guard sessions[i].weekNumber == sessionA.weekNumber else { continue }

            if sessions[i].id != sessionA.id && sessions[i].id != sessionB.id {
                if sessions[i].dayOfWeek == dayA
                    && Calendar.current.isDate(sessions[i].scheduledDate, inSameDayAs: dateA) {
                    sessions[i].scheduledDate = dateB
                    sessions[i].dayOfWeek = dayB
                    movedStrengthIds.append(sessions[i].id)
                } else if sessions[i].dayOfWeek == dayB
                    && Calendar.current.isDate(sessions[i].scheduledDate, inSameDayAs: dateB) {
                    sessions[i].scheduledDate = dateA
                    sessions[i].dayOfWeek = dayA
                    movedStrengthIds.append(sessions[i].id)
                }
            }
        }

        let swap = SessionSwap(
            id: UUID(),
            planId: planId,
            sessionAId: sessionA.id,
            sessionBId: sessionB.id,
            reason: reason,
            swappedAt: Date()
        )
        swaps.append(swap)
        saveToCache()

        let updatedA = sessions[indexA]
        let updatedB = sessions[indexB]
        let movedStrengthSessions = sessions.filter { movedStrengthIds.contains($0.id) }

        // Enqueue first, then attempt persistence. If the persist task fails or
        // the app is killed mid-write, the swap survives in pendingSwaps and is
        // replayed at the next loadPlan — preventing the fresh Supabase fetch
        // from clobbering the local cache with stale (pre-swap) workout fields.
        let pending = PendingSwap(
            swap: swap,
            sessionAUpdate: snapshot(updatedA),
            sessionBUpdate: snapshot(updatedB),
            strengthMoves: movedStrengthSessions.map {
                StrengthDateMove(sessionId: $0.id, scheduledDate: $0.scheduledDate, dayOfWeek: $0.dayOfWeek)
            }
        )
        pendingSwaps.append(pending)
        savePendingSwapsToCache()

        Task { await persistPendingSwap(pending) }
    }

    private func snapshot(_ session: PlannedSession) -> SessionFieldSnapshot {
        SessionFieldSnapshot(
            sessionId: session.id,
            workoutType: session.workoutType,
            targetDistanceKm: session.targetDistanceKm,
            targetPaceDescription: session.targetPaceDescription,
            notes: session.notes
        )
    }

    /// Try to push a single PendingSwap to Supabase. On success, dequeue it.
    /// On retryable failure (network/timeout/5xx) leave it queued — silent;
    /// `replayPendingSwaps()` picks it up at the next loadPlan. On non-retryable
    /// failure (RLS denial, validation), surface the real PostgREST message so
    /// the user knows what's wrong — the bogus "Will sync when online" alert
    /// when actually online was the bug here.
    private func persistPendingSwap(_ pending: PendingSwap) async {
        guard !isOffline else { return }
        do {
            try await pushSwapToSupabase(pending)
            removePending(pending.swap.id)
        } catch {
            let err = PersistenceError.from(error, table: "session_swaps", operation: "upsert")
            print(err.description)
            if err.isAuthFailure {
                SupabaseService.shared.onAuthFailure?()
            } else if !err.isRetryable {
                lastError = err.userFacing
            }
            // Retryable failures: swap stays in pendingSwaps for retry — no alert.
        }
    }

    private func removePending(_ swapId: UUID) {
        pendingSwaps.removeAll { $0.swap.id == swapId }
        savePendingSwapsToCache()
    }

    /// Drain `pendingSwaps` against Supabase. Called at the top of `loadPlan`
    /// so that the upcoming fetch sees a server state consistent with the
    /// local cache. Failed swaps stay queued for the next attempt.
    func replayPendingSwaps() async {
        guard !isOffline, !pendingSwaps.isEmpty else { return }
        let snapshot = pendingSwaps
        for pending in snapshot {
            do {
                try await pushSwapToSupabase(pending)
                removePending(pending.swap.id)
            } catch {
                print("Failed to replay pending swap \(pending.swap.id): \(error)")
                // Keep in queue; try again next loadPlan.
            }
        }
    }

    /// Idempotent push: upserts the SessionSwap row and updates both planned
    /// sessions plus any moved strength sessions. Throws on any failure so the
    /// caller can decide whether to retry or surface the error.
    private func pushSwapToSupabase(_ pending: PendingSwap) async throws {
        try await supabase.from("session_swaps")
            .upsert(pending.swap, onConflict: "id")
            .execute()

        try await supabase.from("planned_sessions")
            .update(SessionFieldUpdate(
                workoutType: pending.sessionAUpdate.workoutType,
                targetDistanceKm: pending.sessionAUpdate.targetDistanceKm,
                targetPaceDescription: pending.sessionAUpdate.targetPaceDescription,
                notes: pending.sessionAUpdate.notes
            ))
            .eq("id", value: pending.sessionAUpdate.sessionId)
            .execute()

        try await supabase.from("planned_sessions")
            .update(SessionFieldUpdate(
                workoutType: pending.sessionBUpdate.workoutType,
                targetDistanceKm: pending.sessionBUpdate.targetDistanceKm,
                targetPaceDescription: pending.sessionBUpdate.targetPaceDescription,
                notes: pending.sessionBUpdate.notes
            ))
            .eq("id", value: pending.sessionBUpdate.sessionId)
            .execute()

        for move in pending.strengthMoves {
            try await supabase.from("planned_sessions")
                .update(SessionDateUpdate(scheduledDate: move.scheduledDate, dayOfWeek: move.dayOfWeek))
                .eq("id", value: move.sessionId)
                .execute()
        }
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
        saveToCache()

        Task { await persistSkip(skip) }
    }

    func unskipSession(_ sessionId: UUID) {
        guard let index = skips.firstIndex(where: { $0.sessionId == sessionId }) else { return }
        let skip = skips.remove(at: index)
        saveToCache()
        guard !isOffline else { return }

        Task {
            let result = await SupabaseService.shared.execute(table: "session_skips", operation: "delete") {
                try await supabase.from("session_skips")
                    .delete()
                    .eq("id", value: skip.id)
                    .execute()
            }
            if case .failure(let err) = result, !err.isRetryable {
                lastError = err.userFacing
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

        saveToCache()
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
        saveToCache()
        guard !isOffline else { return }

        Task {
            await persistSessionFieldUpdate(sessions[sessionIndex])
            let result = await SupabaseService.shared.execute(table: "session_overrides", operation: "delete") {
                try await supabase.from("session_overrides")
                    .delete()
                    .eq("id", value: overrideId)
                    .execute()
            }
            if case .failure(let err) = result, !err.isRetryable {
                lastError = err.userFacing
            }
        }
    }

    // MARK: - Load from Supabase

    func loadPlan(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        // Load from local cache first for instant display
        if activePlan == nil, let cached = PlanCacheService.loadCached() {
            activePlan = cached.plan
            sessions = cached.sessions
            skips = cached.skips
            swaps = cached.swaps
            overrides = cached.overrides
        }

        guard !isOffline else { return }

        // Drain any swaps that didn't persist on a previous run before we
        // fetch — otherwise the fetch would clobber local cache with stale
        // (pre-swap) workout fields.
        await replayPendingSwaps()

        // Then sync from Supabase in foreground
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

            // Cache for offline access
            PlanCacheService.save(plan: plan, sessions: sessions, skips: skips, swaps: swaps, overrides: overrides)
        } catch {
            // If Supabase fails but we have cached data, that's OK
            if activePlan == nil {
                lastError = "Failed to load plan."
            }
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
        pendingSwaps = []
        PlanCacheService.clear()

        guard !isOffline else { return }
        if let oldId = oldPlanId {
            Task {
                let result = await SupabaseService.shared.execute(table: "training_plans", operation: "delete") {
                    try await supabase.from("training_plans")
                        .delete()
                        .eq("id", value: oldId)
                        .execute()
                }
                if case .failure(let err) = result, !err.isRetryable {
                    lastError = err.userFacing
                }
            }
        }
    }

    // MARK: - Supabase Persistence Helpers

    private var isOffline: Bool { SupabaseService.shared.isOffline }

    private func persistNewPlan() async {
        guard !isOffline, let plan = activePlan else { return }
        let result = await SupabaseService.shared.execute(table: "training_plans", operation: "insert") { () -> Void in
            try await supabase.from("training_plans").insert(plan).execute()
            try await supabase.from("planned_sessions").insert(sessions).execute()
        }
        if case .failure(let err) = result, !err.isRetryable {
            lastError = err.userFacing
        }
    }

    private func persistDateUpdate() async {
        guard !isOffline, let plan = activePlan else { return }
        let result = await SupabaseService.shared.execute(table: "training_plans", operation: "update") { () -> Void in
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
        }
        if case .failure(let err) = result, !err.isRetryable {
            lastError = err.userFacing
        }
    }

    private func persistSkip(_ skip: SessionSkip) async {
        guard !isOffline else { return }
        let result = await SupabaseService.shared.execute(table: "session_skips", operation: "insert") {
            try await supabase.from("session_skips").insert(skip).execute()
        }
        if case .failure(let err) = result, !err.isRetryable {
            lastError = err.userFacing
        }
    }

    private func persistOverride(_ override: SessionOverride) async {
        guard !isOffline else { return }
        let result = await SupabaseService.shared.execute(table: "session_overrides", operation: "insert") {
            try await supabase.from("session_overrides").insert(override).execute()
        }
        if case .failure(let err) = result, !err.isRetryable {
            lastError = err.userFacing
        }
    }

    private func persistSessionFieldUpdate(_ session: PlannedSession) async {
        guard !isOffline else { return }
        let result = await SupabaseService.shared.execute(table: "planned_sessions", operation: "update") {
            try await supabase.from("planned_sessions")
                .update(SessionFieldUpdate(
                    workoutType: session.workoutType,
                    targetDistanceKm: session.targetDistanceKm,
                    targetPaceDescription: session.targetPaceDescription,
                    notes: session.notes
                ))
                .eq("id", value: session.id)
                .execute()
        }
        if case .failure(let err) = result, !err.isRetryable {
            lastError = err.userFacing
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
