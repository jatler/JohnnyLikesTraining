# Claude Design Prototyping Prompt — SWAP Training (Simplify branch)

Paste everything below the `---` line into Claude Design once you've connected the GitHub repo on branch `simplify`.

---

You are prototyping UI for **SWAP Training**, a native iOS SwiftUI app for ultramarathon runners following the David & Megan Roche Champion Plan. Generate three high-fidelity mocks of the simplified interface. Pull live context from this repo (branch `simplify`): start with `DESIGN.md` and `PLAN.md` in the project root, then skim `TrainingApp/Sources/Views/Week/WeekView.swift`, `TrainingApp/Sources/Views/Progress/ProgressDashboardView.swift`, `TrainingApp/Sources/Views/Calendar/SessionDetailSheet.swift`, and `TrainingApp/Sources/Design/BrandKit.swift` for the exact structure we shipped.

## Three Guiding Principles

1. **Playful** — Some work, all play. Completing a workout feels satisfying; progress reads like a mountain climb. Motion does the work — language stays plain.
2. **Informative** — Workout type, distance, and interval structure are legible at a glance. Clear visual hierarchy. Coach notes stay prominent and readable.
3. **Simple** — Delete redundant surfaces. When in doubt, remove.

## Product Voice

Calm, focused, coach-led. Feels like opening a trusted coach's notebook — not a data dashboard, not a gamified fitness app. Competitors are *Runna* (clean, dark, data-forward) and *Bear Notes* (restrained typography, editorial warmth). Avoid *TrainingPeaks* (dated, corporate).

## Typography — 5 tokens, 3 families

Strict five-token system. Do not introduce new sizes, weights, or tokens.

| Token  | Font              | Size | Weight | Use                                                                |
|--------|-------------------|------|--------|--------------------------------------------------------------------|
| title  | Geist Mono        | 20pt | 500    | Tab titles, section headers, workout-type names                    |
| body   | SF Pro (system)   | 17pt | 400    | Primary UI text, descriptions, button labels                       |
| meta   | SF Pro (system)   | 12pt | 400    | Metadata, badges, counts, timestamps                               |
| coach  | Fraunces          | 16pt | 500    | Coach notes prose *only* — the single place serif voice is allowed |
| data   | Geist Mono        | 13pt | 400    | Stats: distance, pace, HR, elevation, sets×reps                    |

Apply `.fontWeight(.semibold)` inline for emphasis; do not add a bold variant token.

## Palette

**Trail Green** (brand accent — buttons, active states, today markers):
- Light: `#008D55`
- Dark: `#00B068`

**Warm stone neutrals:**
| Token         | Light     | Dark      |
|---------------|-----------|-----------|
| bg            | `#FAFAF7` | `#1C1C1A` |
| surface       | `#FFFFFF` | `#2A2A27` |
| surface-warm  | `#F5F2ED` | `#333330` |
| border        | `#E8E4DF` | `#3D3D38` |
| text-primary  | `#1C1C1A` | `#F0EDE8` |
| text-secondary| `#5A5750` | `#B8B2A8` |

**Workout type hues** (per-workout icon color — used at 15% opacity on the icon badge background):
Easy `.green` · Tempo `.orange` · Intervals `.red` · Long Run `.blue` · Recovery `.mint` · Rest `.gray` · Race `.purple` · Cross Train `.yellow` · Strength Trail Green.

## Tab Inventory (4 tabs)

| Tab       | Icon             | Purpose                                                    |
|-----------|------------------|------------------------------------------------------------|
| Week      | `calendar`       | Landing. 7-day overview, summary stats, today highlighted  |
| Progress  | `chart.bar.fill` | Weekly mileage across the plan, race readiness             |
| Strength  | `dumbbell.fill`  | Weekly template editor for strength / stretch / heat       |
| Settings  | `gearshape`      | Plan, connected services, account                          |

## Screen Anatomy

### Week tab (primary landing)

```
┌────────────────────────────────────────────────┐
│  Week 11                    ‹ › 🗓            │ ← solid Trail Green band
│  Mar 30 – Apr 5   Current Week                 │   title = Geist Mono 20pt white
│                                                │   meta = SF Pro 12pt white 85%
├────────────────────────────────────────────────┤
│  ◎ 58.2 planned  ✓ 24.1 done  3/6 runs  1 skip │ ← system bar bg
│                                                │   body semibold for "58.2 planned"
│                                                │   data for the rest
├────────────────────────────────────────────────┤
│  ┌ Low readiness (58)                        ┐ │ ← conditional banner
│  │ Swap today's Intervals with Friday's Easy? │ │   orange 8% bg, 30% stroke
│  │ [ Swap to Easy ]                           │ │   appears only on low-readiness + hard session days
│  └───────────────────────────────────────────┘ │
│                                                │
│  │ Mon 30  🏃 Easy · 6.0 mi              ›    │ ← 44pt min-height rows
│  │ Tue 31  ⚡ Intervals · 8.0 mi         ›    │   workout-type title = Geist Mono 20pt
│  │ Wed  1  🎯 Tempo · 7.0 mi             ›    │   distance = data 13pt
│  ┃ Thu  2  🏃 Long Run · 18.0 mi    ✓ 18.2   │ ← today: 3pt Trail Green left accent bar
│  │ Fri  3  🛌 Rest                       ›    │   Trail Green 25% stroke
│  │ Sat  4  🏃 Easy · 5.0 mi              ›    │
│  │ Sun  5  🏃 Recovery · 4.0 mi          ›    │
└────────────────────────────────────────────────┘
```

Rules:
- Date column: `Mon 30` single line, SF Pro body weight. Today: Trail Green + semibold.
- Workout icon badge: 28×28, rounded 8, 15% opacity fill in the workout's type color.
- Row background: `.systemBackground`. No per-workout tint. Today gets the left accent bar + 25% Trail Green stroke.
- Skipped rows: strikethrough the workout-type text + "Skipped" in red meta semibold at trailing edge. No opacity fade.
- Completed rows (Strava matched): green checkmark + actual mileage in green data font at trailing edge.
- Summary bar is non-scrolling; pinned under the header.

### Progress tab

```
┌────────────────────────────────────────────────┐
│  Progress                                      │ ← same Trail Green band header
├────────────────────────────────────────────────┤
│  Week-by-Week                                  │
│                                                │
│  W1  ▓▓░░░░░░░░░░░    8 /  22 mi              │
│  W2  ▓▓▓░░░░░░░░░   14 /  29 mi              │
│  W3  ▓▓▓▓▓░░░░░░   21 /  32 mi              │
│  W4  ▓▓▓▓▓▓▓░░░░   28 /  36 mi              │
│  …                                             │
│  W11 ▓▓▓▓▓▓▓▓▓░░░░ 42 /  55 mi  ← pulses 3x   │ ← current-week breathing scale 1.0↔1.04
│  …                                             │
│  W16 ▓▓▓▓▓▓▓▓░░░░░ — /  40 mi  🏁            │ ← race week with 14pt checkered flag
│                                                │
│  Race Readiness                    [On Track]  │
│  [days] [completion%] [weeks done]             │
└────────────────────────────────────────────────┘
```

Rules:
- Each bar is a horizontal `RoundedRectangle`. Planned (15% opacity Trail Green) underneath, actual (solid Trail Green) on top.
- Bars **grow from 0 → full width on appear**, staggered by 0.035s per week, easeOut 0.45s each. By the time your eye reaches W16 the last bars are still rising.
- Current week scales 1.0↔1.04 three times (1.8s per cycle) then settles.
- Race-week bar: 14pt row height (vs 10pt for others) + `flag.checkered` glyph pinned at the bar's final x + 4pt, fading in after the stagger reaches it.
- No copy-level mountain metaphors ("summit", "peak") — the animation carries the feeling.

### SessionDetailSheet (tap any row)

```
╔════════════════════════════════════════════════╗
║  Long Run                                Edit  ║
║  Week 11 · Thursday, Apr 2                     ║
╠════════════════════════════════════════════════╣
║  📏  18.0 mi                                   ║
║  ⏱  Easy effort, Z1/Z2                         ║
║                                                ║
║  Coach notes                                   ║  ← title in Geist Mono 20pt
║  │ Three hour gradual build. First hour        ║  ← coach prose in Fraunces 16pt
║  │ super chill, second hour you can flow a     ║     left Trail Green accent bar
║  │ bit, last hour find rhythm if your body     ║
║  │ allows. If it doesn't, easy is fine…        ║
║                                                ║
║  💪  Strength          3/5 done                ║  ← strength section w/ per-exercise checkmarks
║  🔥  Heat              25 min sauna    [Log]   ║  ← heat section
║                                                ║
║  ─── Recovery (Oura) ─────────────────         ║
║  Readiness 82  Sleep 79  HRV 48  RHR 52       ║
║                                                ║
║  ─── Plan vs Actual (Strava) ────────          ║
║  Distance 18.2 / 18.0  Pace 8:42  HR 148      ║
║                                                ║
║  [Skip]  [Swap]  [Edit]                        ║
╚════════════════════════════════════════════════╝
```

Rules:
- Coach notes block uses **Fraunces** Medium 16pt, 2pt Trail Green left border (the signature voice of the app).
- Every other text element uses one of the four non-coach tokens.
- Stretches are **not** shown here anymore — only in the Strength tab's stretch template editor.

## The Two Playful Moments

**1. Bar-grow on the Progress tab**
- On `.onAppear`, all bar widths animate 0 → target over ~1s with a 0.035s per-week stagger.
- Current week breathes 1.0 ↔ 1.04 for three cycles, then rests.
- Race-week flag (`flag.checkered`, 14pt) stays anchored at the final bar's end x, fading in as its bar reaches it.

**2. CompletionPulse**
- When any completion circle flips incomplete → complete:
  - Haptic `.success`.
  - Icon scales `1.0 → 1.12 → 1.0` via interpolating spring (stiffness 380, damping 14).
  - A Trail Green ring (`lineWidth 1.5`) expands from scale 1.0 → 1.65 while fading 0.7 → 0.0 over 0.5s.
- Applied to: session completion, strength sets, strength day, stretch day, heat log.

## What I Want From You

Generate three mocks — produce them as standalone screens I can screenshot and compare to the built SwiftUI views:

1. **Week tab mock** — Today = Thursday, Week 11 of 16. All 7 rows visible without scrolling. Low-readiness banner above the rows (today's session is Intervals; readiness 58). Include realistic workout types across the week.
2. **Progress tab mock** — Capture a moment mid-animation: weeks 1–6 fully grown, week 7 at 60%, weeks 8+ still building, current-week bar (week 11) visibly scaled up, race-week flag already placed at its final position.
3. **SessionDetailSheet mock** — Long Run day with real Champion Plan-style coach notes (3+ paragraphs), strength section showing 3/5 complete, heat section with 25-minute sauna, recovery row with Oura data, Strava plan-vs-actual comparison.

Render each at iPhone 15/16 Pro dimensions (1179×2556 or equivalent canvas). Light mode first; include a dark-mode variant if capacity allows.

When in doubt about a detail — whether spacing, state, or copy — read the source files listed at the top and match what shipped.
