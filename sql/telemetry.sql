-- ============================================
-- Wandr App - Telemetry (BQ1 and BQ2)
-- Supabase / PostgreSQL
-- Run after storage.sql
-- ============================================

-- One row per measured request. The apps save them locally and send them in batches.
create table telemetry_events (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references users(id) on delete cascade,
  event_name text not null,
  duration_ms integer not null check (duration_ms >= 0),
  success boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  app_platform text not null check (app_platform in ('android', 'ios')),
  -- When it happened on the phone (it may arrive later)
  created_at timestamptz not null default now()
);

create index idx_telemetry_events_name_created on telemetry_events(event_name, created_at);

-- ============================================
-- RLS: the apps can only add their own rows and can never read them.
-- Analysis is done from the SQL editor (it bypasses RLS).
-- ============================================

alter table telemetry_events enable row level security;

create policy "telemetry_events: insert own" on telemetry_events
  for insert to authenticated with check (user_id = auth.uid());

-- ============================================
-- Event names sent by the apps
--   quest_recommendations_load  BQ1  time until nearby quests are shown
--                                    metadata: radius_km, policy, result_count, from_cache
--   quest_step_response         BQ2  time of each complete_objective call
--                                    metadata: quest_id, objective_id, with_photo
-- ============================================

-- ============================================
-- Queries for the business questions (run them in the SQL editor)
-- ============================================

-- BQ1: During the last 30 days, what has been our average response time for quest recommendations?
-- select
--   app_platform,
--   count(*) as requests,
--   round(avg(duration_ms)) as avg_ms,
--   percentile_cont(0.95) within group (order by duration_ms) as p95_ms
-- from telemetry_events
-- where event_name = 'quest_recommendations_load'
--   and success
--   and created_at >= now() - interval '30 days'
-- group by app_platform;

-- BQ2: Which quest step has the highest average response time?
-- select
--   q.title as quest,
--   o.title as step,
--   count(*) as requests,
--   round(avg(t.duration_ms)) as avg_ms
-- from telemetry_events t
-- join quest_objectives o on o.id = (t.metadata->>'objective_id')::uuid
-- join quests q on q.id = o.quest_id
-- where t.event_name = 'quest_step_response'
-- group by q.title, o.title
-- order by avg_ms desc
-- limit 10;
