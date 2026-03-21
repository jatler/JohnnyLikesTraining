-- M7: Session overrides + strength training tables

-- Session overrides (manual workout adjustments)
create table session_overrides (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references planned_sessions(id) on delete cascade unique,
  original_workout_type workout_type,
  original_target_distance_km numeric(6,2),
  original_target_pace_description text,
  original_notes text,
  override_reason text,
  overridden_at timestamptz not null default now()
);

create index idx_session_overrides_session on session_overrides(session_id);

-- Strength templates (one per training plan)
create table strength_templates (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references training_plans(id) on delete cascade unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Strength template exercises (the repeating weekly pattern)
create table strength_template_exercises (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references strength_templates(id) on delete cascade,
  day_of_week int not null check (day_of_week between 1 and 7),
  exercise_name text not null,
  target_sets int not null default 3,
  target_reps int not null default 10,
  target_weight_kg numeric(6,2),
  target_rpe numeric(3,1),
  is_bodyweight boolean not null default false,
  sort_order int not null default 0,
  notes text
);

create index idx_strength_template_exercises_template on strength_template_exercises(template_id);

-- Strength sessions (per-week instantiated exercises)
create table strength_sessions (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references training_plans(id) on delete cascade,
  template_exercise_id uuid references strength_template_exercises(id) on delete set null,
  scheduled_date date not null,
  week_number int not null,
  day_of_week int not null check (day_of_week between 1 and 7),
  exercise_name text not null,
  prescribed_sets int not null default 3,
  prescribed_reps int not null default 10,
  prescribed_weight_kg numeric(6,2),
  prescribed_rpe numeric(3,1),
  is_deload boolean not null default false,
  is_template_override boolean not null default false
);

create index idx_strength_sessions_plan on strength_sessions(plan_id);
create index idx_strength_sessions_date on strength_sessions(scheduled_date);

-- Strength logs (actual completed sets)
create table strength_logs (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references strength_sessions(id) on delete cascade,
  set_number int not null,
  actual_reps int not null,
  actual_weight_kg numeric(6,2),
  rpe numeric(3,1),
  completed_at timestamptz not null default now(),
  notes text
);

create index idx_strength_logs_session on strength_logs(session_id);

-- Row Level Security
alter table session_overrides enable row level security;
alter table strength_templates enable row level security;
alter table strength_template_exercises enable row level security;
alter table strength_sessions enable row level security;
alter table strength_logs enable row level security;

create policy "Users manage own session overrides"
  on session_overrides for all
  using (
    session_id in (
      select ps.id from planned_sessions ps
      join training_plans tp on tp.id = ps.plan_id
      where tp.user_id = auth.uid()
    )
  );

create policy "Users manage own strength templates"
  on strength_templates for all
  using (
    plan_id in (
      select id from training_plans where user_id = auth.uid()
    )
  );

create policy "Users manage own strength template exercises"
  on strength_template_exercises for all
  using (
    template_id in (
      select st.id from strength_templates st
      join training_plans tp on tp.id = st.plan_id
      where tp.user_id = auth.uid()
    )
  );

create policy "Users manage own strength sessions"
  on strength_sessions for all
  using (
    plan_id in (
      select id from training_plans where user_id = auth.uid()
    )
  );

create policy "Users manage own strength logs"
  on strength_logs for all
  using (
    session_id in (
      select ss.id from strength_sessions ss
      join training_plans tp on tp.id = ss.plan_id
      where tp.user_id = auth.uid()
    )
  );
