-- M8: Heat training tables

create table heat_sessions (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references training_plans(id) on delete cascade,
  scheduled_date date not null,
  week_number int not null,
  day_of_week int not null check (day_of_week between 1 and 7),
  session_type text not null default 'sauna',
  target_duration_minutes int not null default 25,
  notes text
);

create index idx_heat_sessions_plan on heat_sessions(plan_id);
create index idx_heat_sessions_date on heat_sessions(scheduled_date);

create table heat_logs (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references heat_sessions(id) on delete cascade,
  actual_duration_minutes int not null,
  session_type text not null default 'sauna',
  completed_at timestamptz not null default now(),
  notes text
);

create index idx_heat_logs_session on heat_logs(session_id);

-- Row Level Security
alter table heat_sessions enable row level security;
alter table heat_logs enable row level security;

create policy "Users manage own heat sessions"
  on heat_sessions for all
  using (
    plan_id in (
      select id from training_plans where user_id = auth.uid()
    )
  );

create policy "Users manage own heat logs"
  on heat_logs for all
  using (
    session_id in (
      select hs.id from heat_sessions hs
      join training_plans tp on tp.id = hs.plan_id
      where tp.user_id = auth.uid()
    )
  );
