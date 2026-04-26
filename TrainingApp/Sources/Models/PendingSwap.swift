import Foundation

/// A swap that has not yet been confirmed by Supabase. Stored locally and
/// replayed at the top of the next `loadPlan` so that the fresh server fetch
/// can't clobber the local cache with stale (pre-swap) workout fields.
struct PendingSwap: Codable {
    let swap: SessionSwap
    let sessionAUpdate: SessionFieldSnapshot
    let sessionBUpdate: SessionFieldSnapshot
    let strengthMoves: [StrengthDateMove]
}

struct SessionFieldSnapshot: Codable {
    let sessionId: UUID
    let workoutType: WorkoutType
    let targetDistanceKm: Double?
    let targetPaceDescription: String?
    let notes: String?
}

struct StrengthDateMove: Codable {
    let sessionId: UUID
    let scheduledDate: Date
    let dayOfWeek: Int
}
