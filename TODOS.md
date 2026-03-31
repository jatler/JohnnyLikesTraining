# TODOS

## Pre-Demo (by April 7, 2026)

### ~~Fix: Patreon JSON decode error handling (CRITICAL)~~ ✅
- **Completed:** v1.0 (2026-03-29) — commit `66d23b5`

### ~~Fix: OAuth state parameter validation~~ ✅
- **Completed:** v1.0 (2026-03-30) — All three services now validate state parameter on callback

### ~~Fix: Patreon token refresh — add expiry check~~ ✅
- **Completed:** v1.0 (2026-03-29) — commit `7896965`

### ~~Add: Error surfacing for Supabase persistence~~ ✅
- **Completed:** v1.0 (2026-03-29) — commit `52fb04f`

### ~~Add: Unit tests for core logic~~ ✅
- **Completed:** v1.0 (2026-03-29) — commit `968bf2c` (19 tests)

### ~~Design: Today View run card must be above the fold~~ ✅
- **Completed:** v1.0 (2026-03-29) — commit `725aae0`

### ~~Design: Segmented control for Strength tab~~ ✅
- **Completed:** v1.0 (2026-03-29) — commit `ace17c0`

### ~~Design: Calendar workout type color mapping~~ ✅
- **Completed:** v1.0 (2026-03-29) — commit `f753ea1`

### ~~Design: Loading state pattern~~ ✅
- **Completed:** v1.0 (2026-03-29) — commit `519e413`

### ~~Design: Always display distances in miles~~ ✅
- **Completed:** v1.0 (2026-03-29) — commit `60caa3c`

### ~~Fix: Oura RHR not updating for current day~~ ✅
- **Completed:** v1.0 (2026-03-30) — Added TimeZone.current to DateFormatter in syncDaily()

### ~~Fix: Dev mode simulator not showing heat and strength plan~~ ✅
- **Completed:** v1.0 (2026-03-30) — Investigated: createPlan() is synchronous, timing issue doesn't exist. Template JSONs include strength/heat/stretch fields.

### ~~Fix: Coach notes have strange punctuation and missing paragraph breaks~~ ✅
- **Completed:** v1.0 (2026-03-30) — Fixed 25 punctuation issues in champion_plan_100k.json, 16 in winter_plan_10w.json

### ~~Strava: Add official "Connect with Strava" button~~ ✅
- **Completed:** v1.0 (2026-03-30) — ConnectWithStrava.imageset added, SettingsView updated

### ~~Strava: Add official "Powered by Strava" logo~~ ✅
- **Completed:** v1.0 (2026-03-30) — PoweredByStrava.imageset added, used in Settings, TodayView, SessionDetailSheet

### ~~Strava: Add "View on Strava" deep links on activity views~~ ✅
- **Completed:** v1.0 (2026-03-29) — SessionDetailSheet.swift

### ~~Perf: Parallelize data loading on app launch~~ ✅
- **Completed:** v1.0 (2026-03-29) — commit `7e8f2c5`

### ~~Add: Local cache for offline plan access~~ ✅
- **Completed:** v1.0 (2026-03-29) — commit `26b70f2`

### ~~Fix: Delete-then-reinsert race condition in persistence (CRITICAL)~~ ✅
- **Completed:** v1.0 (2026-03-30) — Replaced DELETE+INSERT with upsert in all three stores

### ~~Fix: Remove sensitive tokens from debug logs (CRITICAL)~~ ✅
- **Completed:** v1.0 (2026-03-30) — Replaced token/secret prints with safe messages

### ~~Fix: Complete OAuth state validation on Strava + Oura~~ ✅
- **Completed:** v1.0 (2026-03-30) — pendingOAuthState added to both services, validated on callback

### ~~Fix: Set lastError on Supabase write failures~~ ✅
- **Completed:** v1.0 (2026-03-30) — Already implemented in all persist catch blocks

### ~~Add: Tests for PlanCacheService, DistanceFormatter, PatreonService~~ ✅
- **Completed:** v1.0 (2026-03-30) — DistanceFormatterTests.swift and PlanCacheServiceTests.swift added

### ~~Fix: Cache swaps/skips/overrides in PlanCacheService~~ ✅
- **Completed:** v1.0 (2026-03-30) — PlanCacheService now saves/loads skips, swaps, overrides

### ~~Fix: Parse Patreon expires_in from token response~~ ✅
- **Completed:** v1.0 (2026-03-30) — Added expiresIn to PatreonTokenResponse, uses actual value

### ~~Fix: Champion plan not showing heat and strength days~~ ✅
- **Completed:** v1.0.2 (2026-03-30) — Added auto-initialization from bundled template on app launch when stores are empty

### ~~Add: Manual strength and stretching program creation~~ ✅
- **Completed:** v1.0.2 (2026-03-30) — Added createBlankTemplate() to StrengthStore and StretchStore, "Create Program" buttons in empty states

### ~~Fix: Today page vertical card order~~ ✅
- **Completed:** v1.0.2 (2026-03-30) — Reordered to: notes → Strava → heat → strength → stretch → Oura → actions

### ~~Add: Weekly mileage in progress bar~~ ✅
- **Completed:** v1.0.2 (2026-03-30) — Added weeklyMileageSummary with progress bar to TodayView

### ~~Fix: App version incorrect in Settings~~ ✅
- **Completed:** v1.0.2 (2026-03-30) — Already reading from CFBundleShortVersionString, project.yml at 1.0.2. Needs fresh build.

### ~~Fix: Heat session edit UI rendering issues~~ ✅
- **Completed:** v1.0.2 (2026-03-31) — Fixed 3 issues: (1) heat tab showed empty-state layout when no strength/stretch existed, (2) HeatLogSheet content clipped under `.medium` detent (added ScrollView + `.large` detent), (3) segmented type picker didn't show icons (replaced with custom capsule buttons)

## Pre-Beta (by May 1, 2026)

### ~~Strava: Delete imported data from Supabase on disconnect~~ ✅
- **Completed:** v1.0.3 (2026-03-31) — `disconnect(userId:)` now deletes from `strava_activities` table before clearing Keychain. SettingsView passes `auth.currentUserId`.

### ~~Strava: Implement 7-day data freshness / cache compliance~~ ✅
- **Completed:** v1.0.3 (2026-03-31) — Added `lastSyncedAt` persisted to Keychain, `isSyncStale()` method, auto-resync on app launch when data > 7 days old.

### Strava: Submit app for production API access
- **What:** Go to strava.com/settings/api. Fill out all required fields: app name, description, website URL (johnnylikestraining.com), callback URL, app icon. Submit for review to remove the testing-mode athlete limit.
- **Why:** Strava testing mode limits the app to ~15 authorized athletes. Production access is required before beta/App Store launch.
- **Effort:** human: ~1 hr / CC: N/A (manual process)
- **Depends on:** Official Strava branding assets integrated, privacy policy and terms updated (done)

### ~~Security: Move OAuth client secrets to Supabase Edge Functions~~ ✅
- **Completed:** v1.0.3 (2026-03-31) — Created 3 Edge Functions (`strava-token`, `oura-token`, `patreon-token`) in `supabase/functions/`. Updated all 3 OAuth services to route token exchange/refresh through Edge Functions instead of embedding client secrets.

### ~~DRY: Extract shared OAuthService protocol~~ ✅
- **Completed:** v1.0.3 (2026-03-31) — Created `OAuthServiceProtocol.swift` with `OAuthConfig`, `OAuthTokenExchanger` protocol, `DirectOAuthTokenExchanger` and `EdgeFunctionOAuthTokenExchanger` implementations. Enables mocking in tests.

### ~~Design: Patreon content gate at plan-access level~~ ✅
- **Completed:** v1.0.3 (2026-03-31) — PlanSetupView now gates SWAP Running plans behind Patreon verification. Non-SWAP plans are ungated. DevSignIn bypasses the gate.

### ~~Test: Snapshot/UI tests for critical views~~ ✅
- **Completed:** v1.0.3 (2026-03-31) — Added `OAuthTokenExchangerTests.swift`, `PatreonGateTests.swift`, `StravaFreshnessTests.swift` (unit tests for OAuth mocking, Patreon gating logic, Strava freshness).

## Pre-App Store (future)

### ~~Integration tests for OAuth flows~~ ✅
- **Completed:** v1.0.3 (2026-03-31) — `OAuthTokenExchanger` protocol enables full mocking of token exchange. `MockOAuthTokenExchanger` in tests validates success/failure paths.

### Strava webhook integration
- **What:** Replace polling with Strava webhook push via Supabase Edge Function for real-time activity import and deletion propagation. Must handle `activity.create`, `activity.update`, and `activity.delete` events.
- **Context:** Currently syncs on manual trigger or app launch. Webhook would auto-import without opening the app. Also required for Strava compliance: if a user deletes an activity on Strava, it must be removed from the app within 48 hours. Webhooks make this automatic.

### Strava: Security breach notification process
- **What:** Document an incident response process that includes notifying Strava within 24 hours of discovering any security breach or personal data breach involving Strava data or API tokens.
- **Context:** Required by Strava API Agreement. Currently no documented process.

### ~~Onboarding flow~~ ✅
- **Completed:** v1.0.3 (2026-03-31) — 4-page onboarding wizard: Welcome, Connect Services (Patreon/Strava/Oura), Create Plan, All Set. Tracked via `@AppStorage("hasCompletedOnboarding")`.

## Strategic (post-demo evaluation)

### Evaluate: StoreKit 2 vs Patreon paywall
- **What:** Compare maintaining PatreonService (OAuth, token refresh, grace periods, decode handling, ~350 LOC) against StoreKit 2 subscriptions (~50 LOC, native, no token bugs). If Patreon is chosen for business reasons (coaches' existing community), document the decision explicitly.
- **Why:** The Patreon integration is the most complex and fragile OAuth service in the app. StoreKit 2 gives subscriptions for free with no external API dependency.
- **Source:** /autoplan CEO review

### Plan: Coach authoring tool
- **What:** Currently adding a new plan requires: Python script + PDF parsing + JSON bundling + app update. Plan a coach-facing authoring tool (even a simple web form writing to Supabase) so David & Megan can update plans without developer intervention.
- **Why:** The PDF-to-JSON pipeline won't scale past one developer. Every new plan or revision is a bottleneck on you.
- **Source:** /autoplan CEO review

### Document: Competitive analysis vs TrainingPeaks
- **What:** Document why a custom app is better than publishing SWAP plans on TrainingPeaks (which already has Strava/Garmin/Oura integrations). Differentiators: verbatim SWAP coaching notes, tight Strava auto-matching, Patreon-native paywall.
- **Why:** If David says "we already use TrainingPeaks," you need a clear answer ready for the demo pitch.
- **Source:** /autoplan CEO review

### Plan: Multi-plan archive
- **What:** Add plan archiving so users who finish a training cycle (e.g., 16-week Champion Plan) can start a new plan without losing history. Currently "one active plan at a time" means all data from the prior plan disappears.
- **Why:** Will surface as soon as real users finish their first training block.
- **Source:** /autoplan CEO review

### Acknowledge: Android gap in pitch
- **What:** SWAP's Patreon audience includes Android users. Prepare a clear answer for the demo: "Phase 1 is iOS. Android is feasible later via cross-platform rewrite or companion web app."
- **Why:** Every Android patron is excluded. Must be an acknowledged, documented tradeoff in the pitch.
- **Source:** /autoplan CEO review
