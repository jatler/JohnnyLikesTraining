import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Brand Colors

extension Color {
    static let trailGreen = Color("AccentColor")
    static let trailGreenLight = Color.trailGreen.opacity(0.12)
    static let trailGreenSubtle = Color.trailGreen.opacity(0.06)
    /// Elevation accent — the only non-green/orange chart color in the app.
    /// Used by the Vert lollipop chart and the Vert stat in the focused-week
    /// card, where it ties the stat to its chart.
    static let trailPurple = Color(red: 0.541, green: 0.420, blue: 0.820) // #8A6BD1
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

// MARK: - Unified Card Chrome
//
// The standard card surface used across every detail sheet (WeekView's
// SessionDetailSheet, StrengthDayDetailView, HeatLogSheet, StretchDayDetailView).
// One source of truth so the chrome stays consistent if the design tokens shift.

extension View {
    func unifiedCard(padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
    }
}
