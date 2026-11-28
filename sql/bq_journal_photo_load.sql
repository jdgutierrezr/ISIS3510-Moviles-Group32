-- ============================================
-- Wandr App - BQ (Sprint 4): How long does the photo journal take to show each photo,
-- and what share comes from the cache (memory or disk) instead of the network?
-- Run after telemetry.sql
-- ============================================

-- One row per photo source (memory, disk, network) and size (thumbnail, full)
create or replace function public.get_journal_photo_load(p_days integer default 30)
returns table (
  source text,
  photo_size text,
  loads integer,
  avg_ms integer,
  p95_ms integer,
  share_pct numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select
    metadata->>'source',
    metadata->>'size',
    count(*)::integer,
    round(avg(duration_ms))::integer,
    round(percentile_cont(0.95) within group (order by duration_ms))::integer,
    round(100.0 * count(*) / sum(count(*)) over (partition by metadata->>'size'), 1)
  from telemetry_events
  where event_name = 'journal_photo_load'
    and success
    and created_at >= now() - make_interval(days => p_days)
  group by metadata->>'source', metadata->>'size'
  order by metadata->>'size', count(*) desc;
$$;

-- Per day, to compare before and after the cache optimization
create or replace function public.get_journal_photo_load_daily(p_days integer default 30)
returns table (
  day date,
  loads integer,
  avg_ms integer,
  cache_pct numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select
    (created_at at time zone 'America/Bogota')::date,
    count(*)::integer,
    round(avg(duration_ms))::integer,
    round(100.0 * count(*) filter (where metadata->>'source' in ('memory', 'disk')) / count(*), 1)
  from telemetry_events
  where event_name = 'journal_photo_load'
    and success
    and metadata->>'size' = 'thumbnail'
    and created_at >= now() - make_interval(days => p_days)
  group by 1
  order by 1;
$$;

revoke execute on function public.get_journal_photo_load(integer) from public, anon;
revoke execute on function public.get_journal_photo_load_daily(integer) from public, anon;
grant execute on function public.get_journal_photo_load(integer) to authenticated;
grant execute on function public.get_journal_photo_load_daily(integer) to authenticated;
