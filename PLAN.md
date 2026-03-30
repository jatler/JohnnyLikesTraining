t gonewild
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

- Select a training plan from a **dropdown of bundled templates**: **The Champion Plan for 100K to 100 Miles** (16 weeks, ultra) and **10-Week Winter Plan** (SWAP winter base, Z2/uphill treadmill focus, optional ski/x-train).
- Each template is a structured JSON file containing week-by-week sessions with: workout type, target distance (km), effort/pace description, and detailed coaching notes.
- **Coach notes are always the original, verbatim text** from the plan source (e.g. bundled JSON / publisher PDF). They are stored in full in `planned_sessions.notes` and shown in full in the app. We do **not** replace them with AI-generated summaries in templates, sync, or UI. If we ever add AI helpers (e.g. “quick recap”), they must be additive (separate field or collapsible section), not a substitute for the stored notes.
- **Bundled templates** keep the full coaching block in `notes` (including the effort/pace line when it would otherwise live only in `pace_description`), so nothing is split across fields in a way that looks “cut off.” On sync load, if the bundle has **longer** notes than Supabase for the same week/day/workout (e.g. after an app update ships richer JSON), the app **backfills** `planned_sessions.notes` for sessions that are not user-overridden.
- The user sets a **target race date**; the app back-calculates the plan start date and maps each session to a calendar date.
- Support common plan structures: week-based (e.g., 16-week ultra plan) with designated easy, tempo, interval, long run, recovery, rest, race, and cross-training days.
- **Edit plan after creation**: the user can change the race name, race date, or selected plan template at any time from the Plan Management screen. Changing the race date re-maps all sessions to new calendar dates. Changing the template replaces the plan entirely (with a confirmation prompt, since swaps/skips would be reset).
- Store the instantiated plan in Supabase so it syncs across sessions and survives reinstalls.
- **Future**: add more bundled templates and allow CSV import for custom plans.

#### Importing coach notes from a PDF (repeatable for every new template)

Use this whenever you add or refresh a bundled plan whose **original source is a PDF**. The goal is to fill `sessions[].notes` with **verbatim publisher text**, not summaries.

**1. Preconditions**

- You have the **source PDF** (e.g. SWAP plan document) and the right to use its text in the app.
- The app already has (or you have drafted) a **template JSON** that matches `TrainingPlanTemplate`: `sessions[]` with correct `week` (1-based), `day` (1 = Monday … 7 = Sunday), `workout_type`, `target_distance_km`, `pace_description`, and any extra rows (e.g. `strength` on the same calendar day as a run). The import script **only updates `notes`**; it does not invent distances or workout types.
- **PDF layout:** The Champion workflow assumes a **grid**: rows labeled `Week 1` … `Week N` and columns **Mon … Sun**. If a future PDF is not table-shaped, you cannot reuse the same script as-is — use pdfplumber (or manual copy-edit) to map cells to `(week, day)` yourself, then merge into JSON.

**2. Tooling**

```bash
cd /path/to/Training   # repo root
pip install -r scripts/requirements.txt   # installs pdfplumber
```

**3. Champion plan (current automation)**

- Script: `scripts/sync_champion_plan_from_pdf.py`
- Default output: `TrainingApp/Resources/champion_plan_100k.json`
- Run (PDF path optional; default is `~/Downloads/The Champion Plan for 100 km to 100 miles.pdf`):

```bash
python3 scripts/sync_champion_plan_from_pdf.py "/path/to/The Champion Plan for 100 km to 100 miles.pdf"
```

**4. Adapting for a *new* bundled template**

1. Add `TrainingApp/Resources/<your_plan_id>.json` with the full session list (structure aligned with `champion_plan_100k.json` and `SessionTemplate` / `TrainingPlanTemplate` in code).
2. **Copy** `scripts/sync_champion_plan_from_pdf.py` to e.g. `scripts/sync_<your_plan_id>_from_pdf.py` and change:
   - `JSON_PATH` → your new resource file.
   - `DEFAULT_PDF` → default location or name for that plan’s PDF.
3. Adjust **`fix_typos()`** in the copy if that PDF has different recurring OCR glitches (the Champion script normalizes a few known artifacts).
4. Reuse the same **splitting rules** unless the new PDF uses different wording:
   - If a cell contains **`Light Strength`**, the **main** workout row gets the text **before** that phrase; the **`strength`** row on the same day gets from **`Light Strength`** onward.
   - If the same calendar day has both a **main** session and **`strength`**, and the cell ends with a **`Mountain Legs`…** tail, the main session drops that tail and **strength** keeps it (avoids duplicating the full cell in both rows).
5. Run your new script against the PDF; commit the updated JSON.
6. **Register the template** in `PlanTemplateService` / bundled resources so it appears in the template picker.
7. **Ship / verify:** After users update the app, `TrainingPlanStore` **reconciles** longer bundled `notes` into Supabase for non-overridden sessions on next load; testers can also create a fresh plan from the template to pick up new copy immediately.

**5. QA checklist**

- Spot-check **early week, a hard week, race/taper week** (e.g. weeks 1, 8, 16) for truncated cells or wrong day alignment.
- Build the iOS target and open a few **SessionDetailSheet** / **Today** entries to confirm length and formatting.
- If the PDF is revised by the publisher, re-run the script and ship a new app version (or rely on reconcile for existing installs).
- **10-Week Winter Plan (`winter_plan_10w.json`):** After generating or editing from the PDF, sanity-check **Wednesday** cells: steady **road** miles → `tempo`; **Z2-only** uphill treadmill (no `N–M x K minutes` reps) → `easy` with pace **Z2 uphill treadmill**; **uphill TM with `N–M x K minutes` around 1-hour effort** → `intervals` with pace **1-hour effort on uphill threshold intervals** (same idea as the Champion plan). For **Tuesday** interval sessions, `target_distance_km` should reflect the **sum of mile-range midpoints** in the warm-up / main / cool-down (not just the first range).

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
- **Crown indicator** (👑) on readiness and sleep scores ≥ 85 — shown in the Today recovery card and on the SessionDetailSheet recovery row. Highlights exceptional recovery days at a glance.
- Use readiness data to power the swap suggestions (e.g., "Your readiness is 58 — consider swapping today's intervals for an easy run").

### 5. Strava Integration

- OAuth2 flow to connect Strava account.
- Auto-import completed activities: **runs** (Run, TrailRun, VirtualRun), **cycling** (Ride, MountainBikeRide, GravelRide, EBikeRide, VirtualRide), **skiing** (CrossCountrySkiing, BackcountrySki, NordicSki, AlpineSki, Snowboard), **other cross-training** (Elliptical, Hike, RockClimbing, Rowing, StairStepper, Swim, Walk), **strength training** (WeightTraining, Crossfit), and **yoga** (Yoga). All cycling and skiing activities are labeled as cross-training. Each activity stores its Strava `activity_type` for filtering and display.
- Match each imported Strava activity to the corresponding planned session for that day. Runs match run sessions; cross-training matches `cross_train` sessions; strength/yoga activities appear as supplementary on any day.
- Show a **plan vs. actual** comparison: did you hit the target distance? Was your pace in the right zone?
- **Training block mileage chart**: a bar chart (Swift Charts) showing weekly mileage across the entire training block — planned mileage as a lighter/outline bar, actual (from Strava) as a filled bar. Highlights the current week, and overlays a target mileage trend line so you can see ramp-up and taper at a glance.

### 6. Dashboard & Progress Tracking

- Weekly summary: planned vs. actual mileage, number of sessions completed, completion percentage.
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
- `notes` (text, nullable — **full verbatim coach notes** from the plan template, not shortened or AI-summarized)
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
- `activity_type` (text — Strava activity type: Run, TrailRun, WeightTraining, Yoga, etc.)
- `raw_json` (jsonb)
- `synced_at` (timestamp)
- `matched_session_id` (FK → planned_sessions, nullable)

### `session_overrides`
- `id` (uuid, PK)
- `session_id` (FK → planned_sessions, unique)
- `original_workout_type` (enum, nullable — stores original before override)
- `original_target_distance_km` (decimal, nullable)
- `original_target_pace_description` (text, nullable)
- `original_notes` (text, nullable)
- `override_reason` (text, nullable)
- `overridden_at` (timestamp)

### `strength_templates`
- `id` (uuid, PK)
- `plan_id` (FK → training_plans)
- `created_at` (timestamp)
- `updated_at` (timestamp)

### `strength_template_exercises`
- `id` (uuid, PK)
- `template_id` (FK → strength_templates)
- `day_of_week` (int, 1=Mon..7=Sun)
- `exercise_name` (text)
- `target_sets` (int)
- `target_reps` (int)
- `target_weight_kg` (decimal, nullable — null = bodyweight)
- `target_rpe` (decimal, nullable)
- `is_bodyweight` (boolean, default false)
- `is_timed` (boolean, default false — when true, reps represent seconds)
- `sort_order` (int)
- `notes` (text, nullable)

### `strength_sessions`
- `id` (uuid, PK)
- `plan_id` (FK → training_plans)
- `template_exercise_id` (FK → strength_template_exercises, nullable — null if one-off)
- `scheduled_date` (date)
- `week_number` (int)
- `day_of_week` (int)
- `exercise_name` (text)
- `prescribed_sets` (int)
- `prescribed_reps` (int — stores seconds when `is_timed` is true)
- `prescribed_weight_kg` (decimal, nullable)
- `prescribed_rpe` (decimal, nullable)
- `is_timed` (boolean, default false)
- `is_deload` (boolean, default false)
- `is_template_override` (boolean, default false — true if user made a one-off edit)

### `strength_logs`
- `id` (uuid, PK)
- `session_id` (FK → strength_sessions)
- `set_number` (int)
- `actual_reps` (int)
- `actual_weight_kg` (decimal, nullable)
- `rpe` (decimal, nullable)
- `completed_at` (timestamp)
- `notes` (text, nullable)

### `stretch_templates`
- `id` (uuid, PK)
- `plan_id` (FK → training_plans)
- `created_at` (timestamp)
- `updated_at` (timestamp)

### `stretch_template_exercises`
- `id` (uuid, PK)
- `template_id` (FK → stretch_templates)
- `day_of_week` (int, 1=Mon..7=Sun)
- `stretch_name` (text)
- `hold_seconds` (int)
- `sets` (int)
- `is_bilateral` (boolean, default true)
- `sort_order` (int)
- `notes` (text, nullable — PT instructions, cues, modifications)

### `stretch_sessions`
- `id` (uuid, PK)
- `plan_id` (FK → training_plans)
- `template_exercise_id` (FK → stretch_template_exercises, nullable)
- `scheduled_date` (date)
- `week_number` (int)
- `day_of_week` (int, 1=Mon..7=Sun)
- `stretch_name` (text)
- `prescribed_hold_seconds` (int)
- `prescribed_sets` (int)
- `is_bilateral` (boolean)

### `stretch_logs`
- `id` (uuid, PK)
- `session_id` (FK → stretch_sessions)
- `completed_at` (timestamp)
- `notes` (text, nullable)

### `heat_sessions`
- `id` (uuid, PK)
- `plan_id` (FK → training_plans)
- `scheduled_date` (date)
- `week_number` (int)
- `day_of_week` (int, 1=Mon..7=Sun)
- `session_type` (text — sauna, hot_tub, heat_suit)
- `target_duration_minutes` (int)
- `notes` (text, nullable)

### `heat_logs`
- `id` (uuid, PK)
- `session_id` (FK → heat_sessions)
- `actual_duration_minutes` (int)
- `session_type` (text — sauna, hot_tub, heat_suit)
- `completed_at` (timestamp)
- `notes` (text, nullable)

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
7. **Progress** — Completion stats, readiness trends, race readiness summary.
8. **Plan Management** — View/edit active plan: change race name, race date, or plan template. Editing race date re-maps sessions; switching template replaces the plan (with confirmation).
9. **Strength & More** (tab) — Weekly strength template editor. Shows exercises grouped by day of week. Inline editing for sets, reps, weight. "Apply to all future weeks" toggle. Progression suggestions shown as badges on exercises ready to progress. Stretch section for managing prescribed stretch/mobility days (add/remove days, choose routine type and duration). Heat section at the bottom for managing prescribed heat days (add/remove days, view type and duration).
10. **Strength Day Detail** — Logging view for a single day's strength work. Shows prescribed exercises with target sets/reps/weight. User taps each set to log actual reps and weight. Completion state tracked per set.
11. **Exercise History** — Per-exercise progression chart showing weight × reps over time. Accessible from the strength template or from a logged session.
12. **Settings** — Account, connected services, notifications.

## API Integration Notes

### Oura API
- Base URL: `https://api.ouraring.com/v2`
- Key endpoints: `/usercollection/daily_readiness`, `/usercollection/daily_sleep`, `/usercollection/sleep` (detailed sleep periods with HR/HRV).
- OAuth2 authorization code flow with `daily` scope.
- Redirect URI: `training://oura/callback` (custom URL scheme, intercepted by `ASWebAuthenticationSession`).
- Daily poll or on-app-open sync.
- **HRV & resting HR** come from the `/usercollection/sleep` endpoint (detailed sleep periods), **not** from `daily_sleep` or `daily_cardiovascular_age`. The app picks the longest sleep period per day to extract `lowest_heart_rate` and `average_hrv`.
- **Sleep periods fetch** must check the HTTP response status and use explicit `try` (not `try?`) when decoding so that API errors and JSON decode failures are visible in the console. Debug builds log the raw response and first few parsed periods to aid troubleshooting.

#### Oura Developer App Setup

1. Go to [cloud.ouraring.com](https://cloud.ouraring.com) and sign in with your Oura account.
2. Navigate to **My Applications** (or the developer section).
3. Click **Create New Application**:
   - **App Name**: Training (or whatever you prefer)
   - **Redirect URI**: `training://oura/callback` — must match `Config.ouraRedirectURI` exactly.
   - **Scopes**: select at minimum **Daily** (covers readiness, sleep, and detailed sleep periods).
4. After creation, copy the **Client ID** and **Client Secret**.
5. Paste them into `TrainingApp/Secrets.xcconfig`:
   ```
   OURA_CLIENT_ID = <your client id>
   OURA_CLIENT_SECRET = <your client secret>
   ```
6. Rebuild the app. The Oura connect button in Settings will now trigger the real OAuth flow.

### Strava API
- Base URL: `https://www.strava.com/api/v3`
- Key endpoints: `/athlete/activities`, `/activities/{id}`
- OAuth2 authorization code flow with `activity:read` scope.
- Webhook subscription available for real-time activity push (Strava → Supabase Edge Function → DB).
- Rate limit: 200 requests per 15 minutes, 2000 per day.

### 8. Manual Workout Adjustments (Week View)

- Tap any session in the **Week View** to open an **editable detail sheet** (not just read-only).
- Editable fields: workout type, target distance, effort/pace description, and coaching notes.
- Changes are saved as **session overrides** — the original template values are preserved so the user can "reset to plan" at any time.
- Override history is logged (what changed, when) for accountability and debugging.
- Visual indicator on overridden sessions (e.g., a small pencil icon or subtle badge) so the user can distinguish manually adjusted workouts from the original plan.
- Overrides are per-session by default with the option to propagate to other weeks on the same day.

### 9. Strength Training Program

A dedicated **Strength tab** at the bottom of the app for managing a weekly strength program that runs alongside the running plan.

#### Weekly Strength Template
- The user defines a **weekly strength template**: a set of exercises assigned to specific days of the week.
- To start the strength template is pulled in from the training plan.
- Each exercise entry includes: exercise name, target sets, target reps **or** target duration in seconds (timed flag), target weight (or bodyweight flag), RPE target (optional), and notes.
- **Timed exercises**: exercises like planks and side planks are flagged as `is_timed = true`. When timed, the reps field stores seconds and the UI shows "3×45s" instead of "3×45 reps". Logging records seconds held rather than rep count.
- The template is organized by day (e.g., Monday = upper body push/pull, Thursday = lower body + core).
- Editing the template **propagates changes forward** to all future weeks automatically. Past weeks (already completed) are not retroactively changed.
- Users can also make **one-off edits** to a specific week's strength session without affecting the template.

#### Dynamic Load Progression
- Week-over-week strength load (sets, reps, weight) **dynamically adjusts** based on:
  - **Past lifting data**: if the user consistently hits all target reps at a given weight, the system suggests a weight increase (e.g., +2.5 kg / +5 lbs) or rep increase for the next week.
  - **Running load**: during high-mileage or hard running weeks, strength volume is automatically scaled back (fewer sets, maintained weight) to manage total training stress. During taper or lower-volume running weeks, strength volume can increase.
  - **Recovery signals**: if Oura readiness trends downward over multiple days, strength suggestions become more conservative (maintain or reduce load rather than progress).
- Progression follows a simple **linear periodization** model by default:
  - **Accumulation phase**: increase reps within a range (e.g., 3×8 → 3×10 → 3×12).
  - **Intensification phase**: once the top of the rep range is hit, increase weight and reset to the bottom of the rep range (e.g., 3×12 @ 60 kg → 3×8 @ 65 kg).
  - **Deload weeks**: every 4th week (configurable), reduce volume by ~40% (fewer sets, same weight) to allow recovery.
- The user can override any suggestion — the system learns from what they actually do, not just what it prescribed.
- A **progression log** shows weight/rep history per exercise over time (line chart or simple table).

#### Strength–Running Integration
- The Week View shows both running and strength sessions for each day, so the user sees total training load at a glance.
- The Today View includes strength work if scheduled for that day, displayed below the running prescription.
- Strength completion can be logged manually (sets × reps × weight for each exercise) since there's no Strava equivalent for lifting.

### 10. Stretch Routines

A dedicated section in the **Strength tab** for managing individual prescribed stretches that run alongside the running and strength programs. Users can add specific stretches recommended by their PT.

#### Weekly Stretch Template
- The user defines a **weekly stretch template**: individual named stretches assigned to specific days of the week.
- The initial stretch template is seeded from the training plan, but users can **add, edit, and remove individual stretches** at any time (e.g., adding PT-recommended stretches like "Pigeon Pose", "Couch Stretch").
- Each stretch entry includes: stretch name, hold duration (seconds), number of sets, bilateral flag (each side), and notes (PT cues, modifications, form tips).
- The template is organized by day (e.g., Tuesday = post-run stretches, Sunday = full mobility routine).
- Editing the template **propagates changes forward** to all future weeks. Past weeks are not retroactively changed.
- Default days: **Tuesday** (post-run basics), **Saturday** (extended post-long-run), **Sunday** (full mobility).

#### Logging
- Tap a stretch indicator on the Week View or Today View to open the **Stretch Day Detail** view.
- Each individual stretch can be marked as done with a single tap.
- Completion is tracked per stretch per day with a running count (e.g., "3/5 done").

#### Stretch–Running Integration
- The Today View shows all scheduled stretches for the day with individual completion checkmarks.
- The Week View displays a stretch icon on days with prescribed stretches, with a completion count badge.

### 11. Heat Training

Track passive heat acclimation sessions (sauna, hot tub, heat suit) prescribed by the training plan.

#### Prescribed Heat Days
- Heat sessions are pulled from the training plan template — certain days (typically rest and easy days) are flagged for heat acclimation. Default days are **Monday** (rest) and **Friday** (recovery).
- Each prescribed session includes: session type (sauna, hot tub, heat suit), target duration in minutes, and notes.
- The template defines a weekly pattern of heat days; on plan import, `HeatSession` records are generated for each week.
- Heat days are **editable from the Strength & Heat tab** — add new heat days, remove existing ones, choose session type and duration. Changes propagate across all weeks.

#### Logging
- Tap a heat indicator on the Week View or Today View to log a completed session.
- Log fields: session type (sauna / hot tub / heat suit), actual duration in minutes.
- Completion is shown as a flame icon on the Week View, Today View, and Calendar View.

#### Heat–Running Integration
- The Today View shows scheduled heat work alongside running and strength.
- The Week View displays a flame icon on days with prescribed heat, with a checkmark when completed.

## Open Questions

1. **Strava webhook vs polling**: Currently the app polls for activities on manual sync or app launch. Strava supports webhooks (push-based) via a Supabase Edge Function, which would auto-import activities without opening the app. Worth implementing now, or leave as a future enhancement?
2. ~~**Strava activity types**: Currently filtering for `Run`, `TrailRun`, and `VirtualRun`. Should we also import `Hike`, `Walk`, or other activity types that might count as cross-training?~~ **Resolved**: Now importing runs (Run, TrailRun, VirtualRun), cross-training (CrossCountrySkiing, Elliptical, Hike, RockClimbing, Rowing, StairStepper, Swim, Walk), strength (WeightTraining, Crossfit), and yoga (Yoga). Each activity stores its `activity_type`.
3. **Completion calculation**: The "completed" count in the progress dashboard currently relies on Strava-matched sessions. If Strava is not connected, all past non-rest sessions show as "remaining." Should we add a manual "mark as done" option for users without Strava?
4. **Token storage strategy**: OAuth tokens are currently stored locally in Keychain only. The Supabase `oauth_tokens` table exists in the schema but tokens are not synced to it yet. Should we persist tokens server-side as well (for multi-device support), or is Keychain-only sufficient?

## Resolved Decisions

- **One active training plan at a time.** No need to juggle multiple plans.
- **Plan is editable after creation.** The user can change race name, race date, or plan template at any time. Changing the date shifts all sessions; switching template replaces the plan (resets swaps/skips).
- **No push notifications.** The app is pull-based — open it to see your day.
- **No offline support.** Requires connectivity for Oura/Strava sync and Supabase.
- **Unmatched Strava activities still appear.** Any Strava activity that doesn't match a planned session shows up on that day's view as an "extra" activity (cross-training, bonus runs, etc.).
- **Apple Watch companion app** is future scope — not in the initial build.
- **Coach notes stay original.** Verbatim text end-to-end; no AI summary replaces `planned_sessions.notes` or bundled template `notes`. Optional AI features must not overwrite that field.
- **API credentials documented.** Strava credentials are live in `Secrets.xcconfig`. Oura developer app setup steps documented under **Oura API** in API Integration Notes. Credentials go in `Secrets.xcconfig`.
- **Oura `daily` scope is sufficient.** Covers `daily_readiness`, `daily_sleep`, and the detailed `/usercollection/sleep` endpoint (which provides `lowest_heart_rate` and `average_hrv`). No need for `heartrate` scope (that's for raw 5-minute HR samples, which we don't use).

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
- [x] Bundled "Champion Plan for 100K" template (`champion_plan_100k.json`) — 16 weeks; coach `notes` synced from the publisher PDF. **Process:** documented under **Training Plan Selection & Import** → **Importing coach notes from a PDF** (`scripts/sync_champion_plan_from_pdf.py`, `scripts/requirements.txt`).
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
- [x] Activity import — paginated fetch from `/athlete/activities`, filters for runs, cross-training, strength, and yoga types, converts Strava API response (meters, m/s) to app model (km, min/km). Stores `activity_type` for each activity.
- [x] Auto-matching — `autoMatchActivities` matches imported Strava activities to planned sessions by date and type. `activity(for:)` and `activities(on:)` query helpers.
- [x] Plan vs. actual comparison on `SessionDetailSheet` — when a matched Strava activity exists, shows distance (actual vs planned with % delta), pace, duration, heart rate, and elevation.
- [x] Strava completion indicators on `WeekView` (checkmark + actual distance) and `PlanCalendarView` (green checkmark overlay on calendar cells).
- [x] Strava banner on `TodayView` — shows completed run details alongside today's prescription.
- [x] Settings — connect/disconnect Strava, manual sync button with loading state, athlete name display, last sync timestamp.
- [x] Supabase persistence — upserts activities on `strava_id` unique constraint; loads cached activities on app launch.

### M5 — Oura Integration ✅
- [x] `OuraService` — full OAuth2 flow via `ASWebAuthenticationSession`, token exchange, refresh, Keychain persistence.
- [x] Config wiring — `OURA_CLIENT_ID` and `OURA_CLIENT_SECRET` via `Secrets.xcconfig` → `Info.plist` → `Config.swift`.
- [x] Daily sync — fetches readiness, sleep, and heart rate data from Oura v2 API (`/usercollection/daily_readiness`, `/usercollection/daily_sleep`). Merges into unified `OuraDaily` records.
- [x] Recovery card on `TodayView` — shows readiness score, sleep score, HRV, and resting heart rate with color-coded readiness badge (green/orange/red). Crown icon (👑) on readiness and sleep scores ≥ 85.
- [x] Readiness-based swap suggestions — when readiness is low and today is a hard session, suggests swapping with nearest easy/rest day. One-tap swap with reason logged ("Low readiness (58)").
- [x] Recovery row on `SessionDetailSheet` — shows readiness, sleep, HRV, and resting HR for the session's date. Crown icon on scores ≥ 85. RHR now displayed alongside other metrics.
- [x] **Sleep periods fetch fix** — `fetchSleepPeriods` now checks HTTP status (was silently discarding the response) and uses explicit error handling instead of `try?` (was swallowing decode errors). Debug logging added for raw response and parsed values to diagnose HRV/RHR data issues.
- [x] Settings — connect/disconnect Oura, manual sync button with loading state, last sync timestamp.
- [x] Supabase persistence — upserts daily data on `(user_id, date)` unique constraint; loads cached data on app launch.

### M6 — Progress & Polish ✅
- [x] `ProgressDashboardView` — full progress tracking with three sections:
  - **Completion card**: circular progress indicators for completed/skipped/remaining percentages, session counts.
  - **Weekly mileage chart** (Swift Charts): grouped bar chart showing planned vs actual km per week across the full training block. Current week highlighted with orange rule mark. Chart legend for Planned/Actual.
  - **Week-by-week detail list**: progress bars per week showing actual/planned km and session counts.
  - **Race readiness card**: days until race, completion percentage, weeks completed, readiness level badge (On Track / Fair / Behind / Starting) with contextual message.
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

### M7 — Manual Workout Adjustments & Strength Training ✅
- [x] `SessionOverride` model and Supabase migration for `session_overrides` table.
- [x] Editable `SessionDetailSheet` — tap into any session from the Week View to edit workout type, distance, effort, and notes. Original values preserved for "reset to plan."
- [x] Override propagation option — when editing a session, the user can choose to apply the same change to the matching day across other weeks (e.g., change all Tuesdays). Default is single-session only.
- [x] Override indicator (pencil badge) on `WeekView` and `PlanCalendarView` for modified sessions.
- [x] `StrengthTemplate`, `StrengthTemplateExercise`, `StrengthSession`, `StrengthLog` models.
- [x] Supabase migration for strength tables (`strength_templates`, `strength_template_exercises`, `strength_sessions`, `strength_logs`).
- [x] Add strength exercises to the bundled training plan JSON (`champion_plan_100k.json`) — initial strength template is seeded from the plan template, not created from scratch.
- [x] `StrengthStore` — `@Observable` state container for the strength template and weekly sessions. On plan import, populate the strength template from the plan's bundled strength data. Handles template propagation to future weeks, one-off overrides, and deload week detection.
- [x] `StrengthTemplateView` — the Strength tab. Edit the weekly template (exercises grouped by day). Add/remove/reorder exercises. Inline editing for sets, reps, weight.
- [x] Template propagation logic — when the template changes, regenerate `strength_sessions` for all future weeks. Past weeks untouched.
- [x] `StrengthDayDetailView` — logging view for a day's strength work. Tap each set to log actual reps/weight. Mark exercises complete.
- [x] Dynamic load progression engine:
  - Analyze `strength_logs` to detect when user consistently hits target reps → suggest weight increase.
  - Cross-reference running load from `planned_sessions` (weekly distance, workout intensity) to scale strength volume.
  - Integrate Oura readiness trends to moderate progression suggestions.
  - Auto-insert deload weeks (every 4th week by default, configurable).
- [x] Progression suggestions UI — badges on exercises ready to progress, with accept/dismiss actions.
- [x] `ExerciseHistoryView` — per-exercise chart (weight over time, reps over time).
- [x] Strength display on `WeekView` — show strength sessions alongside running sessions per day.
- [x] Strength display on `TodayView` — show today's strength work below the running prescription.
- [x] New Strength tab added to `ContentView` tab bar.
- [x] Supabase persistence for all strength data (template, sessions, logs).

### M8 — Heat Training ✅
- [x] `HeatSession` and `HeatLog` models.
- [x] Supabase migration for heat tables (`heat_sessions`, `heat_logs`).
- [x] Add `heat_sessions` to the bundled training plan JSON template (`champion_plan_100k.json`) — prescribed heat days on Monday (day 1) and Friday (day 5).
- [x] Update `TrainingPlanTemplate` model with `HeatSessionTemplate` struct.
- [x] `HeatStore` — `@Observable` state container. Initialize from template on plan import. Log completion. Query helpers for today/week/date. Add/remove heat days with propagation across all weeks.
- [x] `HeatLogSheet` — simple logging view: session type picker, duration stepper, save.
- [x] Heat display on `TodayView` — show prescribed heat session with log button.
- [x] Heat display on `WeekView` — flame icon on days with prescribed heat, checkmark when done.
- [x] Heat indicator on `PlanCalendarView` — flame icon overlay on calendar cells.
- [x] Heat editing in Strength & Heat tab — add/remove heat days, choose session type and duration. `AddHeatDaySheet` for adding new days.
- [x] Wire `HeatStore` into `TrainingApp`, `ContentView`, `PlanSetupView`, `PlanEditView`.
- [x] Supabase persistence for all heat data (sessions, logs).

### M9 — Stretch Routines ✅
- [x] `StretchTemplate`, `StretchTemplateExercise`, `StretchSession`, `StretchLog` models — follows the same template/session/log pattern as strength training.
- [x] Supabase migration for stretch tables (`stretch_templates`, `stretch_template_exercises`, `stretch_sessions`, `stretch_logs`).
- [x] Add `stretch_exercises` to the bundled training plan JSON template (`champion_plan_100k.json`) — individual stretches on Tuesday (post-run basics), Saturday (extended post-long-run), Sunday (full mobility).
- [x] Update `TrainingPlanTemplate` model with `StretchExerciseTemplate` struct.
- [x] `StretchStore` — `@Observable` state container following `StrengthStore` pattern. Template management (add/edit/remove individual stretches), per-week session generation, completion logging, future week propagation on template changes.
- [x] `AddStretchExerciseSheet` — add individual stretches with name, hold time, sets, bilateral toggle, and PT notes.
- [x] `EditStretchExerciseSheet` — edit or remove individual stretches from the template.
- [x] `StretchDayDetailView` — logging view for a day's stretches. Tap each stretch to mark done. Progress bar with completion count.
- [x] Stretch section in Strength tab — shows individual stretches grouped by day with add/edit capability. Users can add PT-recommended stretches.
- [x] Stretch display on `TodayView` — show individual stretches with per-stretch completion checkmarks and "Log" button.
- [x] Stretch display on `WeekView` — flexibility icon with completion count badge, tap to open day detail.
- [x] Wire `StretchStore` into `TrainingApp`, `ContentView`, `PlanSetupView`, `PlanEditView`.
- [x] Supabase persistence for all stretch data (templates, exercises, sessions, logs).

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
    │   ├── SessionOverride.swift          # Manual workout adjustments
    │   ├── StravaActivity.swift
    │   ├── OuraDaily.swift
    │   ├── StrengthTemplate.swift         # Weekly strength template + exercises
    │   ├── StrengthSession.swift          # Per-week prescribed strength work
    │   ├── StrengthLog.swift              # Actual logged sets/reps/weight
    │   ├── StretchSession.swift            # Prescribed stretch/mobility sessions
    │   ├── StretchLog.swift               # Actual logged stretch sessions
    │   ├── HeatSession.swift              # Prescribed heat acclimation sessions
    │   └── HeatLog.swift                  # Actual logged heat sessions
    ├── Services/
    │   ├── SupabaseService.swift
    │   ├── AuthService.swift
    │   ├── PlanTemplateService.swift      # Load templates, generate plans
    │   ├── TrainingPlanStore.swift        # Active plan state (@Observable)
    │   ├── StrengthStore.swift            # Strength template, sessions, progression
    │   ├── ProgressionEngine.swift        # Dynamic load adjustment logic
    │   ├── StretchStore.swift              # Stretch sessions, logging
    │   ├── HeatStore.swift                # Heat sessions, logging
    │   ├── StravaService.swift            # OAuth2, activity import, auto-match
    │   ├── OuraService.swift              # OAuth2, readiness/sleep sync
    │   └── KeychainService.swift          # Secure token storage
    └── Views/
        ├── Auth/SignInView.swift
        ├── Plan/PlanSetupView.swift
        ├── Plan/PlanEditView.swift
        ├── Today/TodayView.swift          # Recovery card, swap suggestions, strength
        ├── Week/WeekView.swift            # Week summary, completion, strength
        ├── Calendar/PlanCalendarView.swift # Completion dots
        ├── Calendar/SessionDetailSheet.swift # Editable plan vs actual comparison
        ├── Stretch/StretchLogSheet.swift          # Add/edit stretch exercise sheets
        ├── Stretch/StretchDayDetailView.swift    # Log individual stretches for a day
        ├── Heat/HeatLogSheet.swift              # Log heat session duration
        ├── Strength/StrengthTemplateView.swift  # Strength tab — weekly template editor
        ├── Strength/StrengthDayDetailView.swift # Log sets/reps/weight for a day
        ├── Strength/ExerciseHistoryView.swift   # Per-exercise progression chart
        ├── Progress/ProgressDashboardView.swift # Charts, completion, readiness
        └── Settings/SettingsView.swift    # Strava/Oura connect/disconnect

docs/                                    # Static site for GitHub Pages
├── index.html                           # Landing page
├── privacy.html                         # Privacy policy
└── terms.html                           # Terms of service

supabase/
├── config.toml
└── migrations/
    ├── 20260318000000_initial_schema.sql
    ├── 20260320000000_add_strength_workout_type.sql
    ├── 20260320100000_strength_and_overrides.sql
    ├── 20260320200000_heat_training.sql
    ├── 20260325000000_stretch_sessions.sql
    └── 20260325100000_timed_exercises_and_activity_types.sql
```

## Website & Legal

The `docs/` folder contains a static website suitable for GitHub Pages (or any static host). It includes:

- **Landing page** (`index.html`) — app description and feature overview.
- **Privacy policy** (`privacy.html`) — covers data collection (Oura, Strava, training data), storage (Supabase + Keychain), third-party integrations, and user rights.
- **Terms of service** (`terms.html`) — acceptable use, health disclaimer, liability limitations.

To deploy via GitHub Pages: go to your repo's **Settings → Pages**, set Source to "Deploy from a branch", branch `main`, folder `/docs`. The site will be at `https://<username>.github.io/<repo>/`. Use these URLs when registering OAuth apps with Oura and Strava.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | ISSUES (PLAN) | 10 issues, 2 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | ISSUES (FULL) | score: 6/10 -> 7/10, 5 decisions |

- **OUTSIDE VOICE:** Claude subagent ran (eng + design). Eng: 12 findings, 1 incorrect. Design: 16 findings, 2 critical.
- **UNRESOLVED:** 4 deferred design decisions (terminal states, partial completion indicators, Strava match correction, dark mode spec).
- **VERDICT:** ENG + DESIGN REVIEWED. Fix pre-demo TODOS (12 items), then re-run eng review for CLEARED status.
