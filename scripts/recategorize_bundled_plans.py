#!/usr/bin/env python3
"""
Re-classify `workout_type` (and adjust `pace_description`) on every bundled plan
JSON in TrainingApp/Resources/.

Why this exists:
  The original SWAP-plan importer assigned `workout_type` from day-of-week alone
  (Mon=rest, Wed=intervals, ...). When a plan deviates from that template — most
  notably Champion Plan week 3, where Tuesday is the interval day and Wednesday
  is the easy day — the type ends up wrong even though `notes` (refreshed later
  from the PDF) describe the correct workout. This pass fixes those rows.

Policy:
  * Re-derive workout_type from notes content (warm-up structure, treadmill
    workout prefix, "X mi easy, N x ...", etc.).
  * Only override the existing label when the change is high-confidence: the
    cross-axis (workout vs. non-workout) flip we set out to fix, plus clear
    rest / race / cross_train mismatches. We deliberately don't shuffle within
    {easy, recovery, long_run} — that distinction is plan convention, not
    something the cell text always reveals.
  * If two sessions inside the same week swap workout_type with each other (the
    Champion W3 case), swap their pace_description too — the existing strings
    were authored for the original days and now describe the partner.
  * Otherwise, if workout_type changed, drop pace_description so the app shows
    nothing rather than a stale tagline. (Re-derive later if you want.)
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple

REPO = Path(__file__).resolve().parents[1]
RESOURCES = REPO / "TrainingApp" / "Resources"

WORKOUT = {"intervals", "tempo"}
NONWORKOUT = {"easy", "recovery", "long_run"}


def classify(text: str | None, day: int) -> str:
    if not text or not text.strip():
        return "rest"
    t = re.sub(r"\s+", " ", text).strip()
    tl = t.lower()

    # Race day: cell must START with race terminology.
    if re.match(r"^\d+\s*(?:mile|mi|k|km)(?:\s*or\s*\d+\s*(?:mile|mi|k|km))?\s*race\b", tl):
        return "race"
    if re.match(r"^race\s*(?:day|week|!|$)", tl):
        return "race"

    # Pure rest cell.
    if re.match(r"^rest[\.\s!]*$", tl):
        return "rest"
    if re.match(r"^rest[\.,!\s]", tl):
        rest_only = (
            "miles" not in tl
            and " mi " not in tl
            and " mi." not in tl
            and not re.search(r"\bx[-\s]?train\b", tl)
            and not re.match(r"^rest\s+or\s+\d", tl)
        )
        if rest_only:
            return "rest"

    # Workout structure: warm-up, treadmill workout, or "X mi easy, N x ..."
    starts_with_warmup = bool(
        re.match(
            r"^\d+(?:\.\d+)?(?:\s*[-–]\s*\d+(?:\.\d+)?)?\s*(?:mi|miles)\s+(?:easy|easy/mod|very easy)(?:\s+jog)?\s+warm[-\s]?up\b",
            tl,
        )
    )
    starts_with_treadmill_workout = bool(
        re.match(
            r"^uphill\s+treadmill\s+(?:at\s+\d|workout|with\s+\d+\s*x|in\s+z\d|\d+[-–]\d+\s*min\s+with|\d)",
            tl,
        )
    )
    starts_with_easy_then_intervals = bool(
        re.match(
            r"^\d+(?:\.\d+)?(?:\s*[-–]\s*\d+(?:\.\d+)?)?\s*(?:mi|miles)\s+easy[,.\s]+\d+\s*x\s*\d+\s*(?:min|sec|second|minute|hour)\b",
            tl,
        )
    )

    if starts_with_warmup or starts_with_treadmill_workout or starts_with_easy_then_intervals:
        has_short_intervals = bool(
            re.search(r"\d+\s*x\s*\d+\s*(?:min|sec|second|minute)\s*(?:fast|hill|hard)", tl)
        )
        if "threshold" in tl and not has_short_intervals:
            return "tempo"
        if (
            starts_with_treadmill_workout
            and "around 1-hour effort" in tl
            and not has_short_intervals
        ):
            return "tempo"
        return "intervals"

    # Tempo progression cells without warm-up wording.
    if re.match(r"^\d+(?:\.\d+)?(?:\s*[-–]\s*\d+(?:\.\d+)?)?\s*(?:mi|miles)\s+easy/mod\s+to\s+mod\b", tl):
        return "tempo"
    if re.match(r"^\d+(?:\.\d+)?(?:\s*[-–]\s*\d+(?:\.\d+)?)?\s*(?:mi|miles)\s+steady\b", tl):
        return "tempo"

    # Cross-train as primary activity.
    if re.match(
        r"^(?:about\s+)?\d+(?:\.\d+)?(?:\s*[-–]\s*\d+(?:\.\d+)?)?\s*(?:hours?|hr|min|minutes?)\b[a-z\s/]*x[-\s]?train\b",
        tl,
    ):
        return "cross_train"
    nospace = tl.replace(" ", "")
    if re.match(r"^\d+(?:\.\d+)?[-–]\d+(?:\.\d+)?(?:hours?|min|minutes?)easy(?:/mod)?x[-\s]?train", nospace):
        return "cross_train"
    if re.match(r"^rest\s+or\s+x[-\s]?train", tl):
        return "cross_train"

    # Recovery: cell starts with "X mi very easy".
    if re.match(r"^\d+(?:\.\d+)?(?:\s*[-–]\s*\d+(?:\.\d+)?)?\s*(?:mi|miles)\s+very\s+easy\b", tl):
        return "recovery"
    if "aerobic recovery" in tl[:80]:
        return "recovery"

    # Day-of-week tiebreaker for everything else.
    if day == 1:
        return "rest"
    if day == 6:
        return "long_run"
    return "easy"


def should_override(old: str, new: str) -> bool:
    if old == new:
        return False
    # Cross-axis flip — the actual bug.
    if (old in WORKOUT) != (new in WORKOUT):
        return True
    # Rest / race / cross_train mismatches.
    if old in {"rest", "race", "cross_train"} or new in {"rest", "race", "cross_train"}:
        return True
    # Within {easy, recovery, long_run}: keep curator's call.
    return False


def process_plan(path: Path) -> Tuple[int, int]:
    data = json.loads(path.read_text())
    sessions = data.get("sessions") or []

    by_week: Dict[int, List[dict]] = {}
    for s in sessions:
        if s.get("workout_type") == "strength":
            continue
        by_week.setdefault(s["week"], []).append(s)

    changed = 0
    swapped_pairs = 0

    # Per-week reclassification with paired pace swap.
    for week, week_sessions in by_week.items():
        proposals: List[Tuple[dict, str, str]] = []  # (session, old, proposed_new)
        for s in week_sessions:
            old = s["workout_type"]
            new = classify(s.get("notes"), s["day"])
            if should_override(old, new):
                proposals.append((s, old, new))

        # Detect swap pairs: two sessions where each takes the other's old type.
        used = set()
        for i, (s_a, old_a, new_a) in enumerate(proposals):
            if i in used:
                continue
            for j in range(i + 1, len(proposals)):
                if j in used:
                    continue
                s_b, old_b, new_b = proposals[j]
                if new_a == old_b and new_b == old_a:
                    s_a["workout_type"] = new_a
                    s_b["workout_type"] = new_b
                    pa = s_a.get("pace_description")
                    pb = s_b.get("pace_description")
                    s_a["pace_description"] = pb
                    s_b["pace_description"] = pa
                    used.update({i, j})
                    changed += 2
                    swapped_pairs += 1
                    break

        for k, (s, old, new) in enumerate(proposals):
            if k in used:
                continue
            s["workout_type"] = new
            # Existing pace_description was authored for the old type — drop it.
            if s.get("pace_description") is not None:
                s["pace_description"] = None
            changed += 1

    if changed:
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")

    return changed, swapped_pairs


def main(argv: List[str]) -> int:
    paths = sorted(RESOURCES.glob("*.json"))
    if not paths:
        print(f"No plan JSONs in {RESOURCES}", file=sys.stderr)
        return 1

    dry_run = "--dry-run" in argv

    total_changed = 0
    for p in paths:
        try:
            data = json.loads(p.read_text())
        except json.JSONDecodeError:
            continue
        if "sessions" not in data:
            continue

        if dry_run:
            # Re-derive without writing.
            backup = p.read_text()
            changed, swaps = process_plan(p)
            p.write_text(backup)
        else:
            changed, swaps = process_plan(p)

        if changed:
            print(f"{p.name}: {changed} session(s) updated, {swaps} pair-swap(s)")
        total_changed += changed

    print(f"\nTotal sessions updated: {total_changed}{' (dry run, not written)' if dry_run else ''}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
