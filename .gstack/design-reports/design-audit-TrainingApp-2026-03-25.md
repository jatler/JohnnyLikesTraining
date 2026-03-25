# Design Audit — Training App (iOS/SwiftUI)
**Date:** 2026-03-25
**Type:** Source-code audit (native iOS app — browse daemon not applicable)
**Classifier:** APP UI — utility, data-dense, task-focused training companion

---

## First Impression

The app communicates **competence and seriousness**. The TabView architecture with Today/Week/Strength/Progress/Settings is well-chosen for a training companion app. I notice the color palette is generous to the point of being distracting — nearly every data type gets its own tint color, which makes the UI feel more like a data visualization than a calm daily driver. The first 3 things a user's eye would go to: (1) the Oura recovery card with its multicolor metrics, (2) session cards with colored icons, (3) action buttons in their various tints. If I had to describe this in one word: **capable-but-busy**.

---

## Inferred Design System

### Typography
- **Scale:** System font stack exclusively (`.largeTitle.bold`, `.headline`, `.subheadline`, `.body`, `.caption`, `.caption2`). Appropriate for native iOS — system fonts are the right call here.
- **Grade: A** — correct use of the iOS type system with no custom fonts to manage.

### Colors
Accent colors in active use:
`.blue`, `.orange`, `.green`, `.red`, `.purple`, `.teal`, `.indigo`, `.primary`, `.secondary`, `.tertiary`, `.quaternary`

That's **7 distinct accent hues** plus 4 semantic text levels. The palette is unstructured — each data type picks its own color:
- Strava = orange, Oura = purple, strength = indigo, stretch = teal, heat = orange (conflict with Strava!), running = blue, completed = green, skipped/error = red

Heat and Strava both use `.orange` — that's a meaning collision.

### Spacing
Mixed spacing values in use: 2, 4, 6, 8, 10, 12, 16, 20, 24, 32, 40
An 8pt grid would allow: 8, 16, 24, 32, 40.
`VStack(spacing: 20)` in TodayView and `VStack(spacing: 6)` in several sub-components are not on the 8pt grid.

### Materials
Three different materials used across the app:
- `.regularMaterial` — Today recovery card, Progress cards
- `.bar` — Week navigator
- `.ultraThinMaterial` — Week summary bar

No consistent rule for which material tier applies where.

---

## Findings

### FINDING-001 [HIGH] — Seven accent colors creates a visual circus
**File:** Multiple views (TodayView, WeekView, StrengthTemplateView, etc.)

The app currently uses 7+ distinct accent colors as data-type identifiers. For an APP UI, the rule is: calm surface hierarchy, few colors. Each new color demands cognitive attention to learn and track. Heat and Strava both use `.orange`, creating a meaning ambiguity.

**Recommended palette reduction:**
- Keep semantic: green (completed), red (error/skipped)
- Pick ONE primary accent (blue is already dominant)
- Replace indigo/teal/purple with tinted opacity variants of one accent or semantic gray
- Heat = distinguish with a warm tint at 40% opacity, not a competing orange

**Impact:** Reading the week view means decoding 6 colors simultaneously. That's friction.

### FINDING-002 [HIGH] — Recovery card uses 4 colors for 4 metrics
**File:** `TodayView.swift` — `recoveryCard` section

Readiness, Sleep, HRV, RHR each get distinct colors: readiness=dynamic, sleep=.blue, HRV=.purple, RHR=.red. These colors have no semantic meaning (red doesn't mean bad for RHR here — it's just "that's the RHR color"). A user has to decode the color legend rather than reading state.

**Fix:** Use ONE color per semantic state: green (optimal), yellow (fair), red (low). Apply it based on the score range, not the metric name. The metric label is sufficient to distinguish — color should only encode state.

### FINDING-003 [HIGH] — Week row information density is too high
**File:** `WeekView.swift` — `sessionRow()` method

Each row packs: day-of-week column, workout icon with colored background, workout name, override indicator (pencil), strength badge with label, heat badge (tappable), stretch badge (tappable), distance, pace, strength completion count, Strava checkmark with mileage, skipped label. On a 375pt-wide phone, this row is attempting to do too many things at once. The heat and stretch badges are tiny `Label` buttons with `.caption2` font — 11pt text as touch targets, almost certainly under 44pt.

**Fix:** Move supplemental info (heat, stretch, strength badges) to a secondary row or summary pill. Primary row: date column + icon + name + completion state. Secondary row: any addon activities.

### FINDING-004 [MEDIUM] — Icon-in-colored-RoundedRect pattern in week rows
**File:** `WeekView.swift` — `sessionRow()` line:
```swift
Image(systemName: session.workoutType.iconName)
    .background(session.workoutType.swiftUIColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
```

This is the iOS-app equivalent of the "icon in colored circle" SaaS pattern — each workout type gets its own tinted box. This compounds the 7-color problem and makes rows feel like icon stickers rather than clean data.

**Fix:** Use the icon without a background, relying on color + label text for type identification. Or use a monochrome icon with only the workout name colored. Less decoration, more hierarchy.

### FINDING-005 [MEDIUM] — Material inconsistency between navigator and summary bar
**File:** `WeekView.swift`

`weekNavigator` uses `.background(.bar)` while `weekSummaryBar` uses `.background(.ultraThinMaterial)`. These are adjacent UI elements — `.bar` is darker/more opaque than `.ultraThinMaterial` in both light and dark mode. The visual boundary between them will be noticeable.

**Fix:** Standardize to `.bar` for both, or `.ultraThinMaterial` for both. `.bar` is the more appropriate choice for navigation chrome elements that need visual separation from content.

### FINDING-006 [MEDIUM] — Spacing not on 8pt grid
**File:** `TodayView.swift` — `todayContent` body

```swift
VStack(spacing: 20) {  // should be 24
```

Also throughout: `spacing: 6`, `spacing: 10`, `spacing: 2` — these fractional values accumulate into inconsistent rhythm. The 8pt grid values are: 4, 8, 16, 24, 32, 40. Minor increments like 2, 6, 10 should be replaced with 4, 8.

**Fix:** `VStack(spacing: 20)` → `VStack(spacing: 24)` in `todayContent`. Sub-component spacing: 2 → 4, 6 → 8, 10 → 8.

### FINDING-007 [MEDIUM] — ContentView uses wrong animation easing for enter/exit transition
**File:** `ContentView.swift`

```swift
.animation(.easeInOut, value: auth.isAuthenticated)
```

Per animation best practices: entering elements should use `.easeOut` (decelerates as it arrives), exiting elements `.easeIn` (accelerates as it leaves). `.easeInOut` is for moving/repositioning. The sign-in → main app transition is an enter event.

**Fix:**
```swift
.animation(.easeOut(duration: 0.3), value: auth.isAuthenticated)
```

### FINDING-008 [MEDIUM] — Three-circle compliance stat is the generic "3 metrics" pattern
**File:** `ProgressDashboardView.swift` — `complianceCard`

Three donut circles for Completed/Skipped/Remaining is extremely common in fitness/health apps — it reads as template, not designed. The three circles also encode a logical whole (total sessions), so they'd be better as one donut ring with three segments.

**Fix:** Use a single segmented progress ring: green segment (completed), red segment (skipped), gray segment (remaining). More compact, more visually interesting, and encodes the same data more accurately.

### FINDING-009 [MEDIUM] — Sign-in screen uses system icon as brand mark
**File:** `SignInView.swift`

```swift
Image(systemName: "figure.run")
    .font(.system(size: 64))
    .foregroundStyle(.blue)
```

`figure.run` is a generic SF Symbol used in thousands of apps. For a sign-in screen, this is the app's only brand impression. The copy below it ("Training" + "Your running plan, daily.") is solid, but the mark reads as placeholder.

**Recommendation:** Replace with an `Image("AppIcon")` asset rendered at 64pt, or design a simple wordmark. If sticking with SF Symbol, at minimum, add a circle/background shape to give it context and prevent it from looking like a floating stock icon.

### FINDING-010 [POLISH] — Empty states are functional but cold
**File:** Multiple views (WeekView, ProgressDashboardView, StrengthTemplateView)

Pattern: system icon + "No X yet" + explanatory sentence. These work but don't feel warm or encouraging for a training app. A user who just installed and sees "No data yet" with a generic bar chart icon feels deflated.

**Fix:** Add an action button to each empty state. WeekView: "Set Up Your Plan" → triggers PlanSetupView. Progress: "Import from Strava" or "Create Your First Plan". The system icons are fine for utility apps; the gap is in the call-to-action.

### FINDING-011 [POLISH] — Deload badge style vs L+R badge style are inconsistent
**File:** `StrengthDayDetailView.swift` and `StretchDayDetailView` (via StretchLogSheet)

Deload badge:
```swift
.padding(.horizontal, 6).padding(.vertical, 2).background(.orange.opacity(0.15), in: Capsule())
```
L+R badge in stretch:
```swift
.padding(.horizontal, 5).padding(.vertical, 1).background(.quaternary, in: Capsule())
```
These "pill badge" components are duplicated with slightly different paddings (5 vs 6, 1 vs 2) and background styles. Should be a shared `BadgeView` component with consistent padding (8×4 or 6×2).

---

## AI Slop Assessment

For a native iOS app, the web-centric AI slop patterns translate as:
- ✅ No purple-on-white gradient backgrounds
- ⚠️ Icon-in-colored-box pattern (Finding-004)
- ⚠️ 3-column/3-circle metric grid (Finding-008)
- ✅ No wavy SVG dividers
- ✅ No emoji as decoration
- ✅ No generic hero copy
- ✅ Good use of native materials and components

**AI Slop Score: B** — The app avoids the worst patterns but has two recognizable SaaS/template patterns adapted to iOS.

---

## Scores

| Category | Grade | Key Issue |
|----------|-------|-----------|
| Visual Hierarchy | C | Too many competing colors (Finding-001) |
| Typography | A | Correct iOS font system usage |
| Spacing & Layout | C | Off-grid values, dense rows (Finding-003, 006) |
| Color & Contrast | D | 7 accent hues, semantic collision (Finding-001, 002) |
| Interaction States | B | Loading/disabled states present; touch targets on badges risky (Finding-003) |
| Responsive | A | Native iOS — no responsive issues |
| Content Quality | B | Functional copy, cold empty states |
| AI Slop | B | Two template patterns |
| Motion | C | Wrong easing on ContentView (Finding-007) |
| Performance | A | Native app; no web perf concerns |

**Design Score: C+** (strong bones, color discipline is the main drag)
**AI Slop Score: B**

---

## Quick Wins (< 30 min each)

1. **ContentView easing** — 1 line change. `easeInOut` → `easeOut(duration: 0.3)`. (`ContentView.swift:14`)
2. **TodayView spacing** — `spacing: 20` → `spacing: 24`. (`TodayView.swift` — `todayContent`)
3. **WeekView material consistency** — `weekSummaryBar` `.ultraThinMaterial` → `.bar`. (`WeekView.swift`)
4. **Empty state CTAs** — Add a primary action button to each empty state view. (~15 min per view)
5. **Recovery card colors** — Convert Sleep/HRV/RHR colors to semantic state colors rather than type-identity colors. (`TodayView.swift` — `recoveryCard`)

---

## Fix Plan

The following will be applied as atomic commits:
- FINDING-007: ContentView animation easing
- FINDING-006: TodayView spacing onto 8pt grid
- FINDING-005: WeekView material consistency
- FINDING-010: Empty state CTAs (Today + Week + Progress)

Higher-impact systemic fixes (FINDING-001 color reduction, FINDING-003 row density, FINDING-008 compliance ring) require larger changes and will be presented as recommendations rather than auto-applied.

---

## PR Summary
Design review found 11 issues (3 high, 5 medium, 3 polish). Applying 4 quick fixes. Design Score: C+ → aiming for B−. Main remaining opportunity: color discipline and row density in WeekView.
