-- Refactor strength sessions: pull workouts from coach notes instead of
-- template exercises.  The old template-based columns are replaced with
-- a planned_session_id reference, verbatim coach_notes text, and a simple
-- is_complete flag.

-- 1. Add new columns
alter table strength_sessions
  add column if not exists planned_session_id uuid references planned_sessions(id) on delete set null,
  add column if not exists coach_notes text not null default '',
  add column if not exists is_complete boolean not null default false;

-- 2. Drop old columns that are no longer used
alter table strength_sessions
  drop column if exists template_exercise_id,
  drop column if exists exercise_name,
  drop column if exists prescribed_sets,
  drop column if exists prescribed_reps,
  drop column if exists prescribed_weight_kg,
  drop column if exists prescribed_rpe,
  drop column if exists is_deload,
  drop column if exists is_template_override;

-- 3. Clear old generated session data (it will be re-generated from
--    PlannedSessions on next app launch).
truncate strength_sessions;

-- 4. Old template tables are no longer populated by the app.
--    Drop the template exercises and templates tables.
drop table if exists strength_logs;
drop table if exists strength_template_exercises;
drop table if exists strength_templates;

-- 5. Index on the new foreign key
create index if not exists idx_strength_sessions_planned
  on strength_sessions(planned_session_id);
