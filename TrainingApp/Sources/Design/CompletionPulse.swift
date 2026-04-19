import SwiftUI

struct CompletionPulse: ViewModifier {
    let isComplete: Bool

    @State private var scale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.0
    @State private var ringScale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .overlay(
                Circle()
                    .strokeBorder(Color.trailGreen, lineWidth: 1.5)
                    .opacity(ringOpacity)
                    .scaleEffect(ringScale)
                    .allowsHitTesting(false)
            )
            .sensoryFeedback(.success, trigger: isComplete) { _, new in new }
            .onChange(of: isComplete) { _, newValue in
                guard newValue else { return }
                withAnimation(.interpolatingSpring(stiffness: 380, damping: 14)) {
                    scale = 1.12
                }
                withAnimation(.easeOut(duration: 0.18).delay(0.08)) {
                    scale = 1.0
                }

                ringScale = 1.0
                ringOpacity = 0.7
                withAnimation(.easeOut(duration: 0.5)) {
                    ringScale = 1.65
                    ringOpacity = 0.0
                }
            }
    }
}

extension View {
    func completionPulse(_ isComplete: Bool) -> some View {
        modifier(CompletionPulse(isComplete: isComplete))
    }
}
