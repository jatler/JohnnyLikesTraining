-- Athlete-side journal field. Separate from coach_notes / notes which
-- carry the prescribed plan; athlete_notes captures how the session
-- actually felt, what was substituted, energy levels, etc. Optional and
-- nullable so existing rows decode without touching them.

alter table planned_sessions
    add column if not exists athlete_notes text;

alter table strength_sessions
    add column if not exists athlete_notes text;
