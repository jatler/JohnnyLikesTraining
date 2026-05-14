-- Skip / swap / edit infrastructure for strength, heat, and stretch sessions.
-- Mirrors what cardio (planned_sessions) already has via session_skips + session_overrides,
-- but inlined onto the session rows themselves since these domains don't carry
-- per-day overrides and the inline columns persist cleanly through the existing
-- bulk-upsert pattern in each store.

alter table strength_sessions
    add column if not exists is_skipped boolean not null default false,
    add column if not exists skip_reason text,
    add column if not exists original_coach_notes text;

alter table heat_sessions
    add column if not exists is_skipped boolean not null default false,
    add column if not exists skip_reason text;

alter table stretch_sessions
    add column if not exists is_skipped boolean not null default false,
    add column if not exists skip_reason text;

-- Cardio (planned_sessions) gains a manual completion flag so the Done button
-- in SessionDetailSheet can mark a session complete independently of a Strava
-- match. The UI OR's this with Strava-match detection.
alter table planned_sessions
    add column if not exists manually_complete boolean not null default false;
