import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD — Miles-Aware Completion Pulse
 *
 * Trigger: a run logs to the day → green check appears in WeekView.
 *
 *    0ms   Phase 1 · GROW
 *          dot scales 1.0 → peakScale (computed from miles)
 *          background fills empty-outline → solid green
 *          variant chooses spring vs. ease-out
 *
 * +growDur Phase 2 · HOLD
 *          brief read-the-size pause
 *          burst variant emits concentric rings here
 *
 * +holdDur Phase 3 · SHRINK
 *          dot scales peak → 1.0 with optional spring bounce
 *
 *  ≈shrinkEnd Phase 4 · CHECK
 *          white checkmark fades + scales 0.4 → 1.0
 *          overlaps tail of shrink by `checkOverlap` so the
 *          two phases feel connected, not sequential
 *
 * Miles → peak map (linear, capped):
 *   peak = 1.0 + min(miles, milesCap) / milesCap × (maxScale − 1.0)
 *   0 mi → 1.0×    cap+ mi → maxScale×
 * ─────────────────────────────────────────────────────────
 */

// MARK: - Variant + params

enum CompletionVariant: String, CaseIterable, Identifiable {
    case bouncy = "Bouncy"
    case smooth = "Smooth"
    case burst  = "Burst"
    var id: String { rawValue }
}

struct CompletionParams: Equatable {
    var maxScale: Double        // peak multiplier at milesCap
    var milesCap: Double        // miles above which size is clamped
    var growDuration: Double    // sec
    var holdDuration: Double    // sec
    var shrinkDuration: Double  // sec
    var checkOverlap: Double    // 0…1 fraction of shrink overlapped by check appear
    var checkDuration: Double   // sec
    var shrinkBounce: Double    // 0…1, higher = more bouncy
    var ringCount: Int          // burst only

    static let bouncy = CompletionParams(
        maxScale: 2.4, milesCap: 20,
        growDuration: 0.32, holdDuration: 0.10, shrinkDuration: 0.55,
        checkOverlap: 0.55, checkDuration: 0.35,
        shrinkBounce: 0.55, ringCount: 0
    )
    static let smooth = CompletionParams(
        maxScale: 2.0, milesCap: 18,
        growDuration: 0.45, holdDuration: 0.25, shrinkDuration: 0.50,
        checkOverlap: 0.30, checkDuration: 0.30,
        shrinkBounce: 0.15, ringCount: 0
    )
    static let burst = CompletionParams(
        maxScale: 4.0, milesCap: 40,
        growDuration: 0.50, holdDuration: 0.50, shrinkDuration: 0.45,
        checkOverlap: 0.50, checkDuration: 0.28,
        shrinkBounce: 0.40, ringCount: 1
    )

    /// How long the full storyboard runs end-to-end, so callers can defer
    /// dependent UI (e.g. the miles label) until the dot has settled.
    var totalDuration: Double {
        let checkEnd = growDuration + holdDuration + shrinkDuration * (1 - checkOverlap) + checkDuration
        let shrinkEnd = growDuration + holdDuration + shrinkDuration
        return max(checkEnd, shrinkEnd)
    }
}

// MARK: - The animated dot

private struct RingState: Identifiable {
    let id = UUID()
    var scale: CGFloat = 1.0
    var opacity: Double = 0.6
}

struct MilesCompletionDot: View {
    let miles: Double
    let variant: CompletionVariant
    let params: CompletionParams
    let trigger: Int          // bump to replay
    var baseSize: CGFloat = 22

    @State private var scale: CGFloat = 1.0
    @State private var fillProgress: Double = 0.0
    @State private var checkScale: CGFloat = 0.4
    @State private var checkOpacity: Double = 0.0
    @State private var rings: [RingState] = []

    private var peakScale: Double {
        let cap = max(params.milesCap, 0.01)
        let t = min(max(miles, 0), params.milesCap) / cap
        return 1.0 + t * (params.maxScale - 1.0)
    }

    var body: some View {
        ZStack {
            // Outline (visible at rest, fades as fill grows)
            Circle()
                .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1.5)
                .frame(width: baseSize, height: baseSize)
                .opacity(1 - fillProgress)

            // Solid green fill (fades in during grow)
            Circle()
                .fill(Color.trailGreen)
                .frame(width: baseSize, height: baseSize)
                .opacity(fillProgress)

            // Burst rings (only emitted by burst variant)
            ForEach(rings) { r in
                Circle()
                    .strokeBorder(Color.trailGreen, lineWidth: 1.5)
                    .frame(width: baseSize, height: baseSize)
                    .scaleEffect(r.scale)
                    .opacity(r.opacity)
                    .allowsHitTesting(false)
            }

            // White checkmark glyph
            Image(systemName: "checkmark")
                .font(.system(size: baseSize * 0.55, weight: .bold))
                .foregroundStyle(.white)
                .scaleEffect(checkScale)
                .opacity(checkOpacity)
        }
        .scaleEffect(scale)
        .frame(width: baseSize, height: baseSize)
        .onChange(of: trigger) { _, _ in animate() }
    }

    private func animate() {
        // Reset to pre-trigger state
        scale = 1.0
        fillProgress = 0
        checkScale = 0.4
        checkOpacity = 0
        rings = []

        let grow   = params.growDuration
        let hold   = params.holdDuration
        let shrink = params.shrinkDuration
        let checkStartOffset = grow + hold + shrink * (1 - params.checkOverlap)

        // ── Phase 1 · Grow + fill ─────────────────────────
        let growAnim: Animation
        switch variant {
        case .bouncy:
            growAnim = .interpolatingSpring(stiffness: 220, damping: 14)
        case .smooth:
            growAnim = .easeOut(duration: grow)
        case .burst:
            growAnim = .interpolatingSpring(stiffness: 380, damping: 18)
        }
        withAnimation(growAnim) {
            scale = CGFloat(peakScale)
            fillProgress = 1.0
        }

        // ── Phase 2.5 · Burst rings (during hold) ────────
        if variant == .burst && params.ringCount > 0 {
            let perRing = hold / Double(max(params.ringCount, 1))
            for i in 0..<params.ringCount {
                let delay = grow + Double(i) * max(perRing, 0.04)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    rings.append(RingState())
                    let idx = rings.count - 1
                    withAnimation(.easeOut(duration: 0.65)) {
                        guard idx < rings.count else { return }
                        rings[idx].scale = CGFloat(peakScale * 2.2)
                        rings[idx].opacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        if !rings.isEmpty { rings.removeFirst() }
                    }
                }
            }
        }

        // ── Phase 3 · Shrink ──────────────────────────────
        let damping = max(0.15, 1 - params.shrinkBounce * 0.6)
        let shrinkAnim: Animation
        switch variant {
        case .bouncy:
            shrinkAnim = .spring(response: shrink, dampingFraction: damping)
        case .smooth:
            shrinkAnim = .easeInOut(duration: shrink)
        case .burst:
            shrinkAnim = .spring(response: shrink, dampingFraction: damping)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + grow + hold) {
            withAnimation(shrinkAnim) { scale = 1.0 }
        }

        // ── Phase 4 · Check appear ────────────────────────
        DispatchQueue.main.asyncAfter(deadline: .now() + checkStartOffset) {
            let checkAnim: Animation
            switch variant {
            case .bouncy: checkAnim = .spring(response: params.checkDuration, dampingFraction: 0.55)
            case .smooth: checkAnim = .easeOut(duration: params.checkDuration)
            case .burst:  checkAnim = .spring(response: params.checkDuration, dampingFraction: 0.6)
            }
            withAnimation(checkAnim) {
                checkScale = 1.0
                checkOpacity = 1.0
            }
        }
    }
}

// MARK: - Prototype playground

struct MilesCompletionPrototype: View {
    @State private var variant: CompletionVariant = .burst
    @State private var miles: Double = 30.0
    @State private var trigger: Int = 0
    @State private var milesLabelVisible: Bool = false

    @State private var bouncyParams = CompletionParams.bouncy
    @State private var smoothParams = CompletionParams.smooth
    @State private var burstParams  = CompletionParams.burst

    private var activeParams: Binding<CompletionParams> {
        switch variant {
        case .bouncy: return $bouncyParams
        case .smooth: return $smoothParams
        case .burst:  return $burstParams
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                stage
                replayButton
                variantPicker
                milesControl
                Divider().padding(.vertical, 2)
                paramControls
                resetButton
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Completion Lab")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: trigger) { _, _ in scheduleLabelReveal() }
    }

    private func scheduleLabelReveal() {
        milesLabelVisible = false
        let delay = activeParams.wrappedValue.totalDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 0.25)) {
                milesLabelVisible = true
            }
        }
    }

    private var stage: some View {
        VStack(spacing: 12) {
            // Show the dot inside a context that looks like the WeekView row
            // so the size feels honest against real chrome.
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LONG RUN")
                        .font(TrailFont.data).tracking(0.5)
                        .foregroundStyle(.secondary)
                    Text("Easy 8 miles, conversational")
                        .font(TrailFont.body)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    MilesCompletionDot(
                        miles: miles,
                        variant: variant,
                        params: activeParams.wrappedValue,
                        trigger: trigger,
                        baseSize: 22
                    )
                    Text(String(format: "%.1f mi", miles))
                        .font(TrailFont.data).fontWeight(.medium)
                        .foregroundStyle(.green)
                        .opacity(milesLabelVisible ? 1 : 0)
                }
            }
            .padding(14)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
            )

            // Big isolated preview — easier to see the shape of the motion.
            ZStack {
                MilesCompletionDot(
                    miles: miles,
                    variant: variant,
                    params: activeParams.wrappedValue,
                    trigger: trigger,
                    baseSize: 56
                )
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var replayButton: some View {
        Button {
            trigger += 1
        } label: {
            Label("Replay", systemImage: "arrow.clockwise")
                .font(TrailFont.body).fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.trailGreen, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
    }

    private var variantPicker: some View {
        Picker("Variant", selection: $variant) {
            ForEach(CompletionVariant.allCases) { v in
                Text(v.rawValue).tag(v)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: variant) { _, _ in trigger += 1 }
    }

    private var milesControl: some View {
        Dial(label: "Miles run", value: $miles, range: 0...30, step: 0.5, format: "%.1f mi")
    }

    @ViewBuilder
    private var paramControls: some View {
        Dial(label: "Max scale (at cap)", value: activeParams.maxScale,        range: 1.2...4.0,   step: 0.05, format: "%.2f×")
        Dial(label: "Miles cap",          value: activeParams.milesCap,        range: 5...40,      step: 1,    format: "%.0f mi")
        Dial(label: "Grow duration",      value: activeParams.growDuration,    range: 0.10...1.00, step: 0.02, format: "%.2fs")
        Dial(label: "Hold duration",      value: activeParams.holdDuration,    range: 0.00...0.60, step: 0.02, format: "%.2fs")
        Dial(label: "Shrink duration",    value: activeParams.shrinkDuration,  range: 0.15...1.20, step: 0.02, format: "%.2fs")
        Dial(label: "Shrink bounce",      value: activeParams.shrinkBounce,    range: 0.00...0.90, step: 0.02, format: "%.2f")
        Dial(label: "Check overlap",      value: activeParams.checkOverlap,    range: 0.00...1.00, step: 0.05, format: "%.2f")
        Dial(label: "Check duration",     value: activeParams.checkDuration,   range: 0.10...0.80, step: 0.02, format: "%.2fs")
        if variant == .burst {
            IntDial(label: "Ring count", value: activeParams.ringCount, range: 0...8)
        }
    }

    private var resetButton: some View {
        Button {
            switch variant {
            case .bouncy: bouncyParams = .bouncy
            case .smooth: smoothParams = .smooth
            case .burst:  burstParams  = .burst
            }
            trigger += 1
        } label: {
            Text("Reset \(variant.rawValue) to defaults")
                .font(TrailFont.data)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 1)
                )
        }
    }
}

// MARK: - Slider rows (DialKit-style)

private struct Dial: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0.01
    var format: String = "%.2f"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(TrailFont.meta)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: format, value))
                    .font(TrailFont.data)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: step)
                .tint(Color.trailGreen)
        }
    }
}

private struct IntDial: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(TrailFont.meta)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(value)")
                    .font(TrailFont.data)
                    .monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .tint(Color.trailGreen)
        }
    }
}

// MARK: - Preview

#Preview("Completion Lab") {
    NavigationStack {
        MilesCompletionPrototype()
    }
}

#Preview("Side-by-side @ 12 mi") {
    HStack(spacing: 40) {
        ForEach(CompletionVariant.allCases) { v in
            VStack(spacing: 12) {
                Text(v.rawValue)
                    .font(TrailFont.data).tracking(0.5)
                    .foregroundStyle(.secondary)
                MilesCompletionDot(
                    miles: 12,
                    variant: v,
                    params: {
                        switch v {
                        case .bouncy: return .bouncy
                        case .smooth: return .smooth
                        case .burst:  return .burst
                        }
                    }(),
                    trigger: 1,
                    baseSize: 44
                )
            }
        }
    }
    .padding(40)
}
