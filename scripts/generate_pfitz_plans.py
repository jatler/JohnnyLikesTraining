#!/usr/bin/env python3
"""Generate the Pfitz 18/55 and 18/70 plan JSON files.

Source: Pete Pfitzinger & Scott Douglas, Advanced Marathoning (3rd ed.),
"55 Miles per Week or Less, 18-Week Schedule" and
"70 Miles per Week or Less, 18-Week Schedule".

Mapping conventions:
- day 1 = Monday ... day 7 = Sunday (matches PlanCalendarView columns)
- target_distance_km = day's total mileage * 1.609344
- workout_type classification:
    Rest / Rest or cross-training        -> rest
    Recovery / Recovery + speed          -> recovery / easy
    General aerobic (+ speed)            -> easy
    Medium-long run                      -> easy
    Long run                             -> long_run
    Lactate threshold                    -> tempo
    VO2max                               -> intervals
    Marathon specific / Dress rehearsal  -> tempo
    8-XK tune-up race                    -> race
    Goal marathon                        -> race
"""

import json
from pathlib import Path

MI_TO_KM = 1.609344


def km(mi):
    return round(mi * MI_TO_KM, 4)


# Day descriptors:
#   (mileage_mi, workout_type, pace_description, notes)
# Mileage is total mi for the day. Use 0 for rest. Tune-up race days
# carry the day's full mileage (warmup + race + cooldown estimate).
REST = (0, "rest", "rest", "Rest or cross-training")
HARD_REST = (0, "rest", "rest", "Rest")


def rec(mi, extra=None):
    note = f"Recovery {mi} mi"
    if extra:
        note += f". {extra}"
    return (mi, "recovery", f"Recovery {mi} mi", note)


def rec_double(am_mi, pm_mi):
    total = am_mi + pm_mi
    note = f"Recovery {am_mi} mi a.m., {pm_mi} mi p.m."
    return (total, "recovery", note, note)


def rec_speed(mi, strides):
    note = f"Recovery + speed {mi} mi w/ {strides} x 100 m strides"
    return (mi, "easy", note, note)


def rec_speed_double(am_mi, strides, pm_mi):
    total = am_mi + pm_mi
    note = f"Recovery + speed {am_mi} mi w/ {strides} x 100 m strides a.m.; {pm_mi} mi p.m."
    return (total, "easy", note, note)


def ga(mi):
    note = f"General aerobic {mi} mi"
    return (mi, "easy", note, note)


def ga_speed(mi, strides):
    note = f"General aerobic + speed {mi} mi w/ {strides} x 100 m strides"
    return (mi, "easy", note, note)


def mlr(mi):
    note = f"Medium-long run {mi} mi"
    return (mi, "easy", note, note)


def lr(mi):
    note = f"Long run {mi} mi"
    return (mi, "long_run", note, note)


def lt(total_mi, lt_mi):
    note = f"Lactate threshold {total_mi} mi w/ {lt_mi} mi @ 15K to half marathon race pace"
    return (total_mi, "tempo", note, note)


def vo2_reps(total_mi, reps, dist_m, jog):
    note = f"VO2max {total_mi} mi w/ {reps} x {dist_m:,} m @ 5K race pace; jog {jog} between"
    return (total_mi, "intervals", note, note)


def marathon_specific(total_mi, mp_mi):
    note = f"Marathon specific {total_mi} mi w/ {mp_mi} mi @ marathon race pace"
    return (total_mi, "tempo", note, note)


def tune_up(total_mi, race_label):
    note = f"{race_label} tune-up race ({total_mi} mi total: warm-up + race + cool-down)"
    return (total_mi, "race", f"{race_label} tune-up race", note)


def dress_rehearsal(total_mi, mp_mi):
    note = f"Dress rehearsal {total_mi} mi w/ {mp_mi} mi @ marathon race pace"
    return (total_mi, "tempo", note, note)


def goal_marathon():
    return (26.2, "race", "Goal marathon", "Goal marathon — race day!")


# ---------------------------------------------------------------------------
# 55 Miles per Week or Less, 18-Week Schedule
# Weeks-to-goal: 17, 16, 15, 14, 13, Recovery 12, 11, 10, 9, Recovery 8, 7,
#                 6, 5, 4, 3, 2, 1, Race week (0)
# Plan week 1 corresponds to weeks-to-goal 17.
# ---------------------------------------------------------------------------

PFITZ_55 = [
    # Week 1 (wtg 17, 32 mi) Mesocycle 1 Endurance
    [REST,            ga_speed(7, 10),  REST,             ga(9),            REST,             rec(4),          mlr(12)],
    # Week 2 (wtg 16, 36 mi)
    [REST,            ga_speed(8, 10),  REST,             ga(10),           REST,             rec(5),          mlr(13)],
    # Week 3 (wtg 15, 40 mi)
    [REST,            lt(8, 4),         rec(4),           ga(10),           REST,             rec(4),          mlr(14)],
    # Week 4 (wtg 14, 42 mi)
    [REST,            ga_speed(8, 10),  rec(5),           ga(10),           REST,             rec(4),          mlr(15)],
    # Week 5 (wtg 13, 46 mi)
    [REST,            lt(9, 4),         rec(5),           ga(10),           REST,             rec(5),          mlr(17)],
    # Week 6 (wtg 12 — Recovery, 37 mi)
    [REST,            ga_speed(8, 8),   rec(5),           ga(8),            REST,             rec(4),          mlr(12)],
    # Week 7 (wtg 11, 50 mi) Mesocycle 2 Lactate Threshold + Endurance
    [REST,            lt(10, 5),        rec(4),           mlr(11),          REST,             ga_speed(7, 8),  lr(18)],
    # Week 8 (wtg 10, 54 mi)
    [REST,            rec_speed(6, 6),  mlr(12),          REST,             lt(11, 6),        rec(5),          lr(20)],
    # Week 9 (wtg 9, 47 mi)
    [REST,            rec(6),           mlr(14),          rec(6),           REST,             rec_speed(6, 6), marathon_specific(15, 12)],
    # Week 10 (wtg 8 — Recovery, 43 mi)
    [REST,            ga(8),            vo2_reps(8, 5, 600, "90 sec"), rec(5), REST,         ga_speed(8, 8),  mlr(14)],
    # Week 11 (wtg 7, 55 mi)
    [REST,            rec_speed(6, 6),  lt(12, 7),        mlr(12),          REST,             rec(5),          lr(20)],
    # Week 12 (wtg 6, 50 mi) Mesocycle 3 Race Preparation
    [REST,            vo2_reps(8, 5, 600, "90 sec"), mlr(11), REST,         rec_speed(4, 6),  tune_up(10, "8-15K"), lr(17)],
    # Week 13 (wtg 5, 51 mi)
    [REST,            ga(8),            vo2_reps(9, 5, 1000, "2 min"), REST, mlr(12),         rec(5),          marathon_specific(17, 14)],
    # Week 14 (wtg 4, 50 mi)
    [REST,            vo2_reps(8, 5, 600, "90 sec"), mlr(11), REST,         rec_speed(4, 6),  tune_up(10, "8-15K"), lr(17)],
    # Week 15 (wtg 3, 49 mi)
    [REST,            rec_speed(5, 6),  vo2_reps(10, 4, 1200, "2 min"), REST, ga(10),         rec(4),          lr(20)],
    # Week 16 (wtg 2, 43 mi) Mesocycle 4 Taper and Race
    [REST,            vo2_reps(8, 5, 600, "90 sec"), rec(5), REST,           rec_speed(4, 6),  tune_up(10, "8-10K"), mlr(16)],
    # Week 17 (wtg 1, 32 mi)
    [REST,            ga_speed(7, 8),   vo2_reps(8, 3, 1600, "2 min"), REST, rec_speed(5, 6), REST,            mlr(12)],
    # Week 18 (Race week, 22 mi + race)
    [HARD_REST,       rec(6),           dress_rehearsal(7, 2), HARD_REST,    rec_speed(5, 6), rec(4),          goal_marathon()],
]


# ---------------------------------------------------------------------------
# 70 Miles per Week or Less, 18-Week Schedule
# ---------------------------------------------------------------------------

PFITZ_70 = [
    # Week 1 (wtg 17, 53 mi) Mesocycle 1 Endurance
    [REST,            ga_speed(8, 10),  mlr(11),          rec(5),           ga(9),            rec(5),          mlr(15)],
    # Week 2 (wtg 16, 56 mi)
    [REST,            ga_speed(8, 10),  mlr(12),          rec(5),           ga(9),            rec(5),          lr(17)],
    # Week 3 (wtg 15, 58 mi)
    [REST,            lt(9, 4),         mlr(13),          rec(5),           mlr(11),          rec(5),          mlr(15)],
    # Week 4 (wtg 14, 62 mi)
    [REST,            ga_speed(9, 10),  mlr(14),          rec(5),           mlr(11),          rec(5),          lr(18)],
    # Week 5 (wtg 13, 65 mi)
    [REST,            lt(9, 4),         mlr(14),          rec(5),           mlr(12),          rec(5),          lr(20)],
    # Week 6 (wtg 12 — Recovery, 55 mi)
    [REST,            ga_speed(8, 10),  mlr(12),          rec(5),           mlr(11),          rec(5),          mlr(14)],
    # Week 7 (wtg 11, 69 mi) Mesocycle 2 Lactate Threshold + Endurance
    [REST,            lt(10, 5),        mlr(14),          rec(5),           mlr(11),          ga_speed(8, 10), lr(21)],
    # Week 8 (wtg 10, 66 mi)
    [REST,            rec_double(6, 4), mlr(14),          rec(5),           lt(11, 6),        rec(6),          lr(20)],
    # Week 9 (wtg 9, 66 mi)
    [REST,            rec_double(6, 4), mlr(15),          rec(6),           mlr(13),          rec_speed(7, 6), marathon_specific(15, 12)],
    # Week 10 (wtg 8 — Recovery, 59 mi)
    [REST,            ga(10),           vo2_reps(9, 6, 600, "90 sec"), rec(6), mlr(11),       ga_speed(8, 10), mlr(15)],
    # Week 11 (wtg 7, 70 mi)
    [REST,            rec_double(6, 4), mlr(15),          rec(6),           lt(12, 7),        rec(5),          lr(22)],
    # Week 12 (wtg 6, 68 mi) Mesocycle 3 Race Preparation
    [REST,            vo2_reps(9, 5, 600, "90 sec"), mlr(14), rec_speed_double(6, 6, 4), rec(5), tune_up(12, "8-15K"), lr(18)],
    # Week 13 (wtg 5, 70 mi)
    [REST,            vo2_reps(11, 6, 1000, "90 sec"), mlr(15), rec_double(6, 4), mlr(12),    rec(5),          marathon_specific(17, 14)],
    # Week 14 (wtg 4, 63 mi)
    [REST,            vo2_reps(9, 5, 600, "2 min"), mlr(13), rec_speed(6, 6), rec(5),         tune_up(12, "8-15K"), lr(18)],
    # Week 15 (wtg 3, 68 mi)
    [REST,            rec_double(6, 4), vo2_reps(11, 6, 1200, "2 min"), mlr(14), ga_speed(8, 8), rec(5),       lr(20)],
    # Week 16 (wtg 2, 56 mi) Mesocycle 4 Taper and Race
    [REST,            ga_speed(7, 8),   mlr(12),          rec_speed(6, 6),  rec(5),           tune_up(9, "8-10K"), lr(17)],
    # Week 17 (wtg 1, 46 mi)
    [REST,            ga_speed(8, 8),   rec(5),           vo2_reps(8, 3, 1600, "2 min"), rec(5), ga_speed(7, 8), mlr(13)],
    # Week 18 (Race week, 30 mi + race)
    [HARD_REST,       rec_double(5, 4), dress_rehearsal(7, 2), rec(5),       rec_speed(5, 6), rec(4),          goal_marathon()],
]


def sessions_for(plan):
    out = []
    for week_idx, week in enumerate(plan, start=1):
        assert len(week) == 7, f"Week {week_idx} has {len(week)} days"
        for day_idx, (mi, wtype, pace, notes) in enumerate(week, start=1):
            session = {
                "week": week_idx,
                "day": day_idx,
                "workout_type": wtype,
                "target_distance_km": km(mi) if mi > 0 else None,
                "pace_description": pace,
                "notes": notes,
            }
            out.append(session)
    return out


def build_template(plan_id, name, target_distances, plan):
    return {
        "id": plan_id,
        "name": name,
        "author": "Pete Pfitzinger & Scott Douglas",
        "source": "Advanced Marathoning (3rd ed.)",
        "description": (
            "Pfitzinger & Douglas 18-week marathon schedule from Advanced "
            "Marathoning. Four mesocycles: Endurance, Lactate Threshold + "
            "Endurance, Race Preparation, and Taper. Six runs per week."
        ),
        "duration_weeks": 18,
        "target_distances": target_distances,
        "sessions": sessions_for(plan),
    }


def main():
    out_dir = Path(__file__).resolve().parent.parent / "TrainingApp" / "Resources"

    plans = [
        (
            "pfitz_advanced_marathon_18w_55",
            "Advanced Marathoning — 18 week, 55 mi",
            ["Marathon"],
            PFITZ_55,
        ),
        (
            "pfitz_advanced_marathon_18w_70",
            "Advanced Marathoning — 18 week, 70 mi",
            ["Marathon"],
            PFITZ_70,
        ),
    ]

    for plan_id, name, td, plan in plans:
        template = build_template(plan_id, name, td, plan)
        out_path = out_dir / f"{plan_id}.json"
        with open(out_path, "w") as f:
            json.dump(template, f, indent=2)
            f.write("\n")
        # Verify totals
        weekly_totals = []
        for week in plan:
            total_mi = sum(mi for mi, *_ in week if isinstance(mi, (int, float)))
            weekly_totals.append(round(total_mi, 1))
        print(f"Wrote {out_path.name}: {len(template['sessions'])} sessions, weekly mi={weekly_totals}")


if __name__ == "__main__":
    main()
