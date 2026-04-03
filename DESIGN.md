# SWAP Training Design System

## Brand

- **App name:** SWAP Training
- **Coach credit:** David & Megan Roche
- **Tagline:** "Train with David & Megan Roche."
- **Platform:** iOS (SwiftUI, iOS 17+)
- **Personality:** Calm, focused, coach-led. Not flashy, not gamified. The app should feel like a trusted training journal, not a social fitness platform.

## Color System

### Accent Color (SWAP Green)

The primary brand color. Used for tab tint, buttons, strength/stretch labels, and interactive elements.

| Mode  | R     | G     | B     | Hex       |
|-------|-------|-------|-------|-----------|
| Light | 0.000 | 0.553 | 0.333 | `#008D55` |
| Dark  | 0.000 | 0.690 | 0.408 | `#00B068` |

Defined in `AccentColor.colorset`. Accessed via `Color.swapAccent`.

**Opacity variants:**
- `swapAccentLight` (0.12) -- background tint for active/selected states
- `swapAccentSubtle` (0.06) -- card backgrounds for accent-themed sections

### Workout Type Colors

Each workout type has a dedicated color for instant recognition on the calendar, week view, and today view.

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
| Strength    | `Color.swapAccent`| `dumbbell.fill`           |

Defined in `WorkoutType.swift`.

### Status Colors

| State     | Color                | Usage                           |
|-----------|----------------------|---------------------------------|
| Completed | `.green`             | Checkmarks, "Done" labels       |
| Skipped   | `.red`               | Skipped badges, skip counts     |
| Modified  | `.orange`            | Overridden sessions, deload     |
| Heat      | `.orange`            | Heat/sauna sessions             |
| Stretch   | `Color.swapAccent`   | Stretch labels and counts       |

### Semantic Colors

Use SwiftUI system semantic colors for text hierarchy:

- `.primary` -- main text (exercise names, headings)
- `.secondary` -- supporting text (prescriptions, metadata)
- `.tertiary` -- subtle text (notes, fine print)
- `.quaternary` -- dividers, chevrons, faint backgrounds

## Typography

System San Francisco fonts only. No custom typefaces.

### Scale (4 levels only)

| Level   | Style            | Usage                                        |
|---------|------------------|----------------------------------------------|
| Title   | `.headline`      | Day names, section headers                   |
| Body    | `.body`          | Exercise names, workout names, coach notes   |
| Detail  | `.subheadline`   | Prescriptions, distances, descriptions       |
| Meta    | `.caption`       | Dates, counts, badges, attribution           |

### Rules

- **Use only these 4 levels.** Do not use `.title2`, `.title3`, `.caption2`, or `.footnote` in scroll content. Navigation titles are handled by the system and don't count.
- Body (`.body`) is the default for any named item (exercises, workouts, stretches). If it has a name the user needs to read, it's `.body`.
- Use `.bold()` for emphasis within a level (e.g., `.body.bold()` for exercise names vs `.body` for coach notes). Never `.black` or `.heavy`.
- Use `.strikethrough()` for completed/skipped items, not opacity reduction.

## Spacing

### Padding

| Context               | Value  |
|-----------------------|--------|
| Screen edge           | 16pt (`.padding()`)  |
| Card internal         | 12--16pt             |
| Between cards         | 12pt (LazyVStack spacing) |
| Between sections      | 16--20pt             |
| Text vertical spacing | 2--4pt               |
| Badge internal        | 4--6pt horizontal, 2pt vertical |

### Corner Radius

| Element          | Radius |
|------------------|--------|
| Cards            | 12pt   |
| Icon backgrounds | 8--10pt|
| Inline badges    | `Capsule()` |
| Progress bars    | 3pt    |
| Small containers | 6pt    |

## Components

### Cards

The standard card pattern used across all views:

```swift
.padding()
.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
```

For colored cards (status sections):
```swift
.padding()
.background(Color.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
```

Use `.regularMaterial` for data cards. Use `.bar` for sticky headers/navigators. Use color `.opacity(0.06)` for tinted section backgrounds. Use `.opacity(0.15)` for tinted borders via `.strokeBorder()`.

### Completion Indicators

**Tappable circle** (preferred pattern):
```swift
Button { toggleCompletion() } label: {
    Image(systemName: complete ? "checkmark.circle.fill" : "circle")
        .font(.title3)
        .foregroundStyle(complete ? .green : .secondary.opacity(0.4))
}
```

Used in: StretchDayDetailView, TodayView inline stretches. Should be adopted for all completion toggles.

**Non-interactive checkmark** (read-only status):
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

Always set `.tint(Color.swapAccent)` on bordered buttons unless the action has a semantic color (destructive = `.red`).

Control sizes: `.controlSize(.small)` for inline actions. Never `.controlSize(.mini)` (too small for reliable tap targets).

### Sheets

- Detail/logging views: `.presentationDetents([.large])`
- Quick input forms: `.presentationDetents([.medium])`
- Always include a "Done" button in `.confirmationAction` toolbar position.

### Badges

Small inline labels for status or type:
```swift
Text("BW")
    .font(.caption.bold())
    .foregroundStyle(.secondary)
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(.quaternary, in: Capsule())
```

### Workout Icon Badge

Icon with tinted background, used in session rows:
```swift
Image(systemName: workoutType.iconName)
    .font(.body)
    .foregroundStyle(workoutType.swiftUIColor)
    .frame(width: 32, height: 32)
    .background(workoutType.swiftUIColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
```

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

Show summary at the group level, full detail on tap-through. Specifically:

- **Week tab**: Session type + distance + completion status. Tap for detail sheet.
- **Strength tab**: Day name + exercise names + completion circles. Tap day for full prescription + logging.
- **Today view**: Current session with coach notes expanded. Ancillary sections (heat, strength, stretch) show compact status.

## Interaction States

Every interactive element should specify these states:

| State    | Visual Treatment                                |
|----------|-------------------------------------------------|
| Default  | Standard foreground colors                      |
| Pressed  | System highlight (SwiftUI handles for Button)   |
| Complete | `.green` checkmark, `.strikethrough` on text    |
| Disabled | `.opacity(0.4)`, non-interactive                |
| Error    | Alert with "OK" dismiss                         |

### Empty States

Every list/section that can be empty needs:

1. An SF Symbol icon at `.system(size: 48)` in accent or secondary color
2. A title in `.title3` + `.secondary`
3. A description in `.subheadline` + `.tertiary`, centered, max width 280pt
4. A primary action button (`.borderedProminent`) if the user can fix the empty state

Examples: WeekView empty state (line 375), StrengthTemplateView empty state (line 554).

## Accessibility

- Minimum tap target: 44x44pt. Buttons below this size must use `.contentShape(Rectangle())` to expand the hit area.
- Use system Dynamic Type. Never hardcode font sizes except for decorative large numbers.
- All images should have accessibility labels or be marked `.accessibilityHidden(true)` if decorative.
- Color is never the sole indicator of state. Pair color with icons (circle vs checkmark.circle.fill) or text ("Done", "Skipped").

## Key Files

| File | Purpose |
|------|---------|
| `Sources/Design/BrandKit.swift` | Color extensions, brand constants |
| `Sources/Views/Shared/SessionComponents.swift` | Reusable Oura, Strava, comparison cells |
| `Sources/Models/WorkoutType.swift` | Workout colors, icons, display names |
| `Resources/Assets.xcassets/AccentColor.colorset` | Accent color asset (light + dark) |
