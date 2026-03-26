# Design System — SWAP Training

## Product Context
- **What this is:** A training plan companion app for runners following David & Megan Roche's SWAP Running training methodology
- **Who it's for:** SWAP Running Patreon subscribers ($5+/month)
- **Space/industry:** Running / endurance sport training apps
- **Project type:** iOS native app (SwiftUI, iOS 17+)

---

## Brand

- **App name:** SWAP Training
- **Display name (home screen):** SWAP Training
- **Coach credit:** David & Megan Roche
- **Tagline:** "Train with David & Megan Roche."
- **Access gate:** SWAP Running Patreon subscribers only

All brand strings are defined in `Sources/Design/BrandKit.swift` — do not hardcode them in views.

---

## Accent Color — SWAP Green

SWAP green is the single identity color. It appears on tab bar icons, buttons, badges, charts, and progress indicators.

| Mode       | Hex       | RGB (float)              | Usage                        |
|------------|-----------|--------------------------|------------------------------|
| Light mode | `#008D55` | R:0.000 G:0.553 B:0.333  | Primary accent               |
| Dark mode  | `#00B068` | R:0.000 G:0.690 B:0.408  | Primary accent (brightened ~25%) |

### Color Tokens

All token usage goes through `Color.swapAccent` (and its opacity variants) — never hardcode hex values in views.

```swift
Color.swapAccent        // Primary accent — full opacity
Color.swapAccentLight   // swapAccent.opacity(0.12) — chip/badge backgrounds
Color.swapAccentSubtle  // swapAccent.opacity(0.06) — row highlight backgrounds
```

Defined in `Sources/Design/BrandKit.swift`. The `AccentColor` asset at
`Resources/Assets.xcassets/AccentColor.colorset/` provides automatic light/dark adaptation.

### System Integration

The tab bar is tinted with `.tint(Color.swapAccent)` in `ContentView`. All SwiftUI
controls that respond to `accentColor` (pickers, sliders, progress views, toggles,
bordered prominent buttons) automatically use SWAP green.

---

## Typography

System font stack only (SF Pro) — no custom fonts. SwiftUI `.font()` modifiers throughout.

### Scale

| Role               | SwiftUI style                           | Weight        | Notes                              |
|--------------------|-----------------------------------------|---------------|------------------------------------|
| App wordmark       | `.system(size: 52, weight: .black)`     | Black (900)   | "SWAP" in sign-in screen           |
| Screen title       | `.largeTitle` / `.title`                | Bold (700)    | NavigationStack titles             |
| Card heading       | `.title2.bold()`                        | Bold (700)    | Primary card labels                |
| Section heading    | `.headline`                             | Semibold (600)| Bold, primary text color           |
| Body               | `.body`                                 | Regular (400) | Default reading size               |
| Subheadline        | `.subheadline`                          | Regular (400) | Supporting/secondary text          |
| Caption            | `.caption`                              | Regular (400) | Tertiary information               |
| Caption 2          | `.caption2`                             | Regular (400) | Badges, compact labels             |
| Monospace stats    | `.title3.bold().monospacedDigit()`      | Bold (700)    | Distance, pace, progress counts    |

### Rules

- **Weight contrast is hierarchy.** Headings must be visibly heavier than body text. Never use `.regular` for a heading or `.bold` for supporting text.
- **Two weights per card maximum.** Each card-level component uses at most two distinct weights — one for the label, one for the value or body.
- **Stats always monospaced.** Any numeric display (miles, pace, heart rate, set counts) uses `.monospacedDigit()` to prevent layout shift as numbers change.
- **Secondary text uses `.secondary` foreground color**, not a lighter weight. Weight changes meaning; color changes hierarchy.
- **Never use `.caption` weight for interactive labels.** Buttons and tappable text must be at minimum `.subheadline` size.

---

## Spacing

Base unit: **8pt**. Use multiples of 8 for all padding and spacing. Use multiples of 4 for micro-spacing (2, 4) where tighter gaps are needed.

Standard padding:
- Compact: `4`
- Default: `8`
- Card inner: `12`
- Section: `16`
- Screen edge: `16` (or `.padding()`)
- Between cards: `12`

---

## Border Radius

| Context                    | Value              |
|----------------------------|--------------------|
| Card / session row         | `cornerRadius: 12` |
| Chip / badge               | `cornerRadius: 8`  |
| Small icon background      | `cornerRadius: 8`  |
| Capsule / pill             | `Capsule()`        |
| Bottom sheet / full-screen | System (`.presentationDetents`) |

---

## Sheets

Paywall (`PatreonGateView`) and confirmation sheets use `.medium` detent with `.presentationDragIndicator(.visible)`. Never full-screen for lightweight confirmation actions.

---

## Icons

Use SF Symbols throughout. Icon selections per context:

| Context               | Symbol                          | Color          |
|-----------------------|---------------------------------|----------------|
| App / sign-in hero    | `figure.run.circle.fill`        | `swapAccent`   |
| SWAP plan badge       | `checkmark.seal.fill`           | `swapAccent`   |
| Patreon connected     | `star.circle.fill`              | `swapAccent`   |
| Patreon not-patron    | `star.circle`                   | `.secondary`   |
| Network error         | `wifi.exclamationmark`          | `.secondary`   |
| Override indicator    | `pencil.circle.fill`            | `.orange`      |
| Strength              | `dumbbell.fill`                 | `swapAccent`   |
| Heat                  | `flame.fill`                    | `.orange`      |
| Stretch               | `figure.flexibility`            | `swapAccent`   |
| Completed             | `checkmark.circle.fill`         | `.green`       |
| Chevron navigation    | `chevron.left` / `chevron.right` | `.secondary`  |

**Color rule:** SWAP green (`Color.swapAccent`) is used for all activity-type icons (running, strength, stretch). `.orange` is reserved for heat (fire semantics) and override indicators. `.green` is reserved for completion states only. Never use `.indigo`, `.teal`, `.blue`, or `.purple` for icons.

---

## Charts (Swift Charts)

Weekly mileage bars in `ProgressDashboardView`:

| Series        | Color                             |
|---------------|-----------------------------------|
| Planned miles | `Color.swapAccent.opacity(0.25)`  |
| Actual miles  | `Color.swapAccent`                |
| Current week  | `Color.swapAccent` label + `Color.swapAccentSubtle` row background |

---

## Empty States

Every empty state requires: a contextual SF Symbol (in `Color.swapAccent`), a title, a supporting message, and a primary CTA button (`.borderedProminent`).

---

## Paywall — PatreonGateView

Sheet gating Patreon-exclusive features. Four user-visible states:

| State         | Trigger                              | Primary action               |
|---------------|--------------------------------------|------------------------------|
| Not connected | No Patreon token in Keychain         | "Connect Patreon" button     |
| Verifying     | OAuth in progress                    | `ProgressView`               |
| Not patron    | Connected but `patron_status != active_patron` or cents < 500 | "Subscribe on Patreon ↗" link |
| Network error | `authorize()` throws                 | "Try Again" button           |

When `patreon.isPatron` becomes true, the sheet auto-dismisses and calls `onPatronVerified?()`.

Membership is re-verified at most once per 7 days (cached in Keychain as `patreonLastVerifiedAt`). A 7-day grace period applies when patron status lapses (stored as `patreonGracePeriodStart`).

---

## Decisions Log

| Date       | Decision                                                        | Rationale                                                                      |
|------------|-----------------------------------------------------------------|--------------------------------------------------------------------------------|
| 2026-03-25 | SWAP green `#008D55` as single accent color                     | Matches SWAP Running brand; leverages `AccentColor` asset for automatic system-wide tinting |
| 2026-03-25 | Text wordmark on sign-in ("SWAP" + "Training") instead of icon | Stronger brand impression at first launch than a generic SF Symbol icon        |
| 2026-03-25 | Patreon paywall gating all plan features                        | App is exclusive to SWAP Patreon subscribers                                   |
| 2026-03-25 | `.medium` sheet for PaywallGateView                             | Lightweight — doesn't replace root navigation; dismisses automatically on verify |
| 2026-03-25 | System font (SF Pro) only — no custom fonts                     | iOS native feel; no font loading overhead; excellent legibility at all weights  |
| 2026-03-25 | `BrandKit.swift` for all brand strings and color tokens         | Single source of truth; avoids hardcoded strings scattered across view files   |
| 2026-03-26 | Collapsed icon palette to swapAccent + orange + green only      | Removed `.indigo` (strength) and `.teal` (stretch) — too many accent colors created visual noise; green unifies all activity types |
| 2026-03-26 | Pull-to-refresh on TodayView triggers Oura + Strava reload      | Users need a manual way to force-sync integrations; SwiftUI `.refreshable` on the main `ScrollView` is the native iOS pattern |
| 2026-03-26 | Typography weight contrast rules added                          | SF Pro has 9 weights; using only 2-3 per screen creates clear hierarchy without custom fonts |
