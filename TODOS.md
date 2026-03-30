# TODOS

## Pre-Demo (by April 7, 2026)

### ~~Fix: Patreon JSON decode error handling (CRITICAL)~~ ✅
- **Completed:** v1.0 (2026-03-29) — commit `66d23b5`

### Fix: OAuth state parameter validation
- **What:** Store generated `state` UUID in PatreonService, StravaService, and OuraService. Validate it on OAuth callback. 3-line fix per service.
- **Why:** OAuth2 spec requires CSRF validation via state parameter. Currently generated but never checked. Also required by Strava API Agreement.
- **Effort:** human: ~15 min / CC: ~2 min
- **Depends on:** Nothing

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

### Strava: Add official "Connect with Strava" button
- **What:** Download official "Connect with Strava" button asset from Strava brand guidelines (orange or white, 48px @1x / 96px @2x). Replace the plain text "Connect Strava" button in SettingsView with the official asset. Add to Assets.xcassets.
- **Why:** Strava API Agreement and Brand Guidelines require using the official button for the OAuth connect flow. Current plain text button is non-compliant.
- **Effort:** human: ~30 min / CC: ~5 min
- **Depends on:** Nothing

### Strava: Add official "Powered by Strava" logo
- **What:** Download official "Powered by Strava" logo from Strava brand guidelines (orange, white, or black). Replace the text-only "Powered by Strava" link in the Strava section footer with the official logo asset. Add to Assets.xcassets.
- **Why:** Strava requires official logo assets, not just text. Text attribution is a temporary placeholder.
- **Effort:** human: ~30 min / CC: ~5 min
- **Depends on:** Nothing

### ~~Strava: Add "View on Strava" deep links on activity views~~ ✅
- **Completed:** v1.0 (2026-03-29) — SessionDetailSheet.swift

### ~~Perf: Parallelize data loading on app launch~~ ✅
- **Completed:** v1.0 (2026-03-29) — commit `7e8f2c5`

### ~~Add: Local cache for offline plan access~~ ✅
- **Completed:** v1.0 (2026-03-29) — commit `26b70f2`

### Fix: Delete-then-reinsert race condition in persistence (CRITICAL)
- **What:** `StrengthStore.persistAllSessions()`, `StretchStore.persistAllSessions()`, and `HeatStore.persistAllSessions()` do a `DELETE WHERE plan_id = X` then `INSERT`. If the app crashes between delete and insert, all session data is permanently lost. Replace with upsert using conflict key, or wrap in a Supabase RPC transaction.
- **Why:** Data loss on crash/network interruption. Any rapid template edit could interleave and corrupt state.
- **Effort:** human: ~2 hrs / CC: ~10 min
- **Depends on:** Nothing
- **Source:** /autoplan eng review

### Fix: Remove sensitive tokens from debug logs (CRITICAL)
- **What:** Remove `print("Strava refresh token: ...")` at StravaService.swift:157 and `print("Oura client_secret: ...")` at OuraService.swift:70. These leak credentials to console logs.
- **Why:** Refresh tokens and client secrets should never be logged, even in debug builds. Console logs can be captured by crash reporters or shared debug sessions.
- **Effort:** human: ~5 min / CC: ~2 min
- **Depends on:** Nothing
- **Source:** /autoplan eng review

### Fix: Complete OAuth state validation on Strava + Oura
- **What:** Strava has no state parameter at all. Oura generates a state UUID (line 33) but never validates it on callback. Add `pendingOAuthState` property, pass in authorize URL, validate on callback. Same pattern already implemented in PatreonService.
- **Why:** OAuth2 spec requires CSRF validation. Strava API Agreement compliance.
- **Effort:** human: ~15 min / CC: ~2 min
- **Depends on:** Nothing
- **Source:** /autoplan eng review (extends existing TODOS item)

### Fix: Set lastError on Supabase write failures
- **What:** All store `persist*` methods catch write errors with `print()` only. Add `lastError = error.localizedDescription` in every write catch block so the UI shows a toast/banner.
- **Why:** Currently users think data is saved when writes silently fail. The `lastError` pattern exists for reads but not writes.
- **Effort:** human: ~1 hr / CC: ~5 min
- **Depends on:** Nothing
- **Source:** /autoplan eng review

### Add: Tests for PlanCacheService, DistanceFormatter, PatreonService
- **What:** Add unit tests for: (1) PlanCacheService save/load roundtrip + corrupt cache returns nil, (2) DistanceFormatter km-to-miles conversion accuracy, (3) PatreonService.processIdentityResponse() with 4 scenarios: active patron, lapsed patron, decode error (no revocation), no membership data.
- **Why:** 15 untested paths identified. The Patreon decode bug (already fixed) is the exact scenario that needs a regression test.
- **Effort:** human: ~2 hrs / CC: ~10 min
- **Depends on:** Nothing
- **Source:** /autoplan eng review

### Fix: Cache swaps/skips/overrides in PlanCacheService
- **What:** PlanCacheService saves only plan + sessions. Add caching for skips, swaps, and overrides. Without them, offline mode shows stale swap state (a swapped session shows on the wrong day).
- **Why:** Inconsistent offline experience. User may re-skip something, creating duplicate records on reconnect.
- **Effort:** human: ~30 min / CC: ~5 min
- **Depends on:** Nothing
- **Source:** /autoplan eng review

### Fix: Parse Patreon expires_in from token response
- **What:** PatreonService.saveTokens() hardcodes token expiry to 24 hours (line 263). Add `expiresIn: Int?` to `PatreonTokenResponse` and use it: `Date() + TimeInterval(expiresIn ?? 86400)`.
- **Why:** If Patreon's actual token TTL differs from 24h, the app either uses expired tokens or refreshes unnecessarily.
- **Effort:** human: ~15 min / CC: ~2 min
- **Depends on:** Nothing
- **Source:** /autoplan eng review

## Pre-Beta (by May 1, 2026)

### Strava: Delete imported data from Supabase on disconnect
- **What:** In `StravaService.disconnect()`, after removing Keychain tokens, also delete all rows from `strava_activities` where `user_id` matches the current user. The privacy policy now promises this behavior.
- **Why:** Strava API Agreement requires deleting all user data when a user revokes access. Currently disconnect only removes local tokens; imported activities persist in Supabase.
- **Effort:** human: ~30 min / CC: ~5 min
- **Depends on:** Nothing

### Strava: Implement 7-day data freshness / cache compliance
- **What:** Add a `last_synced_at` timestamp to Strava activity records. On each sync, refresh data from Strava API. Add a background task or app-launch check that flags stale data (>7 days since last sync) and triggers a re-sync. Alternatively, implement Strava webhooks (see Pre-App Store) for real-time freshness.
- **Why:** Strava API Agreement states cached data must not remain longer than 7 days without refresh. Currently data is stored indefinitely with no freshness guarantee.
- **Effort:** human: ~4 hrs / CC: ~15 min
- **Depends on:** Nothing

### Strava: Submit app for production API access
- **What:** Go to strava.com/settings/api. Fill out all required fields: app name, description, website URL (johnnylikestraining.com), callback URL, app icon. Submit for review to remove the testing-mode athlete limit.
- **Why:** Strava testing mode limits the app to ~15 authorized athletes. Production access is required before beta/App Store launch.
- **Effort:** human: ~1 hr / CC: N/A (manual process)
- **Depends on:** Official Strava branding assets integrated, privacy policy and terms updated (done)

### Security: Move OAuth client secrets to Supabase Edge Functions
- **What:** Create Edge Functions for Patreon/Strava/Oura token exchange. App sends auth code to Edge Function, which holds the secret and exchanges with the provider. Remove client secrets from Secrets.xcconfig/Info.plist.
- **Why:** Client secrets are currently bundled in the IPA. Anyone with the binary can extract them.
- **Effort:** human: ~1 day / CC: ~20 min
- **Depends on:** Supabase Edge Functions (already configured in repo)

### DRY: Extract shared OAuthService protocol
- **What:** Create a shared OAuth2 protocol/base class for the common flow across Strava, Oura, and Patreon services. Each service provides config (URLs, scopes, keychain keys), shared code handles ASWebAuthSession, token exchange, refresh, and keychain storage.
- **Why:** ~100 lines of near-identical OAuth boilerplate repeated 3x. Bug fixes only apply to one service at a time.
- **Effort:** human: ~1 day / CC: ~20 min
- **Depends on:** Edge Function migration (bundle together)

### Design: Patreon content gate at plan-access level
- **What:** Gate SWAP training plan content (not the app itself) behind Patreon verification. Trigger on plan creation and plan loading. Non-SWAP content (if any future plans) remains ungated.
- **Why:** The app should be open but SWAP coaching content requires patron status. Supports future free tiers or non-SWAP plans.
- **Effort:** human: ~4 hrs / CC: ~15 min
- **Depends on:** Patreon service arch fixes (JSON decode, state validation, token refresh)

### Test: Snapshot/UI tests for critical views
- **What:** Add snapshot tests for PatreonGateView (4 states), TodayView (with/without data), WeekView. Use ViewInspector or similar.
- **Why:** Catches UI regressions, dark mode issues, accessibility problems before beta users see them.
- **Effort:** human: ~1 day / CC: ~15 min
- **Depends on:** XCTest target being added (pre-demo unit tests)

## Pre-App Store (future)

### Integration tests for OAuth flows
- **What:** Protocol-based API client abstraction to enable mocking. Integration tests for full OAuth flows (authorize → token exchange → verify/sync).
- **Depends on:** OAuthService protocol extraction

### Strava webhook integration
- **What:** Replace polling with Strava webhook push via Supabase Edge Function for real-time activity import and deletion propagation. Must handle `activity.create`, `activity.update`, and `activity.delete` events.
- **Context:** Currently syncs on manual trigger or app launch. Webhook would auto-import without opening the app. Also required for Strava compliance: if a user deletes an activity on Strava, it must be removed from the app within 48 hours. Webhooks make this automatic.

### Strava: Security breach notification process
- **What:** Document an incident response process that includes notifying Strava within 24 hours of discovering any security breach or personal data breach involving Strava data or API tokens.
- **Context:** Required by Strava API Agreement. Currently no documented process.

### Onboarding flow
- **What:** Guided first-launch experience: sign in → connect services → create plan.
- **Context:** Currently users land on an empty Today tab and have to figure out plan creation themselves.

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
