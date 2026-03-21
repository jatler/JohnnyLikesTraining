#!/usr/bin/env python3
"""
Rebuild coach `notes` in champion_plan_100k.json from the SWAP Champion Plan PDF
(table extraction via pdfplumber). Preserves `pace_description`, distances, and
other fields; only updates `notes` per session.
"""

from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

import pdfplumber

REPO = Path(__file__).resolve().parents[1]
JSON_PATH = REPO / "TrainingApp" / "Resources" / "champion_plan_100k.json"
DEFAULT_PDF = Path.home() / "Downloads" / "The Champion Plan for 100 km to 100 miles.pdf"


def norm_cell(s: str | None) -> str:
    if s is None:
        return ""
    return re.sub(r"\s+", " ", s.replace("\n", " ")).strip()


def extract_week_table(pdf_path: Path) -> dict[int, list[str]]:
    weeks: dict[int, list[str]] = {}
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            tab = page.extract_table()
            if not tab:
                continue
            for row in tab:
                if not row or len(row) < 8:
                    continue
                label = row[1] if row[0] in (None, "") or norm_cell(row[0]) == "" else row[0]
                cells = [norm_cell(row[i]) for i in range(1, 8)]
                if cells[0] == "Mon":
                    continue
                m = re.match(r"^Week\s+(\d+)\s*$", norm_cell(label))
                if not m:
                    wn = max(weeks.keys()) if weeks else None
                    if wn is not None:
                        for i in range(7):
                            if cells[i]:
                                if weeks[wn][i]:
                                    weeks[wn][i] = (weeks[wn][i] + " " + cells[i]).strip()
                                else:
                                    weeks[wn][i] = cells[i]
                    continue
                wn = int(m.group(1))
                if wn not in weeks:
                    weeks[wn] = cells[:]
                else:
                    for i in range(7):
                        if cells[i]:
                            if weeks[wn][i]:
                                weeks[wn][i] = (weeks[wn][i] + " " + cells[i]).strip()
                            else:
                                weeks[wn][i] = cells[i]
    return weeks


def fix_typos(s: str) -> str:
    s = s.replace("race dayl", "race day,")
    s = s.replace("race day,,", "race day,")
    s = s.replace("after 8s,", "after 800s,")
    s = s.replace("after 8s ", "after 800s ")
    s = s.replace("400 easy after 800s, 200 after 4s,", "400 easy after 800s, 200 after 400s,")
    s = s.replace("400 after 2s", "400 after 200s")
    s = s.replace("would be idea to", "would be ideal to")
    return s


def split_run_and_strength(cell: str, has_strength: bool) -> tuple[str, str | None]:
    """Returns (run_notes, strength_notes or None)."""
    c = fix_typos(cell)
    if not has_strength:
        return c, None
    low = c.lower()
    if "light strength" in low:
        i = low.index("light strength")
        return c[:i].rstrip(), c[i:].strip()
    idx = low.rfind(" mountain legs")
    if idx != -1:
        head = c[:idx].rstrip(" .")
        tail = c[idx + 1 :].strip()
        return head, tail
    return c, "Mountain Legs after your run (per the plan)."


def main() -> int:
    pdf_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PDF
    if not pdf_path.is_file():
        print(f"PDF not found: {pdf_path}", file=sys.stderr)
        return 1

    weeks = extract_week_table(pdf_path)
    if len(weeks) != 16:
        print(f"Expected 16 weeks, got {len(weeks)}", file=sys.stderr)
        return 1

    data = json.loads(JSON_PATH.read_text())
    sessions = data["sessions"]

    by_day: dict[tuple[int, int], list[dict]] = defaultdict(list)
    for s in sessions:
        by_day[(s["week"], s["day"])].append(s)

    for s in sessions:
        w, d = s["week"], s["day"]
        wt = s["workout_type"]
        cell = weeks[w][d - 1]
        has_str = any(x["workout_type"] == "strength" for x in by_day[(w, d)])

        run_text, str_text = split_run_and_strength(cell, has_str)
        if wt == "strength":
            s["notes"] = str_text or "Mountain Legs after your run (per the plan)."
        else:
            s["notes"] = run_text

    JSON_PATH.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    print(f"Updated {JSON_PATH} from {pdf_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
