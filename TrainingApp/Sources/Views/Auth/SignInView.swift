import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AuthService.self) private var auth

    @State private var errorMessage: String?
    @State private var rawNonce: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("JohnnyLikesTraining")
                    .font(.custom("GeistMono-Medium", size: 28, relativeTo: .largeTitle))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.trailGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 16)

                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.3")")
                    .font(TrailFont.body)
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
                .font(TrailFont.meta)
                .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(TrailFont.meta)
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
