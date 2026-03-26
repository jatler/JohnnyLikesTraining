#!/usr/bin/env python3
"""
Generate TrainingApp bundled plan templates from PDFs in ~/Downloads/SWAP_Plans.

This produces `TrainingApp/Resources/<template_id>.json` files so the iOS app can
offer them in the plan picker.

Notes:
- Coach `notes` come from the extracted day cell text. We do not summarize.
- Distances are best-effort from mile ranges found in the extracted cell text.
- Workout types are inferred from day-of-week + keywords like "rest", "very easy",
  "cross train", "race", and "threshold/tempo".
- Duplicate templates (same `id`) are skipped.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pdfplumber


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SWAP_DIR = Path.home() / "Downloads" / "SWAP_Plans"
OUT_DIR = REPO_ROOT / "TrainingApp" / "Resources"

ALLOWED_WORKOUT_TYPES = {
    "easy",
    "tempo",
    "intervals",
    "long_run",
    "recovery",
    "rest",
    "race",
    "cross_train",
}


def norm_cell(s: Optional[str]) -> str:
    if not s:
        return ""
    # pdfplumber often gives odd newlines and extra spaces; normalize but keep wording.
    return re.sub(r"\s+", " ", s.replace("\n", " ")).strip()


def parse_week_number(week_cell: object) -> Optional[int]:
    """
    Extract a week number from a cell that may look like:
      - "Week 1 31 to 65 miles"
      - "1 (18 to 44 mi total)"
      - "2 25 to 86 mi"
      - "Week 10 Race week!!!"
    """
    if not isinstance(week_cell, str):
        return None

    s = norm_cell(week_cell)
    m = re.search(r"(?i)\bweek\s*(\d{1,3})\b", s)
    if m:
        return int(m.group(1))

    # Fallback: leading integer (used in several SWAP tables).
    m = re.match(r"^(\d{1,3})\b", s)
    if m:
        return int(m.group(1))

    return None


def extract_week_table(pdf_path: Path) -> Dict[int, List[str]]:
    """
    Returns {week_number: [Mon..Sun strings]}.
    Supports two common extraction layouts:
      - "swap-style": table row with ~24 columns, day text at indices [3,6,9,12,15,18,21]
      - "simple-style": row with 8 columns, day text at indices [1..7]
    """
    weeks: Dict[int, List[str]] = {}

    with pdfplumber.open(str(pdf_path)) as pdf:
        for page in pdf.pages:
            tab = page.extract_table()
            if not tab:
                continue

            for row in tab:
                if not row:
                    continue

                week = parse_week_number(row[0])
                if week is None:
                    continue

                # Collect up to 7 day cells from this row.
                # In these PDFs, week rows are typically: week label + Mon..Sun day cells,
                # but the extraction may collapse/expand columns depending on the page.
                day_values: List[Tuple[int, str]] = []
                for i in range(1, len(row)):
                    cell = row[i]
                    if cell is None:
                        continue
                    txt = norm_cell(cell) if isinstance(cell, str) else ""
                    if txt:
                        day_values.append((i, txt))

                if len(day_values) < 3:
                    # Avoid false positives on random text rows.
                    continue

                day_values.sort(key=lambda x: x[0])
                day_texts = [txt for _, txt in day_values[:7]]
                if len(day_texts) < 7:
                    day_texts += [""] * (7 - len(day_texts))

                existing = weeks.get(week)
                if existing is None:
                    weeks[week] = day_texts
                else:
                    merged = [
                        (day_texts[di] if existing[di] == "" else existing[di])
                        for di in range(7)
                    ]
                    weeks[week] = merged

    return weeks


def parse_miles_from_text(text: str) -> Optional[float]:
    """
    Best-effort distance extraction:
    - Sum midpoints of all "A-B miles" ranges found in the cell
    - If no ranges are found, use the first single "N miles" or "N mi"
    """
    if not text:
        return None

    text_l = text.lower()
    if "miles" not in text_l and "mi" not in text_l:
        return None

    ranges = re.findall(
        r"(\d+(?:\.\d+)?)\s*(?:-|to)\s*(\d+(?:\.\d+)?)\s*(?:miles|mi)\b",
        text,
        flags=re.I,
    )
    if ranges:
        total_mid = 0.0
        for a, b in ranges:
            total_mid += (float(a) + float(b)) / 2.0
        return total_mid

    m = re.search(r"(\d+(?:\.\d+)?)\s*(?:miles|mi)\b", text, flags=re.I)
    if m:
        return float(m.group(1))
    return None


def parse_race_distance_km(text: str) -> Optional[Tuple[float, str]]:
    """
    If the cell text indicates a race with a distance token (e.g. "50k", "100 mile"),
    return (distance_km, token_string).
    """
    if not text:
        return None

    s = norm_cell(text).lower()
    if "race" not in s:
        return None

    # Prefer patterns where the distance token is explicitly adjacent to the word "race",
    # e.g. "50k race!" or "100 mile race".
    # The tiny window helps avoid false matches like "... like the race" where distances
    # can be far earlier in the sentence.
    km_token: Optional[float] = None
    token: Optional[str] = None

    mk = re.search(r"(\d+(?:\.\d+)?)\s*k\b.{0,10}\brace\b", s, flags=re.I)
    if mk:
        v = float(mk.group(1))
        km_token = v
        token = f"{int(v) if v.is_integer() else v}k"

    if km_token is None:
        mm = re.search(r"(\d+(?:\.\d+)?)\s*(?:mile|mi)\b.{0,10}\brace\b", s, flags=re.I)
        if mm:
            miles = float(mm.group(1))
            km_token = miles * 1.609
            token = f"{int(miles) if miles.is_integer() else miles}mile"

    if km_token is None:
        # Rare pattern where "race" appears first (e.g. "Race week: 50k ...")
        mk2 = re.search(r"\brace\b.{0,10}(\d+(?:\.\d+)?)\s*k\b", s, flags=re.I)
        if mk2:
            v = float(mk2.group(1))
            km_token = v
            token = f"{int(v) if v.is_integer() else v}k"

    if km_token is None:
        mm2 = re.search(r"\brace\b.{0,10}(\d+(?:\.\d+)?)\s*(?:mile|mi)\b", s, flags=re.I)
        if mm2:
            miles = float(mm2.group(1))
            km_token = miles * 1.609
            token = f"{int(miles) if miles.is_integer() else miles}mile"

    if km_token is None or token is None:
        return None

    return (km_token, token)


def workout_type_for(day_of_week: int, week_cell_text: str) -> str:
    t = (week_cell_text or "").strip().lower()

    if not t:
        return "rest"

    if "race" in t:
        return "race"

    if "cross train" in t or "x-train" in t or "x train" in t:
        return "cross_train"

    if day_of_week == 1:
        return "rest"

    if "very easy" in t or "aerobic recovery" in t or "recovery day" in t:
        return "recovery"

    if day_of_week == 6:
        # Saturday is the long run / hardest weekend day in these SWAP plans.
        return "long_run"

    if day_of_week == 3:
        # Wednesday is typically intervals or tempo/threshold.
        if "threshold" in t or "tempo" in t or "steady" in t or "around 1-hour" in t:
            return "tempo"
        return "intervals"

    # Thursday is often easy or cross training; Sunday is easy.
    if day_of_week in (2, 4, 7):
        return "easy"

    return "easy"


def infer_pace_description(workout_type: str, text: str) -> Optional[str]:
    """
    Pace description is optional in the app.
    We keep it concise when we can identify a strong leading cue.
    """
    if not text:
        return None

    # Simple: take the first sentence-ish chunk.
    # Many cells start with the distance + effort description (e.g. "5-10 miles easy ...").
    # That can be redundant with notes, so we keep pace empty unless we can shorten it.
    first = text.split(".")[0].strip()
    if not first:
        return None
    if len(first) > 60:
        first = first[:60].rsplit(" ", 1)[0]
    return first or None


def slugify(s: str) -> str:
    s = s.lower().strip()
    s = re.sub(r"[^a-z0-9]+", "_", s)
    s = re.sub(r"_+", "_", s).strip("_")
    return s


@dataclass(frozen=True)
class PlanMeta:
    template_id: str
    name: str
    duration_weeks: int
    target_distances: List[str]


def plan_meta_from_pdf(pdf_path: Path, weeks: Dict[int, List[str]]) -> Optional[PlanMeta]:
    stem = pdf_path.stem
    duration = max(weeks.keys()) if weeks else 0
    if duration <= 0:
        return None

    all_text = " ".join(
        cell for week_cells in weeks.values() for cell in (week_cells or []) if cell
    ).lower()

    # Detect a race distance from the *latest* "race" mention in the plan.
    # SWAP PDFs often mention "race" earlier as a reference point ("like the race"),
    # so we intentionally pick the last week where we can parse an actual race distance.
    race_km_token: Optional[str] = None
    race_km: Optional[float] = None
    for week in sorted(weeks.keys(), reverse=True):
        day_texts = weeks.get(week, [])
        for cell in day_texts:
            if "race" not in (cell or "").lower():
                continue
            parsed = parse_race_distance_km(cell)
            if parsed:
                race_km, token = parsed
                race_km_token = token
                break
        if race_km_token:
            break

    # Filename-based fallback for target distances + id.
    stem_l = stem.lower()
    if race_km_token:
        if race_km_token.endswith("k"):
            target_distances = [f"{race_km_token[:-1].upper()}K"]
        elif race_km_token.endswith("mile"):
            miles = race_km_token[: -len("mile")]
            target_distances = [f"{miles.upper()}M"]
        else:
            target_distances = [stem]

        template_id = slugify(f"swap_{race_km_token}_{duration}w")
        name = f"SWAP {race_km_token.upper()} Plan ({duration} weeks)"
        return PlanMeta(
            template_id=template_id,
            name=name,
            duration_weeks=duration,
            target_distances=target_distances,
        )

    # If race-distance parsing fails (common for some "Google Doc" variants),
    # map those onto known templates by duration + light keyword cues.
    if "google doc" in stem.lower():
        if duration == 12:
            if "lower" in all_text:
                template_id = slugify(f"swap_lower_volume_ultra_{duration}w")
                name = f"SWAP Lower Volume Ultramarathon Plan ({duration} weeks)"
                return PlanMeta(
                    template_id=template_id,
                    name=name,
                    duration_weeks=duration,
                    target_distances=["Ultramarathon"],
                )

            template_id = slugify(f"swap_50k_{duration}w")
            name = f"SWAP 50K Plan ({duration} weeks)"
            return PlanMeta(
                template_id=template_id,
                name=name,
                duration_weeks=duration,
                target_distances=["50K"],
            )

        if duration == 8:
            template_id = slugify(f"swap_marathon_{duration}w")
            name = f"SWAP Marathon Plan ({duration} weeks)"
            return PlanMeta(
                template_id=template_id,
                name=name,
                duration_weeks=duration,
                target_distances=["Marathon"],
            )

    # No obvious race; infer from filename.
    if "100 mile" in stem_l:
        target_distances = ["100M"]
        template_id = slugify(f"swap_100_mile_{duration}w")
        name = f"SWAP 100 Mile Plan ({duration} weeks)"
    elif "200 mile" in stem_l:
        target_distances = ["200M"]
        template_id = slugify(f"swap_200_mile_{duration}w")
        name = f"SWAP 200 Mile Plan ({duration} weeks)"
    elif "50 mile" in stem_l:
        target_distances = ["50M"]
        template_id = slugify(f"swap_50_mile_{duration}w")
        name = f"SWAP 50 Mile Plan ({duration} weeks)"
    elif "50k" in stem_l:
        target_distances = ["50K"]
        template_id = slugify(f"swap_50k_{duration}w")
        name = f"SWAP 50K Plan ({duration} weeks)"
    elif "lower volume" in stem_l or "ultramarathon" in stem_l:
        target_distances = ["Ultramarathon"]
        template_id = slugify(f"swap_lower_volume_ultra_{duration}w")
        name = f"SWAP Lower Volume Ultramarathon Plan ({duration} weeks)"
    elif "marathon" in stem_l:
        target_distances = ["Marathon"]
        template_id = slugify(f"swap_marathon_{duration}w")
        name = f"SWAP Marathon Plan ({duration} weeks)"
    elif "base building" in stem_l:
        target_distances = ["Base building"]
        template_id = slugify(f"swap_base_building_{duration}w")
        name = f"SWAP Base Building Plan ({duration} weeks)"
    elif "6-week" in stem_l or "6-week" in pdf_path.name.lower():
        target_distances = ["Build phase"]
        template_id = slugify(f"swap_6_week_{duration}w")
        name = f"SWAP 6-Week Plan ({duration} weeks)"
    else:
        template_id = slugify(f"swap_{stem}_{duration}w")
        name = stem
        target_distances = [stem]

    return PlanMeta(
        template_id=template_id,
        name=name,
        duration_weeks=duration,
        target_distances=target_distances,
    )


def build_template_json(pdf_path: Path, weeks: Dict[int, List[str]], meta: PlanMeta) -> dict:
    sessions: List[dict] = []
    sort_order = 1

    for week in range(1, meta.duration_weeks + 1):
        day_texts = weeks.get(week)
        if not day_texts:
            # If a week row is missing, still keep the schedule shape so the app doesn't crash.
            day_texts = [""] * 7

        for day_idx, cell_text in enumerate(day_texts):
            day_of_week = day_idx + 1
            workout_type = workout_type_for(day_of_week, cell_text)

            notes = cell_text if cell_text else None

            target_distance_km: Optional[float] = None
            if workout_type == "race":
                parsed_race = parse_race_distance_km(cell_text)
                if parsed_race:
                    target_distance_km = parsed_race[0]
            else:
                miles = parse_miles_from_text(cell_text)
                if miles is not None:
                    target_distance_km = miles * 1.609

            pace_description = infer_pace_description(workout_type, cell_text) if cell_text else None

            sessions.append(
                {
                    "week": week,
                    "day": day_of_week,
                    "workout_type": workout_type,
                    "target_distance_km": target_distance_km,
                    "pace_description": pace_description,
                    "notes": notes,
                    # `sort_order` is optional in SessionTemplate, but we keep it implicit via PlanTemplateService ordering.
                }
            )
            sort_order += 1

    # Sanity-check workout types.
    for s in sessions:
        wt = s["workout_type"]
        if wt not in ALLOWED_WORKOUT_TYPES:
            raise ValueError(f"Invalid workout_type {wt} for {meta.template_id}")

    return {
        "id": meta.template_id,
        "name": meta.name,
        "author": "David Roche & Megan Roche, MD PhD",
        "source": "SWAP Running",
        "description": "Bundled training plan imported from SWAP_Plans PDF templates.",
        "duration_weeks": meta.duration_weeks,
        "target_distances": meta.target_distances,
        "sessions": sessions,
    }


def validate_template(template: dict) -> None:
    assert "id" in template and isinstance(template["id"], str)
    assert "duration_weeks" in template and isinstance(template["duration_weeks"], int)
    assert "sessions" in template and isinstance(template["sessions"], list)
    for s in template["sessions"]:
        assert s["workout_type"] in ALLOWED_WORKOUT_TYPES
        assert isinstance(s["week"], int)
        assert isinstance(s["day"], int) and 1 <= s["day"] <= 7


def main() -> int:
    swap_dir = DEFAULT_SWAP_DIR
    if not swap_dir.exists():
        print(f"SWAP dir not found: {swap_dir}", flush=True)
        return 1

    pdfs = sorted([p for p in swap_dir.iterdir() if p.suffix.lower() == ".pdf"])
    if not pdfs:
        print(f"No PDFs found in {swap_dir}", flush=True)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    produced_ids: Dict[str, Path] = {}
    skipped_existing = 0
    skipped_unparseable = 0

    for pdf_path in pdfs:
        print(f"Processing {pdf_path.name}...")
        weeks = extract_week_table(pdf_path)
        if not weeks:
            print(f"  Skipping (no week table detected).")
            skipped_unparseable += 1
            continue

        meta = plan_meta_from_pdf(pdf_path, weeks)
        if not meta:
            print(f"  Skipping (could not infer template meta).")
            skipped_unparseable += 1
            continue

        if meta.template_id in produced_ids:
            print(f"  Skipping (duplicate template id: {meta.template_id})")
            continue

        out_path = OUT_DIR / f"{meta.template_id}.json"
        if out_path.exists():
            print(f"  Skipping (already exists: {out_path.name})")
            skipped_existing += 1
            continue

        template = build_template_json(pdf_path, weeks, meta)
        validate_template(template)

        out_path.write_text(json.dumps(template, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        produced_ids[meta.template_id] = out_path
        print(f"  Wrote {out_path}")

    print(
        f"Done. Generated {len(produced_ids)} templates, skipped_existing={skipped_existing}, skipped_unparseable={skipped_unparseable}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

