import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AuthService.self) private var auth

    @State private var errorMessage: String?

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
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                Task {
                    do {
                        let authorization = try result.get()
                        try await auth.signInWithApple(authorization: authorization)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(12)
            .padding(.horizontal, 40)

            #if DEBUG
            Button("Skip Sign-In (Dev)") {
                auth.devSignIn()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            #endif

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
}

#Preview {
    SignInView()
        .environment(AuthService())
}
