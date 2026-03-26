import SwiftUI

/// Paywall sheet shown when a non-patron tries to load a gated feature.
/// Presented as a .medium sheet — does NOT replace root navigation.
struct PatreonGateView: View {
    @Environment(PatreonService.self) private var patreon
    @Environment(\.dismiss) private var dismiss

    /// Callback invoked after successful patron verification — caller dismisses and continues.
    var onPatronVerified: (() -> Void)?

    @State private var showNetworkError = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle region
            Spacer().frame(height: 8)

            switch viewState {
            case .notConnected:
                notConnectedView
            case .verifying:
                verifyingView
            case .notPatron:
                notPatronView
            case .networkError:
                networkErrorView
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onChange(of: patreon.isPatron) { _, isPatron in
            if isPatron {
                onPatronVerified?()
                dismiss()
            }
        }
    }

    // MARK: - View State

    private enum ViewState {
        case notConnected, verifying, notPatron, networkError
    }

    private var viewState: ViewState {
        if showNetworkError { return .networkError }
        if patreon.isVerifying { return .verifying }
        if patreon.isConnected && !patreon.isPatron { return .notPatron }
        return .notConnected
    }

    // MARK: - State A: Not Connected

    private var notConnectedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.swapAccent)
                .padding(.top, 16)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("SWAP Training Plans")
                    .font(.title2.bold())
                Text("Exclusive to SWAP Running Patrons")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Text("Connect your Patreon account to unlock all \(BrandKit.coachCredit) training plans, Oura integration, and the progression engine.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    connectPatreon()
                } label: {
                    Text("Connect Patreon")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.swapAccent, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }

                Link(destination: BrandKit.patreonURL) {
                    Text("Subscribe on Patreon ↗")
                        .font(.subheadline)
                        .foregroundStyle(Color.swapAccent)
                }
                .accessibilityLabel("Subscribe to SWAP on Patreon - opens in browser")
            }
        }
    }

    // MARK: - State B: Verifying

    private var verifyingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView("Checking your membership\u{2026}")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - State D: Connected, Not Patron

    private var notPatronView: some View {
        VStack(spacing: 24) {
            Image(systemName: "star.circle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .padding(.top, 16)

            VStack(spacing: 6) {
                Text("Patreon Connected")
                    .font(.title2.bold())
                Text("Account not subscribed at $5+/mo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("To access SWAP training plans, subscribe to the SWAP Running Patreon at the $5/month tier or higher.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Link(destination: BrandKit.patreonURL) {
                    Text("Subscribe on Patreon ↗")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.swapAccent, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Subscribe to SWAP on Patreon - opens in browser")

                Button {
                    patreon.disconnect()
                } label: {
                    Text("Try another account")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - State E: Network Error

    private var networkErrorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .padding(.top, 16)

            Text("Couldn't reach Patreon. Check your connection.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    showNetworkError = false
                    connectPatreon()
                } label: {
                    Text("Try Again")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.swapAccent, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }

                Button {
                    showNetworkError = false
                    dismiss()
                } label: {
                    Text("Continue anyway")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func connectPatreon() {
        Task {
            do {
                try await patreon.authorize()
            } catch {
                showNetworkError = true
            }
        }
    }
}

#Preview("Not Connected") {
    Text("Content")
        .sheet(isPresented: .constant(true)) {
            PatreonGateView()
                .environment(PatreonService())
        }
}
