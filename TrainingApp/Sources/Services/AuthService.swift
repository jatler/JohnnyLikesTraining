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

    /// True when the last session check or refresh failed because Supabase
    /// could not be reached — device offline, DNS failure, timeout, a 5xx, or
    /// a paused project. The persisted session is kept and the user stays
    /// signed in on local caches; writes fail as retryable and re-queue.
    /// Cleared by the next successful refresh (foreground, pull-to-refresh).
    var isServerUnreachable = false

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
            applySignedIn(session)
        } catch {
            handleSessionFailure(error, context: "checkSession")
        }
    }

    /// Force-refresh the Supabase session. Called on app launch and on
    /// `scenePhase` → `.active` so the JWT is fresh before any writes fire.
    ///
    /// Only a genuine token rejection (400/401/403 from the auth endpoint,
    /// or no stored session at all) signs the user out. A server that can't
    /// be reached keeps the persisted session and flips `isServerUnreachable`
    /// instead — signing out there would strand the user on a sign-in screen
    /// that can't succeed either, with their whole plan sitting in the cache.
    func refreshIfNeeded() async {
        if isDevBypass { return }
        do {
            let session = try await supabase.auth.refreshSession()
            applySignedIn(session)
        } catch {
            handleSessionFailure(error, context: "refresh")
        }
    }

    private func applySignedIn(_ session: Session) {
        currentUserId = session.user.id
        isAuthenticated = true
        needsReauthentication = false
        isServerUnreachable = false
    }

    private func handleSessionFailure(_ error: Error, context: String) {
        if Self.isTransientSessionFailure(error),
           let cached = supabase.auth.currentSession {
            print("[Auth] \(context) failed but server is unreachable — staying signed in on the cached session: \(error)")
            currentUserId = cached.user.id
            isAuthenticated = true
            needsReauthentication = false
            isServerUnreachable = true
            return
        }

        print("[Auth] \(context) failed — session rejected, sign-in required: \(error)")
        needsReauthentication = true
        isAuthenticated = false
        currentUserId = nil
        isServerUnreachable = false
    }

    /// Classifies a failure from `auth.session` / `auth.refreshSession`.
    ///
    /// Returns `true` when the failure says nothing about the validity of the
    /// stored refresh token — the request never got a verdict from GoTrue.
    /// Returns `false` when the server explicitly rejected the session
    /// (`sessionMissing`, or a 4xx auth response such as
    /// `refresh_token_not_found` / `refresh_token_already_used`), which is the
    /// only case where the user must sign in again.
    nonisolated static func isTransientSessionFailure(_ error: Error) -> Bool {
        if let authError = error as? AuthError {
            switch authError {
            case .sessionMissing:
                return false
            case let .api(_, _, _, response):
                return Self.isTransientStatus(response.statusCode)
            default:
                return false
            }
        }
        if let http = error as? HTTPError {
            return Self.isTransientStatus(http.response.statusCode)
        }
        if error is URLError { return true }
        if error is CancellationError { return true }
        // A paused project serves an HTML holding page, which surfaces as a
        // decoding failure rather than an auth error — treat like any other
        // non-verdict from the server.
        return true
    }

    private nonisolated static func isTransientStatus(_ status: Int) -> Bool {
        status >= 500 || status == 408 || status == 429
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
