-- M1: Initial schema for Training app

-- Workout type enum
create type workout_type as enum (
  'easy', 'tempo', 'intervals', 'long_run',
  'recovery', 'rest', 'race', 'cross_train'
);

-- OAuth provider enum
create type oauth_provider as enum ('oura', 'strava');

-- Training plans
create table training_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  race_date date not null,
  plan_start_date date not null,
  source_file_name text,
  created_at timestamptz not null default now()
);

create index idx_training_plans_user on training_plans(user_id);

-- Planned sessions
create table planned_sessions (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references training_plans(id) on delete cascade,
  week_number int not null,
  day_of_week int not null check (day_of_week between 1 and 7),
  scheduled_date date not null,
  workout_type workout_type not null,
  target_distance_km numeric(6,2),
  target_pace_description text,
  notes text,
  sort_order int not null default 0
);

create index idx_planned_sessions_plan on planned_sessions(plan_id);
create index idx_planned_sessions_date on planned_sessions(scheduled_date);

-- Session swaps
create table session_swaps (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references training_plans(id) on delete cascade,
  session_a_id uuid not null references planned_sessions(id) on delete cascade,
  session_b_id uuid not null references planned_sessions(id) on delete cascade,
  reason text,
  swapped_at timestamptz not null default now()
);

-- Session skips
create table session_skips (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references planned_sessions(id) on delete cascade,
  reason text,
  skipped_at timestamptz not null default now()
);

-- Oura daily data
create table oura_daily (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  readiness_score int,
  sleep_score int,
  hrv_average numeric(6,2),
  resting_hr int,
  temperature_deviation numeric(4,2),
  raw_json jsonb,
  synced_at timestamptz not null default now(),
  unique (user_id, date)
);

create index idx_oura_daily_user_date on oura_daily(user_id, date);

-- Strava activities
create table strava_activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  strava_id bigint not null unique,
  activity_date date not null,
  name text not null,
  distance_km numeric(8,2) not null,
  moving_time_seconds int not null,
  elapsed_time_seconds int not null,
  average_pace_per_km numeric(6,2),
  average_hr int,
  elevation_gain_m numeric(8,2),
  map_polyline text,
  raw_json jsonb,
  synced_at timestamptz not null default now(),
  matched_session_id uuid references planned_sessions(id) on delete set null
);

create index idx_strava_activities_user on strava_activities(user_id);
create index idx_strava_activities_date on strava_activities(activity_date);

-- OAuth tokens (encrypted at rest by Supabase)
create table oauth_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider oauth_provider not null,
  access_token text not null,
  refresh_token text not null,
  expires_at timestamptz not null,
  scopes text,
  unique (user_id, provider)
);

-- Row Level Security
alter table training_plans enable row level security;
alter table planned_sessions enable row level security;
alter table session_swaps enable row level security;
alter table session_skips enable row level security;
alter table oura_daily enable row level security;
alter table strava_activities enable row level security;
alter table oauth_tokens enable row level security;

-- Users can only access their own data
create policy "Users manage own training plans"
  on training_plans for all
  using (auth.uid() = user_id);

create policy "Users manage own planned sessions"
  on planned_sessions for all
  using (
    plan_id in (
      select id from training_plans where user_id = auth.uid()
    )
  );

create policy "Users manage own session swaps"
  on session_swaps for all
  using (
    plan_id in (
      select id from training_plans where user_id = auth.uid()
    )
  );

create policy "Users manage own session skips"
  on session_skips for all
  using (
    session_id in (
      select ps.id from planned_sessions ps
      join training_plans tp on tp.id = ps.plan_id
      where tp.user_id = auth.uid()
    )
  );

create policy "Users manage own oura data"
  on oura_daily for all
  using (auth.uid() = user_id);

create policy "Users manage own strava activities"
  on strava_activities for all
  using (auth.uid() = user_id);

create policy "Users manage own oauth tokens"
  on oauth_tokens for all
  using (auth.uid() = user_id);
