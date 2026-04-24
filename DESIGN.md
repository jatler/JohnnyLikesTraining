# Design System — SWAP Training

## Product Context
- **What this is:** A native iOS training app that digitizes David & Megan Roche's SWAP Running coaching plans
- **Who it's for:** SWAP athletes training for ultramarathons and trail races
- **Space/industry:** Endurance running, coaching-led training
- **Project type:** iOS app (SwiftUI) + marketing website
- **Personality:** Calm, focused, coach-led. Like a trusted training journal, not a data dashboard. Not flashy, not gamified.

## Aesthetic Direction
- **Direction:** Organic/Natural meets Editorial
- **Decoration level:** Intentional (subtle warmth and texture, no flashiness)
- **Mood:** Grounded, personal, warm. The app should feel like opening a coach's notebook. The website should read like a letter to athletes, not a SaaS landing page.
- **Reference sites:** runna.com (dark app showcase), vdoto2.com (coach-forward), trainingpeaks.com (what NOT to do, dated/corporate)

## Typography

Three font families, five tokens. No aliases, no size variants.

### Font Families

| Font          | Role                                     | Weights used    |
|---------------|------------------------------------------|-----------------|
| Geist Mono    | Tab titles, section headers, data/stats  | Regular, Medium |
| SF Pro (system) | Body UI copy, metadata, captions       | Regular, Semibold (inline) |
| Fraunces      | Coach voice (prose only)                 | Medium          |

### iOS Token Reference (`TrailFont.*`)

| Token         | Font           | Size | Weight | Usage                                                              |
|---------------|----------------|------|--------|--------------------------------------------------------------------|
| `tabHeading`  | Fraunces       | 28pt | 500    | Top-of-tab display titles: "Week 11", "Progress", "Strength", "Settings" — the first thing you see on each tab |
| `title`       | Geist Mono     | 20pt | 500    | In-tab section headers, workout-type names, numeric dates          |
| `body`        | SF Pro         | 17pt | 400    | Primary UI text: exercise names, descriptions, form copy           |
| `meta`        | SF Pro         | 12pt | 400    | Metadata: dates, badges, counts, attribution, small captions       |
| `coach`       | Fraunces       | 16pt | 500    | Coach notes prose only — the one place serif voice is allowed       |
| `data`        | Geist Mono     | 13pt | 400    | Inline stats: distance, pace, HR, elevation, Oura scores, sets×reps |

When a variant needs emphasis, apply `.fontWeight(.semibold)` inline at the call site — do not add a new token.

### When to Use Each Font

**Fraunces (`tabHeading`, `coach`):**
- Tab display headings ("Week 11", "Progress", "Strength & More", "Settings") — sets the warm, editorial personality at each tab's entry point.
- Coach notes prose (`coach`) — the only place serif runs as body text.

**Geist Mono (`title`, `data`):**
- In-tab section headers ("Week 12 done", "Heat", weekday/numeric date columns) and workout-type names ("Long Run", "Tempo") — rendered as-is (title case).
- All numerical values: distances, paces, durations, HR, elevation, scores, prescriptions.
- Uppercase is reserved for short meta/pill strings — the date range under the Week title ("MAR 30 – APR 5"), the "TODAY" / "SKIPPED" status tags, and the weekday abbreviation in the date column ("MON"). Those use `data` with `.tracking(0.5)`. Longer content strings stay in natural case.

**SF Pro (`body`, `meta`):**
- Primary UI text and descriptions (body)
- All small labels, badges, counts, timestamps (meta)
- Pill labels ("TODAY", "SKIPPED") — uppercase, semibold, `.tracking(0.5)`.

### Rules

- Never use raw `.font(.headline)`, `.font(.body)`, `.font(.subheadline)`, or `.font(.caption)`. Always use `TrailFont.*` tokens.
- `.font(.system(size: N))` is allowed ONLY on SF Symbol `Image` views for icon sizing. Never on `Text`.
- `.font(.title2)` and `.font(.title3)` are allowed ONLY on SF Symbol `Image` views.
- No inline `Font.custom()` or `Font.system()` calls outside BrandKit.swift. All font access goes through `TrailFont.*`.
- Use `.strikethrough()` for completed/skipped items, not opacity reduction.
- Navigation bar titles are hidden on all tab views. Each tab renders its own header using `TrailFont.tabHeading` inside a solid Trail Green band.
- Fraunces is used for `tabHeading` and `coach` **only**. Not for in-card section labels, stats, or generic body copy.

### Website

| Role        | Font              | Size     | Weight    | Usage                                    |
|-------------|-------------------|----------|-----------|------------------------------------------|
| Display     | Fraunces          | 3.2rem   | 400       | Hero headings, section titles            |
| Body        | System (SF Pro)   | 1rem     | 400       | Paragraphs, feature descriptions         |
| UI/Labels   | System (SF Pro)   | 0.85rem  | 500       | Buttons, nav links, form labels          |
| Data        | Geist Mono        | 0.9rem   | 400       | Stats, metrics, technical details        |
| Coach Quote | System (SF Pro)   | 1.05rem  | 400       | Pull-quotes, testimonials, coach voice   |

**Loading:** Google Fonts: `Fraunces:ital,opsz,wght@0,9..144,400;0,9..144,500;0,9..144,600;1,9..144,300;1,9..144,400` + `Geist+Mono:wght@400;500`. Body text uses system font stack (`-apple-system, BlinkMacSystemFont, system-ui, sans-serif`).

### Modular Type Scale (website)

| Token | Size   | Line Height | Usage                    |
|-------|--------|-------------|--------------------------|
| xs    | 0.75rem | 1.4        | Fine print, timestamps   |
| sm    | 0.85rem | 1.5        | Labels, captions         |
| base  | 1rem    | 1.7        | Body text                |
| md    | 1.15rem | 1.6        | Lead paragraphs          |
| lg    | 1.4rem  | 1.4        | Section subheads         |
| xl    | 2rem    | 1.3        | Section titles           |
| 2xl   | 2.6rem  | 1.2        | Page titles              |
| 3xl   | 3.2rem  | 1.15       | Hero headlines           |

## Color

- **Approach:** Restrained. Trail Green for action. Warm stone tones for everything else. Color is rare and meaningful.

### Trail Green (Brand Accent)

| Mode  | Hex       | RGB              | Usage                                    |
|-------|-----------|------------------|------------------------------------------|
| Light | `#008D55` | rgb(0, 141, 85)  | Buttons, links, active states, tab tint  |
| Dark  | `#00B068` | rgb(0, 176, 104) | Same roles, lifted for dark backgrounds  |

**Opacity variants:**
- `trailGreenLight` (0.12) — background tint for active/selected states
- `trailGreenSubtle` (0.06) — card backgrounds for accent-themed sections

### Neutrals (Warm Stone)

| Token           | Light Mode | Dark Mode  | Usage                           |
|-----------------|------------|------------|---------------------------------|
| `--bg`          | `#FAFAF7`  | `#1C1C1A`  | Page/screen background          |
| `--surface`     | `#FFFFFF`  | `#2A2A27`  | Cards, elevated surfaces        |
| `--surface-warm`| `#F5F2ED`  | `#333330`  | Subtle section backgrounds      |
| `--border`      | `#E8E4DF`  | `#3D3D38`  | Dividers, card borders          |
| `--text-primary`| `#1C1C1A`  | `#F0EDE8`  | Headings, primary content       |
| `--text-secondary`| `#5A5750` | `#B8B2A8` | Supporting text, descriptions   |
| `--text-tertiary`| `#8A8478` | `#8A8478`  | Metadata, timestamps            |
| `--text-quaternary`| `#B8B2A8`| `#5A5750` | Dividers, chevrons, faint UI    |

### Workout Type Colors

Each workout type has a dedicated color for instant recognition.

| Type        | Color             | Icon                      |
|-------------|-------------------|---------------------------|
| Easy        | `.green`          | `figure.walk`             |
| Tempo       | `.orange`         | `gauge.with.needle.fill`  |
| Intervals   | `.red`            | `bolt.fill`               |
| Long Run    | `.blue`           | `figure.run`              |
| Recovery    | `.mint`           | `leaf.fill`               |
| Rest        | `.gray`           | `bed.double.fill`         |
| Race        | `.purple`         | `flag.checkered`          |
| Cross Train | `.yellow`         | `figure.mixed.cardio`     |
| Strength    | Trail Green       | `dumbbell.fill`           |

### Semantic Colors

| Token    | Light    | Dark     | Usage                           |
|----------|----------|----------|---------------------------------|
| Success  | `#2D8B4E`| `#3BA864`| Completed, checkmarks           |
| Warning  | `#C47A20`| `#D4922E`| Oura low readiness, deload      |
| Error    | `#C43B3B`| `#D45454`| Disconnected, skipped           |
| Info     | `#3B7BC4`| `#5A96D8`| Week progress, tips             |

### Status Colors

| State     | Color     | Usage                           |
|-----------|-----------|----------------------------------|
| Completed | Success   | Checkmarks, "Done" labels        |
| Skipped   | Error     | Skipped badges, skip counts      |
| Modified  | Warning   | Overridden sessions, deload      |
| Heat      | Warning   | Heat/sauna sessions              |
| Stretch   | Trail Green | Stretch labels and counts      |

### Dark Mode Strategy
- Backgrounds shift to warm charcoal (`#1C1C1A`), not pure black
- Surfaces use `#2A2A27` for cards (warm, not cold)
- Reduce accent saturation ~10% and lift lightness for Trail Green
- Text inverts to warm off-white (`#F0EDE8`), not pure white
- Semantic colors lift 15% to maintain contrast on dark surfaces

## Spacing

- **Base unit:** 8px (iOS: 8pt)
- **Density:** Comfortable

### Scale

| Token | Value | iOS pt | Usage                            |
|-------|-------|--------|----------------------------------|
| 2xs   | 2px   | 2pt    | Text vertical spacing, badge padding (vertical) |
| xs    | 4px   | 4pt    | Badge horizontal padding         |
| sm    | 8px   | 8pt    | Tight internal padding           |
| md    | 16px  | 16pt   | Screen edge padding, section gaps|
| lg    | 24px  | 24pt   | Between major sections           |
| xl    | 32px  | 32pt   | Page-level vertical rhythm       |
| 2xl   | 48px  | 48pt   | Hero padding, major breaks       |
| 3xl   | 64px  | 64pt   | Website hero top/bottom          |

### iOS-Specific Spacing

| Context               | Value  | Token |
|-----------------------|--------|-------|
| Screen edge           | 16pt   | md    |
| Card internal         | 12-16pt| sm-md |
| Between cards         | 12pt   | sm+xs |
| Between sections      | 16-20pt| md    |
| Text vertical spacing | 2-4pt  | 2xs-xs|
| Badge internal (h)    | 4-6pt  | xs    |
| Badge internal (v)    | 2pt    | 2xs   |

## Layout

- **Approach:** Hybrid. Grid-disciplined for iOS app. Creative-editorial for website.
- **iOS grid:** Single column, full width with 16pt margins. LazyVStack with 12pt spacing.
- **Website grid:** Max width 800px, single column editorial. Asymmetric hero with generous whitespace.
- **Border radius:**

| Element             | iOS    | Web         | Token    |
|---------------------|--------|-------------|----------|
| Small containers    | 6pt    | 4px         | sm       |
| Icon badges (card)  | 8pt    | 8px         | md       |
| Icon badges (Week)  | 15pt   | —           | -        |
| Day cards           | 12pt   | 12px        | lg       |
| Week tab rows       | 18pt   | —           | -        |
| Phone frame         | 32pt   | 32px        | -        |
| Inline badges/pills | Capsule| 9999px      | full     |
| Progress bars       | 3pt    | 3px         | -        |

## Motion

- **Approach:** Minimal-functional. Only transitions that aid comprehension.
- **Easing:** enter(ease-out) exit(ease-in) move(ease-in-out)
- **Duration:** micro(50-100ms) short(150-250ms) medium(250-400ms) long(400-700ms)
- **Rules:** No bouncy animations. No spring effects on data. Sheets use system defaults. Completion toggles get a subtle scale pulse (0.95 → 1.0, 150ms).

## Components

### Cards (iOS)

Standard card:
```swift
.padding()
.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
```

Colored card (status sections):
```swift
.padding()
.background(Color.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
```

Use `.regularMaterial` for data cards. Use `.bar` for sticky headers. Use color `.opacity(0.06)` for tinted backgrounds. Use `.opacity(0.15)` for tinted borders via `.strokeBorder()`.

### Completion Indicators

Tappable circle (preferred):
```swift
Button { toggleCompletion() } label: {
    Image(systemName: complete ? "checkmark.circle.fill" : "circle")
        .font(.title3)
        .foregroundStyle(complete ? .green : .secondary.opacity(0.4))
}
```

Non-interactive checkmark (read-only):
```swift
Image(systemName: "checkmark.circle.fill")
    .foregroundStyle(.green)
```

### Buttons

| Style                   | Usage                          |
|-------------------------|--------------------------------|
| `.borderedProminent`    | Primary CTA (one per screen)   |
| `.bordered`             | Secondary actions, "Log" buttons |
| `.plain`                | Inline tappable labels         |

Always set `.tint(Color.trailGreen)` on bordered buttons unless the action has a semantic color (destructive = `.red`).

Control sizes: `.controlSize(.small)` for inline actions. Never `.controlSize(.mini)`.

### Sheets

- Detail/logging views: `.presentationDetents([.large])`
- Quick input forms: `.presentationDetents([.medium])`
- Always include a "Done" button in `.confirmationAction` toolbar position.

### Badges

```swift
Text("BW")
    .font(.caption.bold())
    .foregroundStyle(.secondary)
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(.quaternary, in: Capsule())
```

### Workout Icon Badge

```swift
Image(systemName: workoutType.iconName)
    .font(.body)
    .foregroundStyle(workoutType.swiftUIColor)
    .frame(width: 32, height: 32)
    .background(workoutType.swiftUIColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
```

### Coach Note (iOS)

Fraunces is reserved for the **label** only. Body prose reads in SF Pro for legibility; the container's hairline card border does the structural work — no Trail Green left border on the prose.

```swift
VStack(alignment: .leading, spacing: 8) {
    Text("Coach notes")
        .font(TrailFont.coach)          // Fraunces 16pt — the label
        .foregroundStyle(.secondary)
    Text(coachNote)
        .font(TrailFont.body)           // SF Pro 17pt — the prose
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
}
.padding(14)
.background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
.overlay(
    RoundedRectangle(cornerRadius: 18)
        .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
)
```

### Coach Note (Website)

```css
.coach-note {
    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif;
    font-size: 1.05rem;
    line-height: 1.7;
    color: var(--text-secondary);
    padding-left: 20px;
    border-left: 3px solid var(--accent);
}
```

## Tab Layout Pattern

Every tab follows the same structure. Week is the golden reference — it leads on the Bold Day hierarchy refresh (2026-04-19).

### Anatomy of a Tab

```
┌─────────────────────────────┐
│ ▓▓ TAB TITLE    [actions] ▓▓│  ← Trail Green band: Fraunces 28pt "tabHeading"
│ ▓▓ SUBTITLE / META       ▓▓│    Meta line below in Geist Mono UPPERCASE (data token)
├─────────────────────────────┤
│                             │
│   Scrollable content        │  ← ScrollView, 12pt padding, 10pt row gap
│   ┌───────────────────┐     │
│   │ Row (18pt radius) │     │
│   └───────────────────┘     │
│   ┌───────────────────┐     │
│   │ Row               │     │
│   └───────────────────┘     │
│                             │
└─────────────────────────────┘
```

### Rules

- **Navigation bar hidden** on all tabs. Each tab renders its own header.
- **Header band** is solid Trail Green, white text, `.padding(.horizontal, 16)`, `.padding(.vertical, 12)`. Title uses `TrailFont.tabHeading` (Fraunces 28pt, Medium). The band extends **through the top safe area** (`.background(Color.trailGreen.ignoresSafeArea(edges: .top))`) so the pigment covers the status-bar strip — no white gap above the banner. Status-bar content (time, battery) renders white against green.
- **Title inset:** on tabs whose body has rows with inset padding (e.g. Week), the header title and meta line are left-indented to align with the first content column below. The Week tab uses an 8pt inset (row-container 12 + row pad 12 − header pad 16 = 8).
- **Meta line** directly under the title uses `TrailFont.data` (Geist Mono 13pt) UPPERCASE with `.tracking(0.5)`.
- **Header stays pinned.** It is outside the ScrollView so it does not scroll away.
- **No summary bar** below the header on the Week tab — removed in the Bold Day refresh; summary info lives inside the content cards or is surfaced through the Progress tab instead.
- **Scroll content** uses `LazyVStack(spacing: 10)` or `VStack(spacing: 12)` with `.padding(.horizontal, 12)` and `.padding(.vertical, 12)`.
- **Rows** are `cornerRadius: 18`, `Color(.systemBackground)` fill with a `Color(.separator).opacity(0.3)` hairline border.
- **Section labels** inside content use `TrailFont.title` (Geist Mono 20pt) — except **workout-type labels in Week rows** (e.g. "Easy", "Tempo", "Long Run") and **phase labels in Progress** (e.g. "Base", "Peak") which use **SF Pro 18pt** (`.font(.system(size: 18))`) for friendlier, less-data-forward voice on the item label itself. Uppercase is reserved for status pills and meta strings.
- **All stats** use `TrailFont.data` (Geist Mono 13pt).
- **Trailing edge** on Week rows is one of: green "TODAY" pill (today), checkmark + actual distance (completed), red "SKIPPED" label (skipped), or empty (upcoming). No trailing chevron — the whole row is tappable and opens the detail sheet; an empty trailing slot lets the week's data breathe.
- **Top alignment** (`HStack(alignment: .top)`) on multi-line rows so icons, dates, and titles align to the first line.

### Per-Tab Implementation

| Tab       | Header                                | Summary bar | Content style                                    |
|-----------|---------------------------------------|-------------|--------------------------------------------------|
| Week      | "Week N" (Fraunces 28) + UPPERCASE date range meta, chevrons + calendar icon on right | — (removed) | `TabView(.page(indexDisplayMode: .never))` paging per week; inside each page, `LazyVStack(spacing: 10)` of Bold-Day session rows. Horizontal swipe changes weeks. |
| Progress  | "Progress" (Fraunces 28) + UPPERCASE training-plan name meta | — | Focused-week card on top (swipe animates the content) + `TabView(.page(indexDisplayMode: .always))` paging three chart cards (Miles / Vert / Time) + race card pinned below. |
| Strength  | "Strength & More" (Fraunces 28) + segmented picker | — | `VStack(spacing: 12)`, day cards                 |
| Settings  | "Settings" (Fraunces 28)              | — | Grouped `List` with sections                     |

### Row Pattern — Week tab (Bold Day)

The Week tab establishes the refreshed row anatomy:

```
┌────────────────────────────────────────────────────────┐
│ ┃ MON  [icon 43×43]   Long Run             [>]  16–20 │
│ ┃ 30   r15 0.15 tint  8–10 pace                   mi  │
└────────────────────────────────────────────────────────┘
   ↑    ↑                ↑
   │    │                title title-case, TrailFont.title — no uppercase, no tracking
   │    badge: 43×43, radius 15, hue.opacity(0.15) fill, icon 20pt in hue
   date column: 42pt wide, TrailFont.data (MON) stacked over TrailFont.title (30), Geist Mono throughout, .secondary on every row
```

- Row: `minHeight 67pt`, `cornerRadius 18pt`, internal padding 12pt × 12pt.
- Row gap: `LazyVStack(spacing: 10)`.
- Date column → badge gap: 9pt. Badge → title gap: 14pt.
- **Date column color:** grey on every row — weekday in `TrailFont.data` at 0.75 opacity, number in `TrailFont.title` at medium weight, both `.secondary`. Do NOT tint today's date green; today's identity lives entirely in the accent bar, tint, and "TODAY" pill so the date text can stay quiet.
- **Today row:** 0.07 Trail Green tint background + 0.33 Trail Green stroke + 4pt-wide Trail Green accent bar flush against the left edge (inside the 18pt radius). Trailing slot shows a Trail Green "TODAY" capsule pill (SF Pro 12pt semibold, uppercase, `.tracking(0.5)`, white on green, 10×4 padding).
- **Completed row:** trailing slot shows a success checkmark stacked over actual distance (e.g. "7.1 mi") in `TrailFont.data`, right-aligned.
- **Skipped row:** title gets `.strikethrough()`. Trailing slot shows "SKIPPED" label in error color (SF Pro 12pt semibold, uppercase, `.tracking(0.5)`).
- **Rest day:** mileage line reads "Full recovery" in `TrailFont.data`.

### Row Pattern — Other tabs (Bold Day alignment)

Strength, Stretch, and Heat day cards now follow the same Bold Day chrome as Week rows:

- `HStack(alignment: .top, spacing: 12)`
- Icon badge **43×43, r15, 0.15-opacity tint** — identical to Week row workout badges. Icon glyph rendered at `.system(size: 20)` inside.
- Text in a `VStack(alignment: .leading, spacing: 2)`.
- Day cards use **`cornerRadius: 18`**, today-highlighted with `Color.trailGreenSubtle` fill + `Color.trailGreen.opacity(0.33)` stroke (mirrors the Week today row exactly).

### Icon Badge System

All icon badges across the app use **`cornerRadius: 15`** regardless of size — one radius across every tile slot to unify the visual family. Sizes:
- **43×43** — primary row badges on Week / Strength / Stretch / Heat day cards, and the day-sheet summary card.
- **32×32** — in-row activity badges (e.g., each entry in the day sheet's Activities list).
- **24×24** — section-header chips inside cards (e.g., "LOGGED ACTIVITY" on Strava, "HEAT" / "STRENGTH" / "RECOVERY" labels). At this size, r15 reads nearly circular — intentional; keeps one system rather than mixing r6/r8/r15.

### Content Cards

- Sections within scroll content do NOT wrap in `.regularMaterial` cards. Use flat layout.
- Individual tappable rows use `RoundedRectangle(cornerRadius: 12)` with tint fill for current day + subtle stroke border for non-highlighted rows.
- No `.regularMaterial` backgrounds on content cards. Use `Color(.systemBackground)` fill + `Color(.separator).opacity(0.3)` stroke.
- Section labels use `TrailFont.title` (Fraunces).
- Stat callouts left-align, never center.
- Scroll content spacing: `VStack(spacing: 12)` or `LazyVStack(spacing: 12)` across all tabs.
- Every list item type (workout, exercise, stretch, heat) gets its own icon badge (32x32, rounded 8, 0.15 opacity tint).
- Inline data (prescriptions, durations, distances) always in `TrailFont.data`.

## Progress Charts

Three charts render inside the Progress tab's paginated `TabView` (page dots always shown). All three share the same card chrome: `Color(.systemBackground)` fill, 18pt corner radius, 1pt `Color(.separator).opacity(0.3)` border, 14pt internal padding. Chart height fixed at 142pt; TabView total height 260pt so all three pages have identical dimensions.

### Card header (shared)

| Slot | Format | Font |
|------|--------|------|
| Left label | UPPERCASE (e.g. "TOTAL MILES") | `TrailFont.data` `.tracking(0.5)` `.secondary` |
| Left value | Integer (miles, vert) or integer hours (time) | `TrailFont.data` `.secondary` |
| Right label | `"WEEKLY AVG"` UPPERCASE | `TrailFont.data` `.tracking(0.5)` `.secondary` |
| Right value | One-decimal miles / rounded ft / one-decimal hours | `TrailFont.data` `.secondary` |

### Bar anatomy

| Chart | Green bar | Orange stack | Ghost/future | Accent |
|-------|-----------|--------------|--------------|--------|
| Miles | `actualMi` | — (cross-train moved out) | Current-week remainder + all future weeks in `Color(.systemGray5)` | **All completed and current weeks render at full Trail Green** — no opacity taper for past bars (completed work is work, not faded history). Future weeks stay grey. |
| Vert  | `elevationGainFt` | — | synthesized `plannedMi × 55 ft/mi` for current/future | Custom purple `Color(0.54, 0.42, 0.82)` current / 0.76, 0.71, 0.90 completed |
| Time  | `runHours` | `crossTrainHours` stacked on top | `plannedHours = plannedMi / 6 mph` for current/future | Trail Green (runs) + orange (cross-train); `.orange.opacity(0.5)` for completed past weeks |

### Rules

- **Chart height** 180pt (bumped from 142pt for legibility); TabView container 296pt (280pt chart + 16pt dot strip).
- **Page dots** always shown (`.tabViewStyle(.page(indexDisplayMode: .always))`); active dot tinted Trail Green, inactive `UIColor.secondaryLabel` at 30% alpha, via `UIPageControl.appearance()` in the view's `init`. The appearance setter is global — keep in mind if another surface ever enables page dots.
- Bar width 12pt; spacing auto-computed; y-axis 20pt (miles/time) or 28pt (vert, wider for "k" labels).
- Y-axis labels at 9pt monospace, `.tertiary` — topmost tick hidden so the number doesn't clip the card edge.
- Tap any bar → focuses that week. Tap animates with `withAnimation(.easeOut(0.22))`.
- Focused week's bar label renders in the chart accent color and semibold; current-week label is always accent-colored too.
- Cross-training lives on the **Time** chart only — not stacked on Miles, per 2026-04-19 decision: miles and hours are different units and shouldn't be summed visually.

## Banners (Week tab)

Stacked above the session list inside `weekContent`, two alert banners share a single chrome spec. Both sit below the green banner and above the horizontal `TabView` of week rows, each with 12pt horizontal + 12pt top padding.

### Shared chrome

- `RoundedRectangle(cornerRadius: 10)` container (banner tier — separate from 18pt content cards).
- 10pt internal padding.
- 1pt accent stroke at `.opacity(0.3)`; fill at `.opacity(0.08)`.
- Shadow: `Color.black.opacity(0.08)`, radius 3, y 1.
- Leading SF Symbol rendered at default body size (no `.title2` or other size modifier) so icons across stacked banners match.

### Readiness banner

- Trigger: Oura today readiness `.low` **and** today's session is not easy/rest/recovery **and** not skipped.
- Accent: `.orange` (stroke + title icon).
- Content: warning-triangle icon, "Low readiness (score)" headline in `TrailFont.body` semibold, swap prompt in `TrailFont.body` secondary, orange "Swap to [day]" bordered button.

### Tuesday podcast banner

- Trigger: `Calendar.current.component(.weekday, from: Date()) == 3` (Tuesday — when SWAP drops a new episode).
- Accent: `Color.trailGreen` (stroke + leading icon).
- Content: `headphones` SF Symbol, "Happy Tuesday! It's Tuesday!" in `TrailFont.body` primary, "Listen to the latest SWAP podcast" in `TrailFont.meta` secondary.
- Wrapped in `Link` to `https://open.spotify.com/show/3AaJYZngimocFf8aztKTcO`.
- On a low-readiness Tuesday both banners stack; readiness wins eye-first (actionable).

## Pull-to-refresh

`.refreshable { await sync() }` on:
- Each week page's inner `ScrollView` in `WeekView` (so the gesture works on every week tab, not just the current one).
- The main `ScrollView` in `ProgressDashboardView`.

`sync()` logic (same on both surfaces):
1. `guard let userId = auth.currentUserId else { return }`
2. If `strava.isConnected`: `await strava.loadActivities(userId:)` then `strava.autoMatchActivities(sessions:)`.
3. If `oura.isConnected`: `await oura.loadDailyData(userId:)`.

Spinner is tinted `Color.trailGreen` via `.tint()` on the `ScrollView`. Native iOS chrome — no custom spinner view.

## Session Detail Sheet (Day sheet)

The per-session detail sheet presents as a custom-detent bottom sheet that leaves the underlying tab's green banner fully visible with a 12pt gap. The Week tab's banner **is** the sheet's visual anchor — the sheet itself does not carry its own banner.

### Detent

- Single custom detent: `BannerGapDetent: CustomPresentationDetent` returning `context.maxDetentValue - 87` (banner ≈75pt + 12pt gap).
- No `.medium` secondary detent.
- Drag indicator **visible** (iOS default) so the user sees the sheet is draggable, but the banner above is the contextual title.

### Chrome

- No in-sheet banner, no in-sheet date row. First row of scroll content is a right-aligned close button only: `xmark` glyph on a **30pt Circle** with `Color(.secondarySystemBackground)` fill. The Week tab's green banner (visible above the sheet thanks to `BannerGapDetent`) is the contextual anchor.
- Edit mode replaces the close button with a left-aligned "Cancel" text button and a right-aligned Trail Green "Save" capsule.

### Content cards

Stacked 18pt-radius / `Color(.systemBackground)` / `Color(.separator).opacity(0.3)` 1pt-border cards, 12pt gap between:

1. **Summary card** — `workoutHeader` (43×43 r15 icon badge @ workout hue 0.15 opacity; workout name in SF Pro 18pt; uppercase "WEEK N · DAY d" mono meta) + a **range display** row using `session.displayTargetRange` ("8–14 mi" etc.) in `TrailFont.data`. Same `displayTargetRange` used by the Week tab — one source of truth. Skipped sessions render the workout name with `.strikethrough()` + a red "SKIPPED" capsule pill. Completed days render a green checkmark + summed miles across all day's run activities.
2. **Coach notes card** — label "Coach notes" in `TrailFont.coach` (Fraunces Medium 16pt, `.secondary`), body prose in `TrailFont.body` (SF Pro 17pt, `.primary`). No left border — the card border alone carries the container.
3. **Strength / Heat cards** — 14pt padding, label row is icon-in-tinted-badge (24×24 r6) + UPPERCASE mono label. Item rows use tappable `checkmark.circle.fill` / `circle` on the left (Trail Green / secondary 0.4) + SF body text. Completed items strike through.
4. **Recovery (Oura) card** — UPPERCASE "RECOVERY" label + Oura logo on the right of the header row; four stat chips (Rdy / Slp / HRV / RHR) below, each colored by metric. Same card chrome as everything else.
5. **Strava (plan vs actual) card** — checkmark + activity name header (SF body), 3-column grid (Distance / Pace / Duration) with delta %, optional HR + elevation row with Powered by Strava lockup tucked inline. Tap = open in Strava app/web.
6. **Activities list card** (shown when > 1 run on the same day) — UPPERCASE "ACTIVITIES" label + summed miles, then one row per run: 32×32 r8 run badge, activity name (SF body), `distance · duration · pace` in mono, start time on the right.
7. **Actions card** — Skip / Swap / Edit buttons.

### Edit form

Edit header row at top of scroll content: Cancel (plain text button) on the left, Save (Trail Green capsule) on the right. Fields (type picker, distance, pace, coach notes TextEditor) stack below in the same scroll.

## Multi-Activity Day

For doubles days where multiple Strava run activities land on the same calendar day:
- **Week row trailing slot:** sums `strava.runActivities(on: session.scheduledDate)` miles; checkmark + total.
- **Day sheet `workoutHeader`:** same sum next to the checkmark.
- **Day sheet content:** if exactly one run, flow through the existing `planVsActualSection` card (with its full plan-vs-actual grid). If more than one, render an **Activities list card** with per-activity rows.
- Backed by `StravaService.runActivities(on: Date)` — filters `activities(on:)` by `isRun`, using each activity's own `localCalendarDay` for timezone safety.

## Calendar (PlanCalendarView)

Month grid view reached from the Week tab's calendar-icon button. Cells are intentionally minimal after the 2026-04-19 cleanup:

- Each cell = a single workout-type SF Symbol at 18pt, rendered in `workoutType.swiftUIColor`, centered in a 40pt-tall cell.
- **No day number.** **No heatmap fill.** **No corner glyphs** (done checkmark, strength dumbbell, edit pencil, heat flame).
- **Today marker:** 1pt Trail Green stroke on the cell's 8pt-radius outline — color is the only today signal.
- **Skipped:** 0.5 opacity (only state-change kept).
- Cells remain tappable → opens the Session Detail Sheet.
- Rationale: at this zoom-out the week-by-week rhythm is what reads, not per-day detail. The sheet carries the per-day data.

## Settings Tab

The Settings tab uses a **Bold Day card layout** instead of iOS `List` chrome:

- Trail Green header banner (extends through top safe area) with "Settings" in `TrailFont.tabHeading`.
- `ScrollView` → `VStack(spacing: 18)` of grouped sections.
- Each section is an 18pt-radius `Color(.systemBackground)` card with `Color(.separator).opacity(0.3)` 1pt border. **Section label sits outside the card**, above it: UPPERCASE in `TrailFont.data .tracking(0.5) .secondary`, inset 4pt.
- Rows inside the card use consistent `.padding(.horizontal, 14).padding(.vertical, 12)` and are separated by `Divider().padding(.leading, 14)` for a clean list-within-card look.
- Info rows: label in `TrailFont.body .secondary` on the left, value in `TrailFont.data .primary` on the right.
- Button rows: `Button` wrapping an HStack (16pt leading icon in the row color, 24pt icon slot, `TrailFont.body` label). Destructive variants render in `.red`.
- Grace-period banner (when present) is a standalone Yellow-bordered 18pt-radius card at the top of the scroll content.

## Navigation Patterns

### Tab Structure

| Tab       | Icon             | View                    |
|-----------|------------------|-------------------------|
| Today     | `sun.max.fill`   | TodayView               |
| Week      | `calendar`       | WeekView                |
| Progress  | `chart.bar.fill` | ProgressDashboardView   |
| Strength  | `dumbbell.fill`  | StrengthTemplateView    |
| Settings  | `gearshape`      | SettingsView            |

### Drill-down

- Tap a card or row to open a `.sheet` with full detail.
- Tap a circle to toggle completion inline (no sheet needed).
- Long-press for edit/destructive actions (context menu).
- Tappability is communicated by the row's card shape and tint, not a trailing chevron. The Week tab uses no trailing chevrons on upcoming rows; Strength/Stretch/Heat day cards keep their existing affordances.

### Progressive Disclosure

Show summary at the group level, full detail on tap-through:
- **Week tab**: Session type + distance + completion status. Tap for detail sheet.
- **Strength tab**: Day name + icon badge + exercise name + inline prescription (3x10 @ 45 lbs). Tap day for logging.
- **Today view**: Current session with coach notes expanded. Ancillary sections compact.

## Interaction States

| State    | Visual Treatment                                |
|----------|-------------------------------------------------|
| Default  | Standard foreground colors                      |
| Pressed  | System highlight (SwiftUI handles for Button)   |
| Complete | Success color checkmark, `.strikethrough` on text |
| Disabled | `.opacity(0.4)`, non-interactive                |
| Error    | Alert with "OK" dismiss                         |

### Empty States

Every list/section that can be empty needs:
1. An SF Symbol icon at `.system(size: 48)` in Trail Green or secondary color
2. A title in `TrailFont.title` + `.secondary`
3. A description in `TrailFont.detail` + `.tertiary`, centered, max width 280pt
4. A primary action button (`.borderedProminent`) if the user can fix the empty state

## Accessibility

- Minimum tap target: 44x44pt. Buttons below this size must use `.contentShape(Rectangle())` to expand the hit area.
- Use system Dynamic Type. All custom fonts use `relativeTo:` for scaling.
- All images should have accessibility labels or be marked `.accessibilityHidden(true)` if decorative.
- Color is never the sole indicator of state. Pair color with icons or text.

## Key Files

| File | Purpose |
|------|---------|
| `Sources/Design/BrandKit.swift` | Color extensions, Trail Green, brand constants |
| `Sources/Views/Shared/SessionComponents.swift` | Reusable Oura, Strava, comparison cells |
| `Sources/Models/WorkoutType.swift` | Workout colors, icons, display names |
| `Resources/Assets.xcassets/AccentColor.colorset` | Accent color asset (light + dark) |
| `docs/index.html` | Marketing website |

## Decisions Log

| Date       | Decision                          | Rationale                                                |
|------------|-----------------------------------|----------------------------------------------------------|
| 2026-04-04 | Design system refresh             | Replace generic SwiftUI defaults with intentional warm design |
| 2026-04-04 | Fraunces for titles only          | Warm serif differentiates from data-forward competitors  |
| 2026-04-04 | Warm stone neutrals               | Shifts palette from clinical to personal                 |
| 2026-04-04 | Editorial website layout          | Coaching blog feel, not SaaS landing page                |
| 2026-04-04 | Renamed SWAP Green to Trail Green | Brand-independent color name for broader positioning     |
| 2026-04-04 | Source Sans 3 for website body    | Slightly warmer than system fonts, pairs well with Fraunces |
| 2026-04-04 | Source Sans 3 for all body/UI     | Consistent brand font across iOS and web                 |
| 2026-04-04 | Coach notes in Source Sans 3      | Readability over decoration, Fraunces italic too hard to read |
| 2026-04-09 | SF Pro (system) replaces Source Sans 3 | Native iOS legibility, zero bundle cost, excellent Dynamic Type support. Fraunces + Geist Mono carry the brand personality. |
| 2026-04-04 | Geist Mono for tab headers        | Tab titles, activity names, and stats all in monospace for data-forward feel |
| 2026-04-04 | Hidden navigation bars            | System SF navigation titles removed, replaced with custom TrailFont headers |
| 2026-04-04 | Fraunces for section labels only  | Serif reserved for "Coach notes", "Strength", "Heat" labels, not body or data |
| 2026-04-19 | Bold Day Week tab refresh         | Added `tabHeading` token (Fraunces 28pt Medium) for tab display titles; removed the Week summary bar; new row anatomy at 18pt radius with 43×43 r15 badges, "TODAY" pill, and a Trail Green accent bar on today's row. Tightens visual hierarchy and lets the day itself carry the weight. |
| 2026-04-19 | Week row polish: quiet content, structural signals | Dropped forced UPPERCASE + `.tracking(0.3)` on workout titles (shouted at 20pt Geist Mono); made the date column `.secondary` on every row including today. Today's identity is now fully carried by the accent bar + tint + "TODAY" pill, so the content (dates, titles) stays calm. |
| 2026-04-19 | Removed "Current Week" meta + trailing chevrons on Week tab | "Current Week" was redundant alongside the implicit "you landed on this tab" context. Trailing chevrons on upcoming rows added noise without information — the row's card shape already signals tappability. Empty trailing slots let the date + mileage breathe. |
| 2026-04-19 | Bold Day Progress refresh         | Rewrote Progress tab around focused-week card + stacked-bar mileage chart + elevation chart + race card. Swipe/tap navigates weeks. Header subtitle = training plan name (no "Week N / N" pill). |
| 2026-04-19 | 18pt SF Pro for workout + phase labels | Dropped `TrailFont.title` (Geist Mono 20) on workout-type names and Progress phase labels — monospace at 20pt read as shouting. SF Pro 18pt is friendlier at the item-label slot while data/numbers keep mono. |
| 2026-04-19 | TOTAL TIME chart + paginated Progress charts | Three charts — Miles, Vert, Time — now live in a horizontal `TabView` with page dots; default page = Miles. Unifies chart chrome and cuts vertical scroll. |
| 2026-04-19 | Cross-train moved from Miles to Time chart | Orange cross-train stack on the Miles chart confused units (hours bolted onto miles via a pace hack). Cross-train belongs on the Time chart where hours stack naturally on run hours. Miles chart is now single-color. |
| 2026-04-19 | Week tab horizontal swipe via `TabView` paging | Chevrons stay, but horizontal swipe on the session list now moves between weeks with the native page animation. Each week is a tagged `.page` in the TabView. |
| 2026-04-19 | Calendar icon-only cells          | Stripped day number, heatmap fills, four corner glyphs from Calendar cells. Only the workout icon + its color + a Trail Green ring for today remain. The sheet carries the per-day detail — the grid is a rhythm view. |
| 2026-04-19 | Day sheet banner-aware custom detent + Bold Day chrome | Replaced `.large`/`.medium` with `BannerGapDetent` that pops the sheet just below the tab's green banner (+12pt gap). Removed internal `NavigationStack`; replaced with a Trail Green banner matching the main tabs (Fraunces date + mono meta). Coach notes switch to `TrailFont.coach` (Fraunces) with a Trail Green left border. |
| 2026-04-19 | Removed redundant day-sheet banner | Week tab's green banner is already visible above the sheet thanks to the custom detent — an in-sheet banner doubled up on the title. Dropped the banner; sheet now opens straight into the summary card with a small close button top-right. |
| 2026-04-19 | Coach note reversal: Fraunces label, SF Pro body, no left border | Fraunces Medium as body prose was too ornate for running notes that mix mileage prescriptions and pace callouts. Kept Fraunces on the literal "Coach notes" label so the serif voice still signals the section. The card border alone carries the container — removed the 2pt Trail Green left rule. |
| 2026-04-19 | Multi-activity day aggregation | Doubles days were hidden: the Week row and day sheet only showed the single matched Strava activity. Added `StravaService.runActivities(on:)`; Week row sums miles across all runs on that date; day sheet renders every activity as its own row when the count is > 1. |
| 2026-04-19 | Planned-distance range in day sheet | Day sheet was rendering a single `%.1f mi` value; Week rows show the coach's range (e.g. "8–14 mi"). Swapped the day sheet to `session.displayTargetRange` so the range reads identically everywhere. |
| 2026-04-19 | Unified 18pt-radius chrome for Oura / Strava / Heat / Strength cards | Pre-redesign these lived on tinted `.opacity(0.06-0.08)` fills with 8–12pt radii — stood out from the Week/Progress Bold Day cards. Migrated all four to `Color(.systemBackground)` / 18pt radius / 0.3-separator 1pt border. Accent colors now live in the section label's icon badge (24×24 r6) only, not the full fill. |
| 2026-04-20 | Tab banners extend through top safe area | White status-bar strip above every tab's green band looked unfinished. Wrapped the banner background with a second `Color.trailGreen.ignoresSafeArea(edges: .top)` layer so the pigment fills the status-bar zone. Content still respects the safe area — titles don't slide under the notch. |
| 2026-04-20 | Day sheet date row removed; close button back to Circle | The UPPERCASE date line added in last session's critique duplicated the summary card's meta line (`WK 11 D1 · 8–14 MI`). Dropped it. Close button reverts to a circle — r10 squircle was competing with the workout badge's r15 squircle family; a circle reads as lightweight chrome, not a peer. |
| 2026-04-20 | Miles chart: full Trail Green on every completed bar | Past-week bars were dimmed to 0.55 opacity; made completed work feel faded. Now every completed or current bar is full Trail Green. Future weeks stay `Color(.systemGray5)` so the forward-looking silhouette still reads. |
| 2026-04-20 | Progress chart height 142 → 180pt | Bars at 142pt made week-to-week deltas hard to read. Bumped chart frame to 180pt and TabView container to 280pt; tightened focused-card Divider padding + outer VStack spacing to preserve the no-scroll one-page layout. |
| 2026-04-20 | Unified icon badge system at r15 across the app | Previously mixed r6 (24×24 section chips), r8 (32×32 row badges), and r15 (43×43 workout badges). Collapsed to a single r15 radius at three sizes (43/32/24). The smaller tiles read nearly circular — intentional; one system beats three. |
| 2026-04-20 | Strength tab day cards migrated to Bold Day chrome | Was 12pt-radius with 32×32 r8 badges and `.opacity(0.08)` today tint. Now 18pt-radius with 43×43 r15 badges and `Color.trailGreenSubtle` today tint + `Color.trailGreen.opacity(0.33)` today stroke — identical to Week row spec. |
| 2026-04-20 | Settings tab: iOS List → Bold Day card layout | `List` chrome read as a different app surface. Converted to `ScrollView` of 18pt-radius cards with external UPPERCASE section labels; `Divider().padding(.leading, 14)` between rows for clean in-card separation. All existing actions and alerts preserved. |
| 2026-04-20 | Focused-week MILES number always Trail Green | The MILES stat on the focused-week card only turned green on the current week; past weeks rendered in `.primary`. CROSS-TRAIN (orange) and VERT (purple) were already fixed-color, so MILES was the odd one out. Locked to Trail Green whenever there's a value; falls back to `.secondary` when the value is "—" so empty weeks don't look green-for-nothing. |
| 2026-04-20 | Progress chart TabView shows page dots | Was `indexDisplayMode: .never` — nothing signaled the three charts were swipeable. Switched to `.always` and tinted the active dot Trail Green via `UIPageControl.appearance()` (with inactive at `UIColor.secondaryLabel` 0.3 alpha). TabView container bumped 280 → 296pt so the 16pt dot strip doesn't crop the chart. Global `UIPageControl.appearance()` side-effect is documented inline on the view's `init()`. |
| 2026-04-20 | Race card: X/Y replaced with done / swapped / skipped pills | Raw `X/Y` header over the progress bar showed completion but hid swap/skip counts entirely. Replaced the header counter with three inline pills below the progress bar — `checkmark.circle.fill` + count + "done" (Trail Green), `arrow.left.arrow.right.circle.fill` + "swapped" (orange), `minus.circle.fill` + "skipped" (secondary). Pills use SF Symbol 12pt + `TrailFont.data` for the count + `TrailFont.meta` for the label; no pill backdrop to keep the race card calm. Swap count is per event (A↔B = 1). |
| 2026-04-24 | Tuesday podcast banner restored | The `simplify` redesign deleted `TodayView.swift` and with it the Tuesday-only "Happy Tuesday! It's Tuesday!" podcast CTA. Restored into `WeekView` below the readiness banner with the same 10pt / 0.08 fill / 0.3 stroke banner chrome. Subtitle now `TrailFont.meta` `.secondary` (Geist Mono was wrong for prose); icon drops `.font(.title2)` to match readiness icon sizing when both banners stack. |
| 2026-04-24 | Pull-to-refresh restored on Week + Progress | The `simplify` redesign lost the `.refreshable` handler that used to live on `TodayView`. Wired to each week page's `ScrollView` in `WeekView` and to the Progress content `ScrollView`. Shared `sync()` runs `strava.loadActivities` + `autoMatchActivities` + `oura.loadDailyData` when connected. Spinner tinted Trail Green via `.tint()` on each scroll view. |
