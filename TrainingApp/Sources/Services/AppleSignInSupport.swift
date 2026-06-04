import CryptoKit
import Foundation
import Security

enum DevSignIn {
    /// Debug-only. Release builds have no path to bypass sign-in — App Store
    /// reviewers must use real credentials.
    static var isAllowed: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}

enum AppleSignInNonce {
    static func randomString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")

        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256Hex(_ input: String) -> String {
        let data = Data(input.utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
