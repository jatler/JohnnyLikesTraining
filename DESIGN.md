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

Three font families, strict separation of concerns. No system fonts for content.

### Font Families

| Font          | Role                  | Weights bundled          |
|---------------|-----------------------|--------------------------|
| Fraunces      | Section labels only   | Medium (500), SemiBold (600) |
| Source Sans 3 | All body/UI text      | Regular (400), SemiBold (600) |
| Geist Mono    | Stats, data, tab headers, activity titles | Regular (400), Medium (500) |

### iOS Token Reference (`TrailFont.*`)

| Token       | Font            | Size | Weight | Usage                                              |
|-------------|-----------------|------|--------|----------------------------------------------------|
| `title`     | Fraunces        | 20pt | 500    | Section labels: "Coach notes", "Strength", "Heat"  |
| `titleBold` | Fraunces        | 20pt | 600    | Emphasized section labels                          |
| `body`      | Source Sans 3   | 17pt | 400    | Exercise names, workout descriptions               |
| `bodyBold`  | Source Sans 3   | 17pt | 600    | Emphasized body text                               |
| `detail`    | Source Sans 3   | 15pt | 400    | Descriptions, pace text, week/day labels           |
| `detailBold`| Source Sans 3   | 15pt | 600    | Form labels, sub-section headers                   |
| `meta`      | Source Sans 3   | 12pt | 400    | Dates, counts, badges, attribution                 |
| `metaBold`  | Source Sans 3   | 12pt | 600    | Emphasized metadata, badge labels                  |
| `coach`     | Source Sans 3   | 15pt | 400    | Coach notes text (readable, not decorative)        |
| `data`      | Geist Mono      | 13pt | 400    | Inline stats: pace, distance, HR, elevation, Oura scores, prescriptions |
| `dataBold`  | Geist Mono      | 13pt | 500    | Emphasized stats: Strava titles, comparison values, deltas |
| `dataLarge` | Geist Mono      | 24pt | 500    | Tab headers ("Today", "Week 11"), activity type titles ("Long Run"), hero stat callouts |
| `dataHero`  | Geist Mono      | 28pt | 500    | App title on sign-in screen                        |

### When to Use Each Font

**Fraunces (serif, for labels only):**
- Section labels that name a category: "Coach notes", "Strength", "Stretches", "Heat", "Race Readiness"
- Day names in week view session rows (the date number)
- Plan names

**Source Sans 3 (sans-serif, for all readable text):**
- Exercise and workout names in lists
- Coach notes body text
- Descriptions, prescriptions (as prose)
- Form labels and input text
- All metadata: dates, badges, attribution, "Connected", "Last sync"

**Geist Mono (monospace, for data and headers):**
- Tab headers: "Today", "Week 11", "Progress", "Strength & More", "Settings"
- Activity type titles: "Long Run", "Tempo", "Easy", "Intervals"
- All numerical values: distances (8.2 mi), paces (7:42/mi), durations (1:03:27), HR (152 bpm), elevation (+485 ft), Oura scores (Readiness 82), reps/weight (3x10 @ 45 lbs)
- Strava activity titles: "Completed: Morning Run"
- Hero stat callouts: days to race, completion %, week counts
- Prescriptions as data: "3x10s", "45s hold", "25 min"

### Rules

- Never use raw `.font(.headline)`, `.font(.body)`, `.font(.subheadline)`, or `.font(.caption)`. Always use `TrailFont.*` tokens.
- `.font(.system(size: N))` is allowed ONLY on SF Symbol `Image` views for icon sizing. Never on `Text`.
- `.font(.title2)` and `.font(.title3)` are allowed ONLY on SF Symbol `Image` views.
- No inline `Font.custom()` calls outside BrandKit.swift. All font access goes through `TrailFont.*`.
- Use `.strikethrough()` for completed/skipped items, not opacity reduction.
- Navigation bar titles are hidden on all tab views. Each tab renders its own header using `TrailFont.dataLarge`.
- Fraunces is for labels only, never body text, never stats, never notes.
- Coach notes use Source Sans 3, not Fraunces. Readability over decoration.

### Website

| Role        | Font              | Size     | Weight    | Usage                                    |
|-------------|-------------------|----------|-----------|------------------------------------------|
| Display     | Fraunces          | 3.2rem   | 400       | Hero headings, section titles            |
| Body        | Source Sans 3     | 1rem     | 400       | Paragraphs, feature descriptions         |
| UI/Labels   | Source Sans 3     | 0.85rem  | 500       | Buttons, nav links, form labels          |
| Data        | Geist Mono        | 0.9rem   | 400       | Stats, metrics, technical details        |
| Coach Quote | Source Sans 3     | 1.05rem  | 400       | Pull-quotes, testimonials, coach voice   |

**Loading:** Google Fonts: `Fraunces:ital,opsz,wght@0,9..144,400;0,9..144,500;0,9..144,600;1,9..144,300;1,9..144,400` + `Source+Sans+3:wght@300;400;500;600` + `Geist+Mono:wght@400;500`

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

| Element          | iOS    | Web         | Token    |
|------------------|--------|-------------|----------|
| Small containers | 6pt    | 4px         | sm       |
| Icon backgrounds | 8-10pt | 8px         | md       |
| Cards            | 12pt   | 12px        | lg       |
| Phone frame      | 32pt   | 32px        | -        |
| Inline badges    | Capsule| 9999px      | full     |
| Progress bars    | 3pt    | 3px         | -        |

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

```swift
Text(coachNote)
    .font(TrailFont.coach)
    .foregroundStyle(.secondary)
    .padding(.leading, 12)
    .overlay(
        Rectangle()
            .fill(Color.trailGreen)
            .frame(width: 2),
        alignment: .leading
    )
```

### Coach Note (Website)

```css
.coach-note {
    font-family: 'Source Sans 3', sans-serif;
    font-size: 1.05rem;
    line-height: 1.7;
    color: var(--text-secondary);
    padding-left: 20px;
    border-left: 3px solid var(--accent);
}
```

## Tab Layout Pattern

Every tab follows the same structure. Today and Week are the golden references.

### Anatomy of a Tab

```
┌─────────────────────────────┐
│ Title          [actions]    │  ← Fixed header: TrailFont.dataLarge, .background(.bar)
│ subtitle (optional)         │
├─────────────────────────────┤
│ Summary bar (optional)      │  ← Fixed: stats in TrailFont.data, .background(.bar)
├─────────────────────────────┤
│                             │
│   Scrollable content        │  ← ScrollView with .padding() and 12pt card spacing
│   ┌───────────────────┐     │
│   │ Card (.regularMat)│     │
│   └───────────────────┘     │
│   ┌───────────────────┐     │
│   │ Card              │     │
│   └───────────────────┘     │
│                             │
└─────────────────────────────┘
```

### Rules

- **Navigation bar hidden** on all tabs. Each tab renders its own header.
- **Header** uses `TrailFont.dataLarge` (Geist Mono 24pt), left-aligned, with `.padding()` and `.background(.bar)`.
- **Header stays pinned.** It is outside the ScrollView so it does not scroll away.
- **Summary bar** (Week, Progress) sits between header and scroll content, also `.background(.bar)`.
- **Scroll content** uses `.padding()` with `VStack(spacing: 12)` or `LazyVStack(spacing: 12)`.
- **Cards** use `.regularMaterial` with `cornerRadius: 12`. Colored cards use `.opacity(0.06)` tint.
- **Section labels** inside cards use `TrailFont.title` (Fraunces 20pt).
- **All stats** use `TrailFont.data` or `TrailFont.dataBold` (Geist Mono 13pt).
- **Trailing chevron** (`chevron.right` in `.quaternary`) on tappable rows.
- **Top alignment** (`HStack(alignment: .top)`) on multi-line rows so icons, dates, and titles align to the first line.

### Per-Tab Implementation

| Tab       | Header          | Summary bar | Content style           |
|-----------|-----------------|-------------|-------------------------|
| Today     | (none, activity title serves as header) | — | VStack(spacing: 20), cards with coach notes |
| Week      | "Week N" + date range + "Current Week" | Mileage stats bar | LazyVStack(spacing: 12), session rows |
| Progress  | "Progress" | — | VStack(spacing: 24), material cards |
| Strength  | "Strength & More" + segmented picker | — | VStack(spacing: 20), day sections |
| Settings  | "Settings" | — | List with sections |

### Row Pattern (shared across all tabs)

Every tappable list item follows the same anatomy:

```
┌─────────────────────────────────────────────────────┐
│ [icon badge 32x32]  Title (TrailFont.title)    [>]  │
│                     Subtitle (TrailFont.data)        │
│                     Status badges (TrailFont.meta)   │
└─────────────────────────────────────────────────────┘
```

- `HStack(alignment: .top, spacing: 12)` for top alignment
- Icon badge: `Image(systemName:).frame(width:32, height:32).background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))`
- Text in a `VStack(alignment: .leading, spacing: 2)`
- Data values (distance, pace, prescriptions) in `TrailFont.data`
- Trailing chevron for tappable rows
- Current day/week highlight: `.opacity(0.08)` tinted background + `.opacity(0.3)` stroke border

### Content Cards

- Sections within scroll content do NOT wrap in `.regularMaterial` cards. Use flat layout.
- Individual tappable rows use `RoundedRectangle(cornerRadius: 12)` with optional tint highlight.
- Section labels use `TrailFont.title` (Fraunces).
- Stat callouts left-align, never center.

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
- Use `chevron.right` in `.quaternary` at trailing edge to signal tappability.

### Progressive Disclosure

Show summary at the group level, full detail on tap-through:
- **Week tab**: Session type + distance + completion status. Tap for detail sheet.
- **Strength tab**: Day name + exercise names + completion circles. Tap day for full prescription + logging.
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
| 2026-04-04 | Geist Mono for tab headers        | Tab titles, activity names, and stats all in monospace for data-forward feel |
| 2026-04-04 | Hidden navigation bars            | System SF navigation titles removed, replaced with custom TrailFont headers |
| 2026-04-04 | Fraunces for section labels only  | Serif reserved for "Coach notes", "Strength", "Heat" labels, not body or data |
