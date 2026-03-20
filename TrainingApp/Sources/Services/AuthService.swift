import AuthenticationServices
import Foundation
import Supabase

@MainActor
@Observable
final class AuthService {
    private let supabase = SupabaseService.shared.client

    var isAuthenticated = false
    var isLoading = true
    var currentUserId: UUID?

    #if DEBUG
    var isDevBypass = false
    #endif

    init() {
        Task { await checkSession() }
    }

    func checkSession() async {
        isLoading = true
        defer { isLoading = false }

        #if DEBUG
        if isDevBypass { return }
        #endif

        do {
            let session = try await supabase.auth.session
            currentUserId = session.user.id
            isAuthenticated = true
        } catch {
            isAuthenticated = false
            currentUserId = nil
        }
    }

    #if DEBUG
    func devSignIn() {
        currentUserId = UUID()
        isAuthenticated = true
        isDevBypass = true
    }
    #endif

    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8)
        else {
            throw AuthError.missingIdentityToken
        }

        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: identityToken
            )
        )

        currentUserId = session.user.id
        isAuthenticated = true
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        isAuthenticated = false
        currentUserId = nil
    }
}

enum AuthError: LocalizedError {
    case missingIdentityToken

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            "Apple Sign-In did not return an identity token."
        }
    }
}
