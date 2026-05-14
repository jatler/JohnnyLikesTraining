import AuthenticationServices
import Auth
import Foundation
import Supabase

@MainActor
@Observable
final class AuthService {
    private let supabase = SupabaseService.shared.client

    var isAuthenticated = false
    var isLoading = true
    var currentUserId: UUID?

    /// Set true when a refresh attempt fails — the persisted refresh token is
    /// expired/revoked and the user must sign in again. ContentView watches this
    /// flag to bounce the user to the sign-in screen instead of letting saves
    /// 401 silently.
    var needsReauthentication = false

    var isDevBypass = false

    init() {
        Task { await checkSession() }
    }

    func checkSession() async {
        isLoading = true
        defer { isLoading = false }

        if isDevBypass, DevSignIn.isAllowed { return }

        do {
            let session = try await supabase.auth.session
            currentUserId = session.user.id
            isAuthenticated = true
        } catch {
            isAuthenticated = false
            currentUserId = nil
        }
    }

    /// Force-refresh the Supabase session. Called on app launch and on
    /// `scenePhase` → `.active` so the JWT is fresh before any writes fire.
    /// If the refresh token is itself expired/revoked, sets
    /// `needsReauthentication = true` so the UI can prompt for sign-in.
    func refreshIfNeeded() async {
        if isDevBypass { return }
        do {
            _ = try await supabase.auth.refreshSession()
            let session = try await supabase.auth.session
            currentUserId = session.user.id
            isAuthenticated = true
            needsReauthentication = false
        } catch {
            print("[Auth] refresh failed: \(error)")
            needsReauthentication = true
            isAuthenticated = false
            currentUserId = nil
        }
    }

    func devSignIn() {
        guard DevSignIn.isAllowed else { return }
        currentUserId = UUID()
        isAuthenticated = true
        isDevBypass = true
        SupabaseService.shared.isOffline = true
    }

    func signInWithApple(authorization: ASAuthorization, rawNonce: String?) async throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8)
        else {
            throw AppleSignInError.missingIdentityToken
        }

        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: identityToken,
                    nonce: rawNonce
                )
            )

            currentUserId = session.user.id
            isAuthenticated = true
        } catch let error as AuthError {
            if case let .api(message, code, _, _) = error, code == .providerDisabled {
                throw AppleSignInError.providerDisabled(serverMessage: message)
            }
            throw error
        }
    }

    func signOut() async throws {
        if isDevBypass {
            isDevBypass = false
            isAuthenticated = false
            currentUserId = nil
            SupabaseService.shared.isOffline = false
            LocalCacheService.clearAll()
            PlanCacheService.clear()
            return
        }
        try await supabase.auth.signOut()
        isAuthenticated = false
        currentUserId = nil
        LocalCacheService.clearAll()
        PlanCacheService.clear()
    }
}

enum AppleSignInError: LocalizedError {
    case missingIdentityToken
    case providerDisabled(serverMessage: String)

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            "Apple Sign-In did not return an identity token."
        case .providerDisabled:
            Self.providerDisabledUserMessage
        }
    }

    /// Supabase returns `provider_disabled` when Apple is off or the bundle ID is not in Client IDs.
    private static let providerDisabledUserMessage = """
    Sign in with Apple is not enabled for this Supabase project. In the dashboard open Authentication → Providers → Apple, turn it on, and under Client IDs add your iOS bundle ID (e.g. com.jatler.Training). Native-only apps do not need the OAuth secret.
    """
}
