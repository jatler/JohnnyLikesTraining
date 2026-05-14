import Foundation
import Supabase

@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    /// When true, all stores skip Supabase reads/writes (dev bypass mode with no real auth session).
    var isOffline = false

    /// Callback fired when a Supabase write returns a 401/403. Allows AuthService
    /// to flip `needsReauthentication` without SupabaseService having to import
    /// or own AuthService. Wired up in TrainingApp at startup.
    var onAuthFailure: (() -> Void)?

    private init() {
        client = SupabaseClient(
            supabaseURL: Config.supabaseURL,
            supabaseKey: Config.supabaseAnonKey,
            options: .init(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }

    /// Run a Supabase request and surface structured failure info.
    ///
    /// `body` should perform the full chain (`.from(...).upsert(...).execute()`).
    /// On success the value is returned in `.success`. On failure the caller
    /// gets a `PersistenceError` carrying the HTTP code, PostgREST message, and
    /// hint — enough to either show a useful alert or decide to silently retry.
    ///
    /// 401/403 also flips `onAuthFailure` so the UI can bounce to sign-in.
    @discardableResult
    func execute<T>(
        table: String,
        operation: String,
        _ body: () async throws -> T
    ) async -> Result<T, PersistenceError> {
        do {
            let value = try await body()
            return .success(value)
        } catch {
            let err = PersistenceError.from(error, table: table, operation: operation)
            print(err.description)
            if err.isAuthFailure {
                onAuthFailure?()
            }
            return .failure(err)
        }
    }
}

/// Structured error from a Supabase write. Wraps the underlying SDK error and
/// pulls the human-readable fields out of `HTTPError` / `PostgrestError` so the
/// caller can decide whether to show an alert (and what to show) or to silently
/// re-queue.
struct PersistenceError: Error, CustomStringConvertible {
    let table: String
    let operation: String
    let httpCode: Int?
    let postgrestCode: String?
    let postgrestMessage: String?
    let hint: String?
    let underlying: Error

    var isAuthFailure: Bool {
        httpCode == 401 || httpCode == 403
    }

    /// Retryable: network/timeout/5xx/429/408. Auth and 4xx-validation failures
    /// are NOT retryable — they need a code or user action to fix.
    var isRetryable: Bool {
        if isAuthFailure { return false }
        if let c = httpCode {
            if c == 408 || c == 429 { return true }
            if (500...599).contains(c) { return true }
            return false
        }
        // No HTTP code at all → URLError / network / serialization issue → retryable.
        return true
    }

    /// What to show in an `.alert(...)` when this error is non-retryable.
    var userFacing: String {
        if isAuthFailure { return "Session expired — please sign in again." }
        if let msg = postgrestMessage, !msg.isEmpty {
            return msg
        }
        return underlying.localizedDescription
    }

    var description: String {
        var parts: [String] = [
            "[Supabase] \(operation) \(table) failed"
        ]
        if let c = httpCode { parts.append("status=\(c)") }
        if let c = postgrestCode { parts.append("code=\(c)") }
        if let m = postgrestMessage { parts.append("message=\(m)") }
        if let h = hint { parts.append("hint=\(h)") }
        parts.append("underlying=\(underlying)")
        return parts.joined(separator: " | ")
    }

    static func from(_ error: Error, table: String, operation: String) -> PersistenceError {
        // HTTPError carries the raw response body — try to parse a PostgrestError
        // shape out of it for the friendliest message.
        if let http = error as? HTTPError {
            let code = http.response.statusCode
            if let pgErr = try? JSONDecoder().decode(PostgrestError.self, from: http.data) {
                return PersistenceError(
                    table: table,
                    operation: operation,
                    httpCode: code,
                    postgrestCode: pgErr.code,
                    postgrestMessage: pgErr.message,
                    hint: pgErr.hint,
                    underlying: error
                )
            }
            // No JSON body or unrecognized shape — still carry the status code.
            let bodyMessage = String(data: http.data, encoding: .utf8)
            return PersistenceError(
                table: table,
                operation: operation,
                httpCode: code,
                postgrestCode: nil,
                postgrestMessage: bodyMessage,
                hint: nil,
                underlying: error
            )
        }
        if let pgErr = error as? PostgrestError {
            return PersistenceError(
                table: table,
                operation: operation,
                httpCode: nil,
                postgrestCode: pgErr.code,
                postgrestMessage: pgErr.message,
                hint: pgErr.hint,
                underlying: error
            )
        }
        return PersistenceError(
            table: table,
            operation: operation,
            httpCode: nil,
            postgrestCode: nil,
            postgrestMessage: nil,
            hint: nil,
            underlying: error
        )
    }
}
