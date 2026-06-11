# Plan Verbatim Audit — fix before showing David & Megan

Methodology: extracted each bundled PDF in `scripts/source_pdfs/` to text, then for every session note in the JSON checked whether its distinctive 6-word phrases appear in the source PDF. A session counts as "paraphrased" if fewer than 30% of its phrases match.

## Top-line results

| Plan | Sessions | Paraphrased | Severity |
|---|---:|---:|---|
| champion_plan_100k | 161 | **3** | low — fix |
| swap_6_week_6w | 42 | 0 | clean |
| swap_base_building_12w | 84 | 0 | clean |
| swap_marathon_8w | 56 | 0 | clean |
| swap_50k_12w | 84 | 0 | clean |
| swap_50mile_12w | 84 | 0 | clean |
| swap_100k_16w | 112 | 0 | **see "Structural issues"** |
| swap_100mile_12w | 84 | 1 | trivial typo |
| **swap_lower_volume_ultra_12w** | 84 | **72** | **CRITICAL — broken extraction** |
| swap_200_mile_16w | 112 | 0 | clean |

## 🔴 Critical — must fix

### `swap_lower_volume_ultra_12w` is unreadable

72/84 sessions have words jammed together with no spaces:

> JSON: `4-6mileseasywith5x20sechills fast.Oneasyrunning,thinksmooth, withquickstrides…`
> PDF: `4-6 miles easy with 5 x 20 sec hills fast. On easy running, think smooth, with quick strides…`

This entire plan needs re-extraction from `SWAP Lower Volume Ultramarathon Plan.pdf`. The original PDF text is correct — the conversion script broke. Either:
- Re-run the import script with a working tokenizer
- Or hand-fix all 72 sessions (slow)

This plan would humiliate you if a SWAP athlete opened it.

### `swap_100k_16w` is a structural duplicate of `champion_plan_100k`

Both plans:
- Same author, same source ("SWAP Running")
- Same 16-week duration
- 100/112 sessions overlap on (week, day, type)
- Same week 1 Monday rest note, etc.

Differences:
- `champion_plan_100k`: 161 sessions, includes 49 strength prescriptions inline
- `swap_100k_16w`: 112 sessions, no inline strength entries

These are the *same plan*, just structured differently. Currently:
- `champion_plan_100k` is **free**
- `swap_100k_16w` is **Patreon-gated**

A user picking either gets the same training. Three options to discuss with David & Megan:

1. **Delete `swap_100k_16w`** — Champion is the canonical 100K plan, keep it as the one source of truth (currently free)
2. **Delete `champion_plan_100k`** — Keep `swap_100k_16w` Patreon-only since that's "the SWAP 100K plan"
3. **Reposition**: Move `champion_plan_100k` to Patreon (it's premium content), keep `swap_100k_16w` Patreon

The right answer depends on whether the Champion Plan was published as a free public asset (blog post, book, podcast) or is Patreon-exclusive content. Ask them directly.

## 🟡 Minor — quick fixes

### Champion plan: 3 strength sessions are paraphrased

All three say `Mountain Legs after your run (per the plan).` — that exact phrase doesn't appear in the PDF.

- Week 2, Day 4 (Thursday strength)
- Week 3, Day 3 (Wednesday strength)
- Week 14, Day 6 (Saturday strength)

The PDF for these spots just says `Mountain Legs` (sometimes with surrounding context in the running session's text). The "(per the plan)" wording was inserted by the import script. Replace with the actual nearby PDF text for that day's strength prescription, or just `Mountain Legs` if that's all the PDF gives.

### `swap_100mile_12w` W10D4

Single session has `6-10 mi e asy` (typo — "easy" split into "e asy"). PDF has `6-10 mi easy`. Likely a PDF whitespace artifact in the original import. One-character fix.

## 🟢 Unrelated cleanup before sending the email

These don't affect content accuracy but will look unprofessional:

### Dead plan files

- `winter_plan_10w.json` exists in `Resources/` but isn't in `PlanTemplateService.freeTemplateIDs` or `patronOnlyTemplateIDs`. It ships in the IPA but no UI surfaces it. Same for the `10-Week Winter Plan.pdf` in `scripts/source_pdfs/`. Delete both — they confuse anyone auditing the codebase.

### Patreon campaign ID

`Secrets.xcconfig` still has `PATREON_SWAP_CAMPAIGN_ID = placeholder`. Without the real campaign ID, the Patreon membership check can never succeed in production. **This is the most important specific ask to put in the email to David and Megan** — they own the Patreon campaign, and you need the numeric ID from their creator dashboard.

### Plans free vs Patreon — re-examine the cut

Currently free: `swap_6_week_6w`, `swap_base_building_12w`, `champion_plan_100k`

That's two intro/base plans + their flagship Champion Plan. Likely wrong:
- The 6-week and base building plans are good "free taste" choices — keep
- Champion Plan is their *premium long-form* product — probably should be Patreon-gated to protect SWAP's revenue model

If Champion is meant to be free (because they've published it publicly), keep it. Otherwise, swap it to Patreon and pick a different "free 100K teaser" — maybe a short SWAP base block they've published as a podcast giveaway.

This is the second most important question for the email.

## Strength/heat/stretch coverage

Not part of the verbatim audit but worth a quick mention before the demo:

- `champion_plan_100k.json` has 49 inline strength sessions
- All other plans have **zero inline strength sessions** in their JSON
- The strength template UI fills empty plans from `SWAP Strength Work Cheat Sheet.pdf` via the heat/stretch initialization path
- This means a user picking `swap_100k_16w` gets a different strength experience than `champion_plan_100k`

Worth asking the coaches: should every plan ship with inline strength prescriptions like Champion, or is the cheat-sheet fallback fine?

## What to say in the email

> "I ran a full audit of every plan in the app against the PDFs you shared. Eight of the ten plans are verbatim — every word matches your source. Two need cleanup before I'd ship them publicly:
> - **Lower-Volume Ultramarathon Plan**: my import script broke word spacing on the long-form notes. I'm re-extracting before launch.
> - **100K Plan vs Champion Plan**: I have both, but they're substantially the same content. Which should be the canonical one, and should it be free or Patreon-gated?
>
> Two specific asks: your SWAP Patreon campaign ID (so the membership gate actually works), and your call on which plans are free vs. patron-only."

This frames you as careful and detail-oriented, not as a guy who scraped their content and hoped nobody'd notice.
