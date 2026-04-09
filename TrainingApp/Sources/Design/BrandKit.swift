import SwiftUI

// MARK: - Brand Colors

extension Color {
    static let trailGreen = Color("AccentColor")
    static let trailGreenLight = Color.trailGreen.opacity(0.12)
    static let trailGreenSubtle = Color.trailGreen.opacity(0.06)
}

// MARK: - Typography

enum TrailFont {
    static let title      = Font.custom("Fraunces-Medium", size: 20, relativeTo: .headline)
    static let titleBold  = Font.custom("Fraunces-SemiBold", size: 20, relativeTo: .headline)
    static let body       = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyBold   = Font.system(size: 17, weight: .semibold, design: .default)
    static let detail     = Font.system(size: 15, weight: .regular, design: .default)
    static let detailBold = Font.system(size: 15, weight: .semibold, design: .default)
    static let meta       = Font.system(size: 12, weight: .regular, design: .default)
    static let metaBold   = Font.system(size: 12, weight: .semibold, design: .default)
    static let coach      = Font.system(size: 15, weight: .regular, design: .default)
    static let data       = Font.custom("GeistMono-Regular", size: 13, relativeTo: .caption)
    static let dataBold   = Font.custom("GeistMono-Medium", size: 13, relativeTo: .caption)
    static let dataLarge  = Font.custom("GeistMono-Medium", size: 24, relativeTo: .title)
    static let dataHero   = Font.custom("GeistMono-Medium", size: 28, relativeTo: .largeTitle)
}

// MARK: - Brand Constants

enum BrandKit {
    static let appName = "SWAP Training"
    static let coachCredit = "David & Megan Roche"
    static let tagline = "Train with David & Megan Roche."
    static let patreonURL = URL(string: "https://www.patreon.com/swap?utm_source=app&utm_medium=paywall")!
}
