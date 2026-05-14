import SwiftUI

/// "Session complete" badge — a burst-animated trailGreen dot with a white
/// check, plus an optional readout below ("16.1 mi" / "1.4 hr"). Reads from
/// `CompletionCelebrationStore` so the burst only plays the first time a
/// given session UUID is seen as complete; subsequent appearances jump
/// straight to the filled+checked state. Used by Week (cardio) and Strength
/// (strength + heat day rows).
struct CompleteStatus: View {
    /// Drives the burst's peak scale — miles for runs, hours for cross-train,
    /// a small fixed value (~1.0) for strength / heat where there's no natural
    /// magnitude. Capped by `params.milesCap`.
    let magnitude: Double
    /// Pre-formatted readout shown beneath the dot. Empty string suppresses
    /// the label row — used when the row's left column already says enough
    /// (e.g. strength / heat).
    let label: String
    let sessionId: UUID
    var baseSize: CGFloat = 18

    @State private var trigger: Int = 0
    @State private var labelVisible: Bool
    private let alreadyCelebrated: Bool
    private let params = CompletionParams.burst

    init(magnitude: Double, label: String, sessionId: UUID, baseSize: CGFloat = 18) {
        self.magnitude = magnitude
        self.label = label
        self.sessionId = sessionId
        self.baseSize = baseSize
        // Consult the celebration store at view init so the dot can render
        // its filled+checked state immediately on first appearance for
        // already-celebrated sessions. Without this, navigating back to a
        // surface whose completions have already been seen would replay the
        // burst.
        let celebrated = CompletionCelebrationStore.shared.contains(sessionId)
        self.alreadyCelebrated = celebrated
        _labelVisible = State(initialValue: celebrated)
    }

    var body: some View {
        // 3pt VStack spacing + 22pt dot row matches the WeekView session row's
        // left column so the readout baseline lines up with the coach-notes
        // range when both are present.
        VStack(alignment: .trailing, spacing: 3) {
            MilesCompletionDot(
                miles: magnitude,
                variant: .burst,
                params: params,
                trigger: trigger,
                baseSize: baseSize,
                initiallyCompleted: alreadyCelebrated
            )
            .frame(height: 22)
            if !label.isEmpty {
                Text(label)
                    .font(TrailFont.data)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.trailGreen)
                    .opacity(labelVisible ? 1 : 0)
            }
        }
        .onAppear {
            guard !alreadyCelebrated else { return }
            guard trigger == 0 else { return }
            trigger = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + params.totalDuration) {
                withAnimation(.easeOut(duration: 0.25)) {
                    labelVisible = true
                }
                CompletionCelebrationStore.shared.mark(sessionId)
            }
        }
    }
}
