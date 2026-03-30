import Foundation
import Supabase

@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    /// When true, all stores skip Supabase reads/writes (dev bypass mode with no real auth session).
    var isOffline = false

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
