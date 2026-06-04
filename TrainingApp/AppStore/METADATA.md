# App Store Connect — Submission Sheet (v1.2.0, build 17)

Copy each field straight into App Store Connect. Character limits noted.

---

## App Information

| Field | Value |
|---|---|
| **App Name** (30 char) | `SWAP Training` |
| **Subtitle** (30 char) | `Ultrarunning coaching plans` |
| **Primary Category** | Health & Fitness |
| **Secondary Category** | Sports |
| **Bundle ID** | `com.jatler.Training` |
| **SKU** | `swap-training-ios` |
| **Content Rights** | I do not own/have not licensed third-party content (Apple checkbox; the Roche coaching content is reproduced with arrangement — check this only if your agreement covers it; otherwise check "contains third-party content" and describe the SWAP Running partnership) |

---

## Pricing & Availability

| Field | Value |
|---|---|
| **Price** | Free |
| **Availability** | All countries/regions (or narrow to US/CA/UK/AU/NZ initially) |

---

## Version Information (this submission)

### Promotional Text (170 char, can update without resubmit)
```
Mid-plan, peak weeks, taper — see every workout your coach prescribed, alongside what you actually ran on Strava and how recovered you are per Oura.
```
*(167 chars)*

### Description (4000 char)
```
SWAP Training brings David and Megan Roche's coaching plans to your phone — week by week, day by day, with every coaching note intact.

Pick a plan. Set your race date. Open the app each morning to see exactly what to run, why, and how it fits the bigger arc of your build.

THE PLANS
• The Champion Plan for 100K to 100 Miles (16 weeks)
• SWAP 6-Week and 12-Week Base Building
• Full SWAP catalog (marathon through 200 mile) for SWAP Patreon members
• Every plan ships with the full, unedited coach notes — not summaries

STRAVA INTEGRATION
• Activities import automatically once you connect
• Auto-matched to the prescribed workout for each day
• See planned vs. actual distance, pace, time, and elevation
• Per-week and per-block totals you can scroll through at a glance

OURA RING (OPTIONAL)
• Readiness, sleep, HRV, and resting HR shown next to today's workout
• Know when to push and when to dial back — without leaving the app

YOUR PLAN, ADAPTIVE
• Swap, skip, or rewrite any workout when life happens
• Strength and heat-training sessions, prescribed alongside running
• Stretching templates with per-exercise tracking
• Coach notes always preserved — overrides never overwrite the source

DESIGNED FOR TRAINING, NOT DASHBOARDS
• Calm, focused interface — feels like a training journal, not a SaaS app
• Works offline once your plan loads
• Sign in with Apple, your data stays linked to you

For ultrarunners and trail runners on a structured build. Made by an athlete, for athletes.

Plan content © David Roche and Megan Roche, MD PhD. SWAP Running. Some Work, All Play.
Powered by Strava.
```

### Keywords (100 char, comma-separated, no spaces after commas)
```
ultrarunning,trail,running,coach,strava,oura,marathon,100k,training plan,swap,roche,recovery
```
*(100 chars — adjust if you want different keywords)*

### What's New in This Version (4000 char)
```
v1.2.0
• Two new 18-week marathon plans — Pete Pfitzinger's Advanced Marathoning 55mi/wk and 70mi/wk schedules, transcribed from the 3rd-edition book
• Full plan catalog now visible up front — no gating
• Cleaner Settings — Patreon section removed
• Build polish and stability
```

### Support URL
```
https://johnnylikestraining.com
```
*(or wherever support routes to — update if you have a dedicated /support page)*

### Marketing URL (optional)
```
https://johnnylikestraining.com
```

### Privacy Policy URL (required)
```
https://johnnylikestraining.com/privacy
```

### Copyright
```
© 2026 Johnny Atler. Plan content © David & Megan Roche / SWAP Running.
```

---

## Screenshots

Located in `TrainingApp/AppStore/Screenshots/`:

| Size | Device | Files |
|---|---|---|
| 6.9" iPhone (1320×2868) | iPhone 17 Pro Max | `iphone-6.9/01-week.png`, `02-progress.png`, `03-strength.png`, `04-settings.png` |
| 13" iPad (2064×2752) | iPad Pro 13" M5 | `ipad-13/01-week.png`, `02-progress.png`, `03-strength.png`, `04-settings.png` |

Suggested caption order:
1. Week — daily prescriptions with Strava-matched completion
2. Progress — your full build, plan vs. actual, weeks to race
3. Strength — coach-prescribed strength, heat, stretching alongside running
4. Settings — connect Strava and Oura, manage your plan

---

## App Privacy (questionnaire answer sheet)

**Does this app collect data?** Yes.

| Data type | Linked to user | Used for tracking | Purposes |
|---|---|---|---|
| Email address | Yes | No | App Functionality (Sign in with Apple) |
| Health & Fitness — Fitness | Yes | No | App Functionality |
| Health & Fitness — Health | Yes | No | App Functionality (Oura recovery data) |
| User Content — Other | Yes | No | App Functionality (workout notes, journal entries) |
| Identifiers — User ID | Yes | No | App Functionality, Authentication |

Data is stored in Supabase (Postgres + Auth). Tokens for Strava/Oura/Patreon are stored in iOS Keychain on-device only. No third-party SDKs collect data. No tracking. No data brokers. No analytics.

---

## App Review Information

### Sign-In Required
**Yes.** Use a demo account.

### Demo Account
Reviewers must sign in. Two options:

**Option A (recommended): Provide reviewer credentials**
Create a dedicated Apple ID for App Review, sign in once on a device to seed Supabase, then provide:
- Username: `<reviewer-apple-id@example.com>`
- Password: `<password>`
- Notes: "Sign in with Apple. Plan is pre-loaded. Strava connection is optional and won't be tested."

**Option B: Re-enable the dev-bypass for the Release submission**
In `Secrets.xcconfig`, set `DEV_SIGNIN_ALLOWED = YES`, rebuild and re-archive, then in Review Notes tell reviewers to tap "Skip Sign-In (Dev)" on the sign-in screen. (Disables for next submission.)

### Contact Information
| Field | Value |
|---|---|
| First Name | Johnny |
| Last Name | Atler |
| Phone | `<your phone>` |
| Email | `atler.j@gmail.com` |

### Notes for Review
```
JohnnyLikesTraining reproduces David & Megan Roche's published SWAP Running coaching plans (with their cooperation) and Pete Pfitzinger & Scott Douglas's Advanced Marathoning 18-week schedules. All bundled plans are visible in the picker — no in-app purchase, no membership gate.

Strava integration is optional. The app functions fully without it. To test: tap Settings → Connect Strava and authenticate with any Strava account. Activities sync automatically and match to planned workouts.

Oura integration is optional. The app functions fully without it.

Note: This build's screenshots were generated with synthesized demo workout history. A fresh account starts with an empty Progress tab until Strava is connected and activities sync.
```

---

## Export Compliance
Already declared in Info.plist via `ITSAppUsesNonExemptEncryption = false`. Apple should auto-skip the export compliance questionnaire.

---

## Pre-Submission Checklist

Before clicking "Submit for Review":

- [ ] Branch `simplify` merged to `main`
- [ ] Archive uploaded via Xcode Organizer (Window → Organizer → Distribute App → App Store Connect)
- [ ] Build 17 selected on App Store Connect's Build picker
- [ ] All 4 iPhone + 4 iPad screenshots uploaded (drag from `AppStore/Screenshots/`)
- [ ] App Privacy questionnaire answered (see above)
- [ ] Demo account credentials added to App Review Information
- [ ] Privacy Policy URL reachable and matches what's in the app
- [ ] Age Rating questionnaire completed (likely 4+, no objectionable content)
- [ ] Pricing set
- [ ] Availability set
- [ ] Release type chosen (Manual / Auto on approval / Phased)
- [ ] All metadata fields copied from this sheet
- [ ] Privacy nutrition label preview reviewed in App Store Connect

---

## TestFlight — External Test Submission (v1.2.0, build 17)

Use these when submitting the build for external beta review in App Store Connect → TestFlight.

### What to Test (4000 char — shown to testers + reviewers)
```
v1.2.0 — focus areas

1. Pfitzinger Advanced Marathoning plans (new)
   • From the plan picker, select "Advanced Marathoning — 18 week, 55 mi" or "70 mi"
   • Confirm all 18 weeks load with workout text matching the book (Mesocycles 1–4)
   • Goal marathon lands on day 7 (Sunday) of week 18 — pick a Sunday race date

2. Full plan catalog
   • The picker should show every bundled plan up front — no gating, no membership prompt
   • Open a few plans and confirm coach notes are attached to each session

3. Patreon removal
   • Open Settings — confirm there is no Patreon section
   • Sign-out, plan-delete, and Strava/Oura disconnect flows should still work

4. Existing flows (regression sweep)
   • Mark Done animation still fires on cardio/strength/heat sessions
   • Athlete journal notes still persist on cardio + strength
   • Strava deep links from session detail sheets still open the activity
   • Tuesday SWAP podcast banner still appears on Tuesdays and links to Spotify

Known caveats
• Oura integration is optional; skip if you don't have a ring
• Strava is still in API testing mode — connecting works for ~15 athletes total during beta
• A fresh account starts with an empty Progress tab until Strava syncs

Please file any visual glitches, crashes, or unexpected plan behavior via the TestFlight "Send Beta Feedback" button (screenshot + note is most useful).
```

### Beta App Description (4000 char — public TestFlight page)
```
JohnnyLikesTraining brings published coaching plans for marathoners and ultrarunners to your phone — week by week, day by day, with the full coach notes intact.

Pick a plan, set your race date, and open the app each morning to see exactly what to run and why. Strava activities auto-match to the prescribed workout. Optional Oura integration shows readiness next to today's session.

This beta is testing v1.2.0 — two new 18-week marathon plans from Pete Pfitzinger's Advanced Marathoning (55mi and 70mi schedules), the full plan catalog visible by default, and a streamlined Settings.
```

### Feedback Email
```
atler.j@gmail.com
```

### Marketing URL
```
https://johnnylikestraining.com
```

### Privacy Policy URL
```
https://johnnylikestraining.com/privacy
```

### Beta App Review — Sign-In Information
Same as App Store review (above): provide a dedicated Apple ID with Sign in with Apple, or temporarily re-enable `DEV_SIGNIN_ALLOWED = YES` and tell the reviewer to tap "Skip Sign-In (Dev)".

### Beta App Review Notes
```
External beta of v1.2.0 (build 17). Sign in with Apple is required. All bundled plans (Champion 100K, the SWAP catalog from 6-week base through 200-mile, and the two new Pfitzinger 18-week marathon schedules) are visible in the picker without any membership or in-app purchase. Strava and Oura connections are optional and not required to evaluate the build.
```

---

## Known Risks (do not block submission, but be ready)

| Risk | Impact | Mitigation |
|---|---|---|
| Strava: data not deleted on disconnect | Reviewer who checks Strava API Agreement might flag | If asked, commit to fixing in v1.1.2; existing TODO in `TODOS.md` |
| Strava: no 7-day refresh enforcement | Same | Same |
| Strava: still in testing mode (~15 athletes max) | Limits real-world usage, not review | Submit for Strava production API access (separate process at strava.com/settings/api) |
