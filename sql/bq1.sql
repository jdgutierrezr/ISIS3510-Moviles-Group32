create or replace function public.get_recommendation_load_time(p_days integer default 30)
returns table (requests integer, avg_ms integer, p95_ms integer, network_avg_ms integer, cache_avg_ms integer)
language sql
stable
security definer
set search_path = public
as $$
  select
    count(*)::integer,
    round(avg(duration_ms))::integer,
    round(percentile_cont(0.95) within group (order by duration_ms))::integer,
    round(avg(duration_ms) filter (where metadata->>'from_cache' = 'false'))::integer,
    round(avg(duration_ms) filter (where metadata->>'from_cache' = 'true'))::integer
  from telemetry_events
  where event_name = 'quest_recommendations_load'
    and success
    and created_at >= now() - make_interval(days => p_days);
$$;

revoke execute on function public.get_recommendation_load_time(integer) from public, anon;
grant execute on function public.get_recommendation_load_time(integer) to authenticated;
