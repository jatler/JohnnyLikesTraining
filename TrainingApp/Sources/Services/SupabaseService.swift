import Foundation
import Supabase

@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    /// When true, all stores skip Supabase reads/writes (dev bypass mode with no real auth session).
    var isOffline = false

    /// Base URL for Supabase Edge Functions (e.g. https://<project>.supabase.co/functions/v1).
    static var edgeFunctionBaseURL: String {
        return "\(shared.client.supabaseURL)/functions/v1"
    }

    private init() {
        client = SupabaseClient(
            supabaseURL: Config.supabaseURL,
            supabaseKey: Config.supabaseAnonKey,
            options: .init(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }
}
