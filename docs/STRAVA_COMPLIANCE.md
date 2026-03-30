# Strava API Compliance Checklist

Status as of March 29, 2026. Based on the [Strava API Agreement](https://www.strava.com/legal/api) (Oct 9, 2025) and [Brand Guidelines](https://developers.strava.com/guidelines/) (Sep 29, 2025).

## Documentation (DONE)

- [x] Privacy policy exists and is publicly accessible
- [x] Privacy policy explains what Strava data is collected and how
- [x] Privacy policy explains how users can withdraw consent
- [x] Privacy policy explains how users can request data deletion
- [x] Privacy policy references Strava Privacy Policy
- [x] Privacy policy notes that Strava may monitor API usage
- [x] Privacy policy includes GDPR/UK GDPR rights language
- [x] Terms of service exist and are publicly accessible
- [x] Terms of service include third-party warranty disclaimers (merchantability, fitness, non-infringement)
- [x] Terms of service exclude third-party providers from consequential/special/punitive/indirect damages
- [x] Terms of service reference Strava API Agreement and Terms of Service
- [x] Terms of service prohibit redistribution of Strava data
- [x] Support contact email accessible from within the app
- [x] Links to privacy policy and terms of service accessible from within the app

## Branding & Attribution

- [x] "Powered by Strava" text attribution in Settings (footer of Strava section)
- [ ] Replace text with official "Powered by Strava" logo asset (orange or white, from Strava brand guidelines)
- [ ] Use official "Connect with Strava" button for OAuth (orange or white, 48px @1x / 96px @2x)
- [ ] "View on Strava" deep links on activity detail views (link to `https://www.strava.com/activities/{id}`)
- [ ] Strava logo/name must not be more prominent than app name/logo
- [ ] Never use Strava logo as app icon or part of app icon

## Data Handling

- [ ] Strava data cache must not exceed 7 days without refresh (currently stored indefinitely in Supabase)
- [ ] Disconnecting Strava must delete all imported Strava data from Supabase (currently only removes tokens)
- [ ] If a user deletes an activity on Strava, remove it from the app within 48 hours (requires webhook or frequent sync)
- [ ] If a user revokes access from Strava settings, delete all their Strava data
- [x] Only display a user's own Strava data to that user (enforced by Supabase RLS)
- [x] Data transmitted over HTTPS only
- [x] OAuth tokens stored securely in iOS Keychain
- [ ] No Strava data used for AI/ML training (compliant — but add explicit code comment)
- [ ] No Strava data sold or shared with third parties (compliant — documented in privacy policy)

## OAuth & Authentication

- [x] Standard OAuth2 authorization code flow
- [x] Requesting only necessary scope (`activity:read_all`)
- [ ] Validate OAuth state parameter to prevent CSRF (noted in TODOS.md)
- [x] Token refresh with proper expiry checking
- [x] One API token per application
- [ ] Report unauthorized API token access within 24 hours (add to incident response process)

## Security

- [x] All API communication over HTTPS
- [x] OAuth tokens in iOS Keychain (encrypted at rest)
- [x] Row-level security on all database tables
- [ ] Move client secrets to server-side (currently bundled in IPA — noted in TODOS.md as pre-beta)
- [ ] Security breach notification process to Strava within 24 hours

## App Store Submission

- [ ] Strava API app submitted for production access (currently in testing mode, limited users)
- [ ] All required fields filled on strava.com/settings/api
- [ ] App description, website, callback URL, and icon configured
- [ ] Strava brand assets downloaded and integrated (logos, buttons)

## Priority Order for Remaining Items

### Before Demo (April 7)
1. Add official "Connect with Strava" button asset
2. Add "Powered by Strava" logo asset (replace text)
3. Add "View on Strava" links on activity views
4. Validate OAuth state parameter

### Before Beta (May 1)
5. Delete Strava data from Supabase on disconnect
6. Implement 7-day cache refresh / Strava webhook for data freshness
7. Move client secrets to Supabase Edge Functions
8. Submit Strava app for production access

### Before App Store
9. Implement Strava webhook for real-time activity deletion propagation
10. Document incident response process (24-hour breach notification)
