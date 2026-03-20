# Training App — Plan

## Overview

A native iOS app for tracking running training. The app loads a training plan from a bundled template, maps it against a target race date, and prescribes daily runs. It integrates with Oura (recovery/readiness) and Strava (completed activities) to give a daily view of how actual training compares to the plan — and lets you easily rearrange workouts when life gets in the way.

## Example Target Race

The target race is user-configured via the plan setup screen. Example values:

| Field | Value |
|---|---|
| Race | Tahoe Rim Trail Endurance Run 100K |
| Date | July 18, 2026 (Saturday) |
| Plan | The Champion Plan for 100K to 100 Miles |
| Author | David Roche & Megan Roche, MD PhD (SWAP Running) |
| Duration | 16 weeks |
| Plan Start | March 30, 2026 (Monday) |

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | SwiftUI (iOS 17+) |
| Backend | Supabase (Postgres, Auth, Edge Functions) |
| Auth | Supabase Auth (Apple Sign-In, email) |
| Data APIs | Oura REST API (OAuth2), Strava REST API (OAuth2) |
| Local Health | HealthKit (optional, supplementary) |
| Token Storage | Keychain (KeychainAccess) |
| Charts | Swift Charts |

## Core Features

### 1. Training Plan Selection & Import

- Select a training plan from a **dropdown of bundled templates** (currently one: The Champion Plan for 100K).
- Each template is a structured JSON file containing week-by-week sessions with: workout type, target distance (km), effort/pace description, and detailed coaching notes.
- The user sets a **target race date**; the app back-calculates the plan start date and maps each session to a calendar date.
- Support common plan structures: week-based (e.g., 16-week ultra plan) with designated easy, tempo, interval, long run, recovery, rest, race, and cross-training days.
- **Edit plan after creation**: the user can change the race name, race date, or selected plan template at any time from the Plan Management screen. Changing the race date re-maps all sessions to new calendar dates. Changing the template replaces the plan entirely (with a confirmation prompt, since swaps/skips would be reset).
- Store the instantiated plan in Supabase so it syncs across sessions and survives reinstalls.
- **Future**: add more bundled templates and allow CSV import for custom plans.

### 2. Daily Run Prescription

- Home screen shows **today's prescribed run** with all relevant details: type, target distance, target pace/effort, and any coach notes.
- Week-at-a-glance view showing upcoming runs.
- Calendar view for the full plan with color-coded workout types. **Tap any day** to open a detail sheet showing the full workout prescription (type, distance, effort, coaching notes). If a Strava activity is matched, the sheet also shows the plan-vs-actual comparison.

### 3. Workout Flexibility (Swap & Reschedule)

- Tap any day to **swap it** with another day in the same week (e.g., move Wednesday's tempo to Thursday).
- **Quick swap**: if feeling low on recovery, one-tap option to swap today's hard session with the nearest easy/rest day.
- Mark a day as **skipped** with an optional reason (injury, illness, life).
- Adjustments are logged so you can see a history of plan modifications.

### 4. Oura Integration

- OAuth2 flow to connect Oura account.
- Daily sync of: **readiness score**, **sleep score**, **HRV**, **resting heart rate**, and **body temperature deviation**.
- Display recovery data alongside the daily prescription — a quick visual indicator (green/yellow/red) of whether today is a good day to push hard.
- Use readiness data to power the swap suggestions (e.g., "Your readiness is 58 — consider swapping today's intervals for an easy run").

### 5. Strava Integration

- OAuth2 flow to connect Strava account.
- Auto-import completed runs: **distance**, **pace**, **elapsed time**, **heart rate** (if available), **elevation**, and **GPS route**.
- Match each imported Strava activity to the corresponding planned session for that day.
- Show a **plan vs. actual** comparison: did you hit the target distance? Was your pace in the right zone?
- **Training block mileage chart**: a bar chart (Swift Charts) showing weekly mileage across the entire training block — planned mileage as a lighter/outline bar, actual (from Strava) as a filled bar. Highlights the current week, and overlays a target mileage trend line so you can see ramp-up and taper at a glance.

### 6. Dashboard & Progress Tracking

- Weekly summary: planned vs. actual mileage, number of sessions completed, compliance percentage.
- Long run progression chart.
- Race readiness view as race day approaches: are you on track?

### 7. Web View

- Embedded web view for Strava OAuth callback handling and for viewing detailed Strava activity maps/data when useful.
- Could also serve as a surface for a future companion web dashboard.

## Data Model (Supabase / Postgres)

### `users`
- `id` (uuid, PK)
- `email`
- `created_at`

### `training_plans`
- `id` (uuid, PK)
- `user_id` (FK → users)
- `name` (e.g., "Boston 2026 — Pfitzinger 18/70")
- `race_date` (date)
- `plan_start_date` (date, computed from race_date and plan length)
- `source_file_name`
- `created_at`

### `planned_sessions`
- `id` (uuid, PK)
- `plan_id` (FK → training_plans)
- `week_number` (int)
- `day_of_week` (int, 1=Mon..7=Sun)
- `scheduled_date` (date)
- `workout_type` (enum: easy, tempo, intervals, long_run, recovery, rest, race, cross_train)
- `target_distance_km` (decimal, nullable)
- `target_pace_description` (text, e.g., "4:30–4:45/km" or "easy effort")
- `notes` (text, nullable)
- `sort_order` (int)

### `session_swaps`
- `id` (uuid, PK)
- `plan_id` (FK → training_plans)
- `session_a_id` (FK → planned_sessions)
- `session_b_id` (FK → planned_sessions)
- `reason` (text, nullable)
- `swapped_at` (timestamp)

### `session_skips`
- `id` (uuid, PK)
- `session_id` (FK → planned_sessions)
- `reason` (text, nullable)
- `skipped_at` (timestamp)

### `oura_daily`
- `id` (uuid, PK)
- `user_id` (FK → users)
- `date` (date, unique per user)
- `readiness_score` (int, nullable)
- `sleep_score` (int, nullable)
- `hrv_average` (decimal, nullable)
- `resting_hr` (int, nullable)
- `temperature_deviation` (decimal, nullable)
- `raw_json` (jsonb)
- `synced_at` (timestamp)

### `strava_activities`
- `id` (uuid, PK)
- `user_id` (FK → users)
- `strava_id` (bigint, unique)
- `activity_date` (date)
- `name` (text)
- `distance_km` (decimal)
- `moving_time_seconds` (int)
- `elapsed_time_seconds` (int)
- `average_pace_per_km` (decimal)
- `average_hr` (int, nullable)
- `elevation_gain_m` (decimal, nullable)
- `map_polyline` (text, nullable)
- `raw_json` (jsonb)
- `synced_at` (timestamp)
- `matched_session_id` (FK → planned_sessions, nullable)

### `oauth_tokens`
- `id` (uuid, PK)
- `user_id` (FK → users)
- `provider` (enum: oura, strava)
- `access_token` (text, encrypted)
- `refresh_token` (text, encrypted)
- `expires_at` (timestamp)
- `scopes` (text)

## Screens (SwiftUI)

1. **Onboarding** — Sign in, connect Oura & Strava, import first plan.
2. **Today** — Today's prescribed run, Oura sleep, readiness, activity snapshot, swap/skip actions.
3. **Week** — 7-day view with planned and completed sessions.
4. **Calendar** — Full plan calendar, color-coded by workout type. Tap any day to open a workout detail sheet.
5. **Session Detail** — Planned workout details; if completed, plan vs. actual comparison with Strava data.
6. **Mileage Chart** — Bar chart of weekly mileage (actual from Strava vs. planned) plotted across the entire training block. Highlights the current week, shows a target mileage line, and makes it easy to spot ramp-up, taper, and any weeks where you fell short.
7. **Progress** — Compliance stats, readiness trends, race readiness summary.
8. **Plan Management** — View/edit active plan: change race name, race date, or plan template. Editing race date re-maps sessions; switching template replaces the plan (with confirmation).
9. **Settings** — Account, connected services, notifications.

## API Integration Notes

### Oura API
- Base URL: `https://api.ouraring.com/v2`
- Key endpoints: `/usercollection/daily_readiness`, `/usercollection/daily_sleep`
- OAuth2 authorization code flow.
- Daily poll or on-app-open sync.

### Strava API
- Base URL: `https://www.strava.com/api/v3`
- Key endpoints: `/athlete/activities`, `/activities/{id}`
- OAuth2 authorization code flow with `activity:read` scope.
- Webhook subscription available for real-time activity push (Strava → Supabase Edge Function → DB).
- Rate limit: 200 requests per 15 minutes, 2000 per day.

## Open Questions

1. **Strava & Oura API credentials**: I've added placeholder values in `Secrets.xcconfig` (`YOUR_STRAVA_CLIENT_ID`, etc.). Do you already have Strava and Oura developer app registrations, or do you need me to document the setup steps for obtaining credentials?
2. **Strava webhook vs polling**: Currently the app polls for activities on manual sync or app launch. Strava supports webhooks (push-based) via a Supabase Edge Function, which would auto-import activities without opening the app. Worth implementing now, or leave as a future enhancement?
3. **Oura API scopes**: The Oura v2 API has granular scopes (`daily`, `personal`, `heartrate`, `workout`, `session`). Currently requesting `daily` scope only. Do you want heart rate or workout data from Oura as well?
4. **Strava activity types**: Currently filtering for `Run`, `TrailRun`, and `VirtualRun`. Should we also import `Hike`, `Walk`, or other activity types that might count as cross-training?
5. **Compliance calculation**: The "completed" count in the progress dashboard currently relies on Strava-matched sessions. If Strava is not connected, all past non-rest sessions show as "remaining." Should we add a manual "mark as done" option for users without Strava?
6. **Token storage strategy**: OAuth tokens are currently stored locally in Keychain only. The Supabase `oauth_tokens` table exists in the schema but tokens are not synced to it yet. Should we persist tokens server-side as well (for multi-device support), or is Keychain-only sufficient?

## Resolved Decisions

- **One active training plan at a time.** No need to juggle multiple plans.
- **Plan is editable after creation.** The user can change race name, race date, or plan template at any time. Changing the date shifts all sessions; switching template replaces the plan (resets swaps/skips).
- **No push notifications.** The app is pull-based — open it to see your day.
- **No offline support.** Requires connectivity for Oura/Strava sync and Supabase.
- **Unmatched Strava activities still appear.** Any Strava activity that doesn't match a planned session shows up on that day's view as an "extra" activity (cross-training, bonus runs, etc.).
- **Apple Watch companion app** is future scope — not in the initial build.

## Milestones

### M1 — Foundation ✅
- [x] Xcode project setup with XcodeGen (`project.yml`).
- [x] Supabase project wiring (`SupabaseService`, `Config`).
- [x] Auth service (`AuthService`, `SignInView` with Apple Sign-In).
- [x] All core data models: `TrainingPlan`, `PlannedSession`, `WorkoutType`, `SessionSwap`, `SessionSkip`, `OuraDaily`, `StravaActivity`.
- [x] Supabase schema migration (`20260318000000_initial_schema.sql`) — all tables, enums, and RLS policies.
- [x] App shell with tab-based navigation (`ContentView`).
- [x] Placeholder views: `TodayView`, `WeekView`, `PlanCalendarView`, `ProgressDashboardView`, `SettingsView`.

### M2 — Plan Setup & Import ✅
- [x] Training plan template system (`TrainingPlanTemplate`, `SessionTemplate` models).
- [x] `PlanTemplateService` — loads bundled JSON templates, back-calculates start date from race date, generates `TrainingPlan` + `PlannedSession` array.
- [x] Bundled "Champion Plan for 100K" template (`champion_plan_100k.json`) — 16 weeks, 112 sessions, parsed from SWAP Running PDF.
- [x] `TrainingPlanStore` — `@Observable` state container holding the active plan and sessions, with computed helpers for today's session and current week.
- [x] `PlanSetupView` — user inputs race name, picks race date, selects a plan template from a dropdown, sees computed plan summary (duration, start date, total sessions). Tahoe Rim Trail 100K used as placeholder example.
- [x] Plan setup wired into `TodayView` — empty state prompts plan creation; once created, shows today's workout card with type, distance, effort, and notes.
- [x] `TrainingPlanStore` injected as environment object from app root.
- [x] `PlanEditView` — edit race name, race date, or plan template for an existing plan. Re-maps session dates on date change; full plan replacement on template change (with confirmation).
- [x] Persist generated plan to Supabase (plan + sessions saved on create/edit; loaded on app launch; swaps and skips persisted as they happen).
- [x] Plan calendar view with real data binding — tap any day to open a workout detail sheet (`SessionDetailSheet`) showing the full session prescription. Color-coded grid with month headers, current-week highlight, and color legend.

### M3 — Daily Prescription & Swaps ✅
- [x] Today screen shows real workout details from the active plan (session card with type icon, distance in km/mi, effort description, coaching notes, week number, plan info bar).
- [x] Swap and skip functionality — swap any two sessions in the same week (manual picker or quick-swap to nearest easy/rest day). Skip with reason (injury, illness, life) or unskip to restore. All swaps/skips persisted to Supabase.
- [x] Week view with real data — shows sessions for the selected week with previous/next navigation. Each row shows workout type, distance, pace, and skip status. Tap any session to open the detail sheet. Current day highlighted.

### M4 — Strava Integration ✅
- [x] `StravaService` — full OAuth2 authorization code flow via `ASWebAuthenticationSession`, token exchange, refresh, and Keychain persistence.
- [x] `KeychainService` — lightweight system Keychain wrapper for secure token storage (Strava + Oura access/refresh tokens, expiry timestamps).
- [x] Config wiring — `STRAVA_CLIENT_ID` and `STRAVA_CLIENT_SECRET` exposed via `Secrets.xcconfig` → `Info.plist` → `Config.swift`. Custom URL scheme `training://` registered for OAuth callbacks.
- [x] Activity import — paginated fetch from `/athlete/activities`, filters for Run/TrailRun/VirtualRun, converts Strava API response (meters, m/s) to app model (km, min/km).
- [x] Auto-matching — `autoMatchActivities` matches imported Strava activities to planned sessions by date. `activity(for:)` and `activities(on:)` query helpers.
- [x] Plan vs. actual comparison on `SessionDetailSheet` — when a matched Strava activity exists, shows distance (actual vs planned with % delta), pace, duration, heart rate, and elevation.
- [x] Strava completion indicators on `WeekView` (checkmark + actual distance) and `PlanCalendarView` (green checkmark overlay on calendar cells).
- [x] Strava banner on `TodayView` — shows completed run details alongside today's prescription.
- [x] Settings — connect/disconnect Strava, manual sync button with loading state, athlete name display, last sync timestamp.
- [x] Supabase persistence — upserts activities on `strava_id` unique constraint; loads cached activities on app launch.

### M5 — Oura Integration ✅
- [x] `OuraService` — full OAuth2 flow via `ASWebAuthenticationSession`, token exchange, refresh, Keychain persistence.
- [x] Config wiring — `OURA_CLIENT_ID` and `OURA_CLIENT_SECRET` via `Secrets.xcconfig` → `Info.plist` → `Config.swift`.
- [x] Daily sync — fetches readiness, sleep, and heart rate data from Oura v2 API (`/usercollection/daily_readiness`, `/usercollection/daily_sleep`). Merges into unified `OuraDaily` records.
- [x] Recovery card on `TodayView` — shows readiness score, sleep score, HRV, and resting heart rate with color-coded readiness badge (green/orange/red).
- [x] Readiness-based swap suggestions — when readiness is low and today is a hard session, suggests swapping with nearest easy/rest day. One-tap swap with reason logged ("Low readiness (58)").
- [x] Recovery row on `SessionDetailSheet` — shows readiness, sleep, and HRV for the session's date.
- [x] Settings — connect/disconnect Oura, manual sync button with loading state, last sync timestamp.
- [x] Supabase persistence — upserts daily data on `(user_id, date)` unique constraint; loads cached data on app launch.

### M6 — Progress & Polish ✅
- [x] `ProgressDashboardView` — full progress tracking with three sections:
  - **Compliance card**: circular progress indicators for completed/skipped/remaining percentages, session counts.
  - **Weekly mileage chart** (Swift Charts): grouped bar chart showing planned vs actual km per week across the full training block. Current week highlighted with orange rule mark. Chart legend for Planned/Actual.
  - **Week-by-week detail list**: progress bars per week showing actual/planned km and session counts.
  - **Race readiness card**: days until race, compliance percentage, weeks completed, readiness level badge (On Track / Fair / Behind / Starting) with contextual message.
- [x] Week summary bar on `WeekView` — shows total planned km, actual km done, sessions completed, and skipped count for the selected week.
- [x] Scroll fixes — `WeekView` and `PlanCalendarView` now properly scroll all content with bottom padding to prevent tab bar clipping. `WeekView` uses `LazyVStack` for efficient rendering.
- [x] All new services (`StravaService`, `OuraService`) injected as `@Observable` environment objects from `TrainingApp.swift` through the full view hierarchy.
- [x] Error handling — all OAuth flows surface errors via alerts in `SettingsView`. API failures logged with descriptive messages. Token refresh happens automatically before API calls.

#### M6 — Remaining Polish (future)
- [ ] Long run progression chart (separate visualization of long run distances over time).
- [ ] Readiness trends chart (HRV, sleep score over past 30 days).
- [ ] Unmatched Strava activities view — show extra activities (cross-training, bonus runs) that don't match a planned session.
- [ ] Strava webhook integration via Supabase Edge Function for real-time activity import.
- [ ] Onboarding flow — guided first-launch experience (sign in → connect services → create plan).
- [ ] Edge cases: handle expired/revoked OAuth tokens gracefully, network error retry, plan deletion cleanup.

## Project Structure

```
TrainingApp/
├── project.yml                          # XcodeGen config
├── Info.plist                           # URL scheme (training://), API key refs
├── Secrets.xcconfig                     # API keys (not committed)
├── Training.entitlements
├── Resources/
│   ├── Assets.xcassets/
│   └── champion_plan_100k.json          # Bundled 16-week plan template
└── Sources/
    ├── App/
    │   ├── TrainingApp.swift             # Environment object injection
    │   ├── ContentView.swift             # Auth gate + tab bar
    │   └── Config.swift                  # Supabase, Strava, Oura config
    ├── Models/
    │   ├── TrainingPlan.swift
    │   ├── TrainingPlanTemplate.swift
    │   ├── PlannedSession.swift
    │   ├── WorkoutType.swift
    │   ├── SessionSwap.swift
    │   ├── SessionSkip.swift
    │   ├── StravaActivity.swift
    │   └── OuraDaily.swift
    ├── Services/
    │   ├── SupabaseService.swift
    │   ├── AuthService.swift
    │   ├── PlanTemplateService.swift     # Load templates, generate plans
    │   ├── TrainingPlanStore.swift       # Active plan state (@Observable)
    │   ├── StravaService.swift           # OAuth2, activity import, auto-match
    │   ├── OuraService.swift             # OAuth2, readiness/sleep sync
    │   └── KeychainService.swift         # Secure token storage
    └── Views/
        ├── Auth/SignInView.swift
        ├── Plan/PlanSetupView.swift
        ├── Plan/PlanEditView.swift
        ├── Today/TodayView.swift         # Recovery card, swap suggestions
        ├── Week/WeekView.swift           # Week summary, completion status
        ├── Calendar/PlanCalendarView.swift # Completion dots
        ├── Calendar/SessionDetailSheet.swift # Plan vs actual comparison
        ├── Progress/ProgressDashboardView.swift # Charts, compliance, readiness
        └── Settings/SettingsView.swift   # Strava/Oura connect/disconnect

supabase/
├── config.toml
└── migrations/
    └── 20260318000000_initial_schema.sql
```
