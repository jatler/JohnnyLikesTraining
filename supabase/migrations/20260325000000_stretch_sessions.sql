-- M9: Stretch training tables

create table stretch_templates (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references training_plans(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_stretch_templates_plan on stretch_templates(plan_id);

create table stretch_template_exercises (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references stretch_templates(id) on delete cascade,
  day_of_week int not null check (day_of_week between 1 and 7),
  stretch_name text not null,
  hold_seconds int not null default 45,
  sets int not null default 1,
  is_bilateral boolean not null default true,
  sort_order int not null default 0,
  notes text
);

create index idx_stretch_template_exercises_template on stretch_template_exercises(template_id);

create table stretch_sessions (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references training_plans(id) on delete cascade,
  template_exercise_id uuid references stretch_template_exercises(id) on delete set null,
  scheduled_date date not null,
  week_number int not null,
  day_of_week int not null check (day_of_week between 1 and 7),
  stretch_name text not null,
  prescribed_hold_seconds int not null default 45,
  prescribed_sets int not null default 1,
  is_bilateral boolean not null default true
);

create index idx_stretch_sessions_plan on stretch_sessions(plan_id);
create index idx_stretch_sessions_date on stretch_sessions(scheduled_date);

create table stretch_logs (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references stretch_sessions(id) on delete cascade,
  completed_at timestamptz not null default now(),
  notes text
);

create index idx_stretch_logs_session on stretch_logs(session_id);

-- Row Level Security
alter table stretch_templates enable row level security;
alter table stretch_template_exercises enable row level security;
alter table stretch_sessions enable row level security;
alter table stretch_logs enable row level security;

create policy "Users manage own stretch templates"
  on stretch_templates for all
  using (
    plan_id in (
      select id from training_plans where user_id = auth.uid()
    )
  );

create policy "Users manage own stretch template exercises"
  on stretch_template_exercises for all
  using (
    template_id in (
      select st.id from stretch_templates st
      join training_plans tp on tp.id = st.plan_id
      where tp.user_id = auth.uid()
    )
  );

create policy "Users manage own stretch sessions"
  on stretch_sessions for all
  using (
    plan_id in (
      select id from training_plans where user_id = auth.uid()
    )
  );

create policy "Users manage own stretch logs"
  on stretch_logs for all
  using (
    session_id in (
      select ss.id from stretch_sessions ss
      join training_plans tp on tp.id = ss.plan_id
      where tp.user_id = auth.uid()
    )
  );
