import SwiftUI

extension Color {
    static let swapAccent = Color("AccentColor")
    static let swapAccentLight = Color.swapAccent.opacity(0.12)
    static let swapAccentSubtle = Color.swapAccent.opacity(0.06)
}

enum BrandKit {
    static let appName = "SWAP Training"
    static let coachCredit = "David & Megan Roche"
    static let tagline = "Train with David & Megan Roche."
    static let patreonURL = URL(string: "https://www.patreon.com/swap?utm_source=app&utm_medium=paywall")!
}
