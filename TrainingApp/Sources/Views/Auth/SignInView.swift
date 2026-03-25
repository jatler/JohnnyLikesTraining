import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AuthService.self) private var auth

    @State private var errorMessage: String?
    @State private var rawNonce: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "figure.run")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Training")
                    .font(.largeTitle.bold())

                Text("Your running plan, daily.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            SignInWithAppleButton(.signIn) { request in
                let nonce = AppleSignInNonce.randomString()
                rawNonce = nonce
                request.nonce = AppleSignInNonce.sha256Hex(nonce)
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                Task {
                    do {
                        let authorization = try result.get()
                        let nonce = rawNonce
                        rawNonce = nil
                        try await auth.signInWithApple(authorization: authorization, rawNonce: nonce)
                    } catch {
                        rawNonce = nil
                        errorMessage = Self.message(for: error)
                    }
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(12)
            .padding(.horizontal, 40)

            if DevSignIn.isAllowed {
                Button("Skip Sign-In (Dev)") {
                    auth.devSignIn()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
                .frame(height: 40)
        }
    }

    private static func message(for error: Error) -> String {
        if let apple = error as? AppleSignInError {
            return apple.localizedDescription
        }
        return error.localizedDescription
    }
}

#Preview {
    SignInView()
        .environment(AuthService())
}
