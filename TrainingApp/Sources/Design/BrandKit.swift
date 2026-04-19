import SwiftUI

// MARK: - Brand Colors

extension Color {
    static let trailGreen = Color("AccentColor")
    static let trailGreenLight = Color.trailGreen.opacity(0.12)
    static let trailGreenSubtle = Color.trailGreen.opacity(0.06)
}

// MARK: - Typography

enum TrailFont {
    static let title = Font.custom("GeistMono-Medium", size: 20, relativeTo: .headline)
    static let body  = Font.system(size: 17, weight: .regular, design: .default)
    static let meta  = Font.system(size: 12, weight: .regular, design: .default)
    static let coach = Font.custom("Fraunces-Medium", size: 16, relativeTo: .body)
    static let data  = Font.custom("GeistMono-Regular", size: 13, relativeTo: .caption)
    // Tab-level display heading: Fraunces for dynamic tab titles (Week 11, Progress, Strength, Settings).
    static let tabHeading = Font.custom("Fraunces-Medium", size: 28, relativeTo: .largeTitle)
    // Big stat numbers in cards (focused-week stats, race-card days count). Replaces inline .custom() escapes.
    static let bigNumber = Font.custom("GeistMono-Medium", size: 20, relativeTo: .title3)
}

// MARK: - Brand Constants

enum BrandKit {
    static let appName = "SWAP Training"
    static let coachCredit = "David & Megan Roche"
    static let tagline = "Train with David & Megan Roche."
    static let patreonURL = URL(string: "https://www.patreon.com/swap?utm_source=app&utm_medium=paywall")!
}
