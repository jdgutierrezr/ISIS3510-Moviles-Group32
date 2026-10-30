-- ============================================
-- Wandr App - BQ2: Which quest step has the highest average response time?
-- Run after telemetry.sql
-- ============================================

create or replace function public.get_step_response_time(p_days integer default 30)
returns table (
  quest_id uuid,
  quest_title text,
  objective_id uuid,
  step_title text,
  step_order integer,
  requires_photo boolean,
  requests integer,
  avg_ms integer,
  max_ms integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    q.id,
    q.title,
    o.id,
    o.title,
    o.order_index,
    o.requires_photo,
    count(*)::integer,
    round(avg(t.duration_ms))::integer,
    max(t.duration_ms)::integer
  from telemetry_events t
  join quest_objectives o on o.id::text = t.metadata->>'objective_id'
  join quests q on q.id = o.quest_id
  where t.event_name = 'quest_step_response'
    and t.success
    and t.created_at >= now() - make_interval(days => p_days)
  group by q.id, q.title, o.id, o.title, o.order_index, o.requires_photo
  order by avg(t.duration_ms) desc;
$$;

revoke execute on function public.get_step_response_time(integer) from public, anon;
grant execute on function public.get_step_response_time(integer) to authenticated;
