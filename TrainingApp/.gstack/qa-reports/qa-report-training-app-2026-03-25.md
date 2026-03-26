# QA Report — SWAP Training App (SWAP branch)
**Date:** 2026-03-25
**Scope:** Full source code review of all 13 files changed in the SWAP branch vs main
**Mode:** Diff-aware (native iOS SwiftUI — browser testing not applicable)
**Branch:** SWAP
**Duration:** ~30 min

---

## Summary

| Metric | Value |
|--------|-------|
| Issues found | 3 |
| Fixed (verified) | 3 |
| Deferred | 0 |
| Health score (before) | 60/100 |
| Health score (after) | 90/100 |

---

## Issues

### ISSUE-001 — PatreonService not injected in app environment
**Severity:** Critical  
**Category:** Functional  
**Status:** ✅ verified (commit `d6a1c51`)  
**Files changed:** `Sources/App/TrainingApp.swift`

**Description:** `PatreonService` was completely absent from `TrainingApp.swift`. Any navigation to `SettingsView` or presentation of `PatreonGateView` would crash immediately with a SwiftUI fatal `@Environment(PatreonService.self)` resolution error.

**Fix:** Added `@State private var patreonService = PatreonService()` and `.environment(patreonService)` to `TrainingApp.swift`.

---

### ISSUE-002 — isPatron not persisted to Keychain (cold-launch paywall flash)
**Severity:** High  
**Category:** UX / Persistence  
**Status:** ✅ verified (commit `46802d3`)  
**Files changed:** `Sources/Services/KeychainService.swift`, `Sources/Services/PatreonService.swift`

**Description:** `PatreonService.isPatron` was an in-memory `Bool` never written to Keychain. On every cold launch it started `false`; verified patrons would see the paywall until async `verifyMembership()` completed (~1-2 sec). `isConnected` was correctly persisted, but `isPatron` was not, so patrons with valid Keychain tokens would always get the gate flash.

**Fix:**
- Added `case patreonIsPatron = "patreon_is_patron"` to `KeychainService.Key`
- Added `delete(.patreonIsPatron)` to `deleteAll(for: .patreon)`
- Restored `isPatron` from Keychain in `PatreonService.init()`
- Saved `"true"/"false"` to Keychain in `processIdentityResponse()`

---

### ISSUE-003 — PatreonGateView shows wrong state if patron already verified
**Severity:** Medium  
**Category:** UI state machine  
**Status:** ✅ verified (commit `52c23c4`)  
**Files changed:** `Sources/Views/Paywall/PatreonGateView.swift`

**Description:** If `PatreonGateView` was somehow presented while `isConnected == true && isPatron == true` (possible after ISSUE-002 fix restores patron state on cold launch), the `viewState` computed property had no branch for this case and fell through to `.notConnected`, showing the "Connect Patreon" UI to an active patron. The existing `onChange(of: patreon.isPatron)` only fires on value transitions, so it would never trigger if `isPatron` was already `true` when the sheet appeared.

**Fix:** Added `.onAppear` guard: if `patreon.isPatron` is already `true` when the sheet appears, immediately call `onPatronVerified?()` and `dismiss()`.

---

## Not in scope (manual action required)

- **`Config.swift` is gitignored** — user must manually add `PATREON_CLIENT_ID`, `PATREON_CLIENT_SECRET`, `PATREON_SWAP_CAMPAIGN_ID` to `Secrets.xcconfig` before Patreon OAuth will function.

---

## PR Summary

> QA found 3 issues (1 critical, 1 high, 1 medium), fixed all 3. Health score 60 → 90.
