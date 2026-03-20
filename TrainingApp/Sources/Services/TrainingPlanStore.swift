import Foundation

@MainActor
@Observable
final class TrainingPlanStore {

    private(set) var activePlan: TrainingPlan?
    private(set) var sessions: [PlannedSession] = []
    private(set) var skips: [SessionSkip] = []
    private(set) var swaps: [SessionSwap] = []
    private(set) var isLoading = false

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
                print("Failed to update race name: \(error)")
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
                    print("Failed to delete old plan: \(error)")
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
                print("Failed to delete skip: \(error)")
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
                skips = try await supabase
                    .from("session_skips")
                    .select()
                    .in("session_id", values: sessions.map { $0.id.uuidString })
                    .execute()
                    .value

                swaps = try await supabase
                    .from("session_swaps")
                    .select()
                    .eq("plan_id", value: plan.id)
                    .execute()
                    .value
            }
        } catch {
            print("Failed to load plan: \(error)")
        }
    }

    // MARK: - Clear Plan

    func clearPlan() {
        let oldPlanId = activePlan?.id
        activePlan = nil
        sessions = []
        skips = []
        swaps = []

        if let oldId = oldPlanId {
            Task {
                do {
                    try await supabase.from("training_plans")
                        .delete()
                        .eq("id", value: oldId)
                        .execute()
                } catch {
                    print("Failed to delete plan: \(error)")
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
            print("Failed to persist new plan: \(error)")
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
            print("Failed to persist date update: \(error)")
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
            print("Failed to persist swap: \(error)")
        }
    }

    private func persistSkip(_ skip: SessionSkip) async {
        do {
            try await supabase.from("session_skips").insert(skip).execute()
        } catch {
            print("Failed to persist skip: \(error)")
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
