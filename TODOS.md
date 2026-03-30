# TODOS

## Pre-Demo (by April 7, 2026)

### Fix: Patreon JSON decode error handling (CRITICAL)
- **What:** Replace `try?` with `try` in `PatreonService.processIdentityResponse()` (line 151). Propagate decode errors to UI. Also: when decode fails, do NOT proceed to the grace period/revocation logic. Currently a decode failure actively REVOKES patron access and starts the 7-day grace countdown. Return early on error instead.
- **Why:** A single malformed API response or Patreon API change will immediately revoke every patron's access and start their grace period timer. This is not silent failure, it's active harm.
- **Effort:** human: ~30 min / CC: ~5 min
- **Depends on:** Nothing

### Fix: OAuth state parameter validation
- **What:** Store generated `state` UUID in PatreonService, validate it on OAuth callback. 3-line fix.
- **Why:** OAuth2 spec requires CSRF validation via state parameter. Currently generated but never checked.
- **Effort:** human: ~15 min / CC: ~2 min
- **Depends on:** Nothing

### Fix: Patreon token refresh — add expiry check
- **What:** Add `patreonExpiresAt` to KeychainService, set a TTL on token save, check before refreshing.
- **Why:** `refreshTokenIfNeeded()` currently always refreshes (no expiry check). Wastes API calls, risks rate limiting during demo.
- **Effort:** human: ~30 min / CC: ~5 min
- **Depends on:** Nothing

### Add: Error surfacing for Supabase persistence
- **What:** Add `lastError` property to all Store classes. Show a toast/banner in views when persistence fails.
- **Why:** Currently all Supabase errors are `print()` only. Data silently drops on network failure. User thinks data saved, gone on reload.
- **Effort:** human: ~4 hrs / CC: ~15 min
- **Depends on:** Nothing

### Add: Unit tests for core logic
- **What:** Add XCTest target. Write unit tests for PatreonService verification logic, PlanTemplateService date math, and ProgressionEngine.
- **Why:** Zero test coverage. These are pure logic functions that are critical to correctness and don't need mocking.
- **Effort:** human: ~2 days / CC: ~15 min
- **Depends on:** Patreon JSON decode fix (so tests can validate error propagation)

### Design: Today View run card must be above the fold
- **What:** Reorder TodayView content: (1) run card (always above fold, visible without scrolling), (2) recovery inline, (3) conditional banners (podcast, swap suggestion), (4) strength/stretch/heat sections.
- **Why:** Runner opens app at 5:45am. Workout prescription must be visible in under 1 second. Recovery cards and banners currently can push it below the fold.
- **Effort:** human: ~30 min / CC: ~5 min
- **Depends on:** Nothing

### Design: Segmented control for Strength tab
- **What:** Replace single long scroll in Strength tab with a top-level segmented control (Strength | Stretch | Heat). Each segment gets its own scrollable view.
- **Why:** Three unrelated training modalities crammed into one scroll. Users hunting for post-run stretches have to scroll past all strength exercises.
- **Effort:** human: ~2 hrs / CC: ~10 min
- **Depends on:** Nothing

### Design: Calendar workout type color mapping
- **What:** Define opacity-based color differentiation for 8 workout types on calendar: swapAccent at 0.15 (easy/recovery), 0.4 (tempo), 0.7 (intervals), 1.0 (long_run/race). Rest = no color. Cross_train = outline only.
- **Why:** Calendar is useless for scanning if all workout types look the same.
- **Effort:** human: ~1 hr / CC: ~5 min
- **Depends on:** Nothing

### Design: Loading state pattern
- **What:** Add loading state pattern to DESIGN.md: skeleton cards for first launch (no cache), cached data + subtle refresh indicator for subsequent launches.
- **Why:** Users see nothing during 1-2 second cold start. Loading states are the first impression every morning.
- **Effort:** human: ~1 hr / CC: ~5 min
- **Depends on:** Offline cache TODO

### Design: Always display distances in miles
- **What:** Add rule to DESIGN.md: all distances displayed in miles. Data stays in km internally, conversion at display layer. Single utility function.
- **Why:** SWAP Running is US-based. US runners think in miles.
- **Effort:** human: ~2 hrs / CC: ~10 min
- **Depends on:** Nothing

### Perf: Parallelize data loading on app launch
- **What:** In ContentView.swift MainTabView.task, load strength/heat/stretch/strava/oura concurrently with `async let` after plan loads.
- **Why:** Currently 6 sequential network requests on cold start. ~1.2s of unnecessary loading time.
- **Effort:** human: ~30 min / CC: ~5 min
- **Depends on:** Nothing

### Add: Local cache for offline plan access
- **What:** Cache training plan + sessions as JSON on disk after loading from Supabase. On launch, show cached data immediately, sync in background.
- **Why:** Trail runners have no cell service at the trailhead. Currently the app requires connectivity to show today's workout. Plan data is static after creation.
- **Effort:** human: ~4 hrs / CC: ~15 min
- **Depends on:** Nothing
- **Source:** Outside voice review

## Pre-Beta (by May 1, 2026)

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
- **What:** Replace polling with Strava webhook push via Supabase Edge Function for real-time activity import.
- **Context:** Currently syncs on manual trigger or app launch. Webhook would auto-import without opening the app.

### Onboarding flow
- **What:** Guided first-launch experience: sign in → connect services → create plan.
- **Context:** Currently users land on an empty Today tab and have to figure out plan creation themselves.
