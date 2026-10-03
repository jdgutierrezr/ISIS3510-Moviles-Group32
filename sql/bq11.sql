-- BQ11: install after the shared schema, RLS policies and rpc_functions.sql.
-- Existing nearby_quests / nearby_places signatures remain compatible with Android.
begin;

create table if not exists public.neighborhoods (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  city text not null check (btrim(city) <> ''),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  unique (city, name)
);

alter table public.places add column if not exists neighborhood_id uuid
  references public.neighborhoods(id) on delete set null;
create index if not exists places_neighborhood_idx on public.places(neighborhood_id);
create index if not exists quest_completions_activity_idx
  on public.quest_completions(completed_at, quest_id) where status = 'completed';

alter table public.neighborhoods enable row level security;
revoke all on public.neighborhoods from public, anon, authenticated;
grant select on public.neighborhoods to authenticated;
drop policy if exists "neighborhoods: read" on public.neighborhoods;
create policy "neighborhoods: read" on public.neighborhoods
  for select to authenticated using (true);

-- Only anonymous aggregate counts cross completion RLS. No user IDs, photos,
-- locations of users, or individual completion records are returned.
create or replace function public.neighborhood_quest_activity(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, pg_temp
as $$
declare
  v_end timestamptz := now();
  v_start timestamptz;
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;
  if p_days is null or p_days < 1 or p_days > 365 then
    raise exception 'Activity window must be between 1 and 365 days' using errcode = '22023';
  end if;
  v_start := v_end - make_interval(days => p_days);

  with activity as (
    select p.neighborhood_id, c.user_id, p.id as place_id
    from public.quest_completions c
    join public.quests q on q.id = c.quest_id
    join public.places p on p.id = q.place_id
    where c.status = 'completed'
      and c.completed_at >= v_start and c.completed_at <= v_end
  ), ranked as (
    select n.id, n.name, n.city, n.latitude, n.longitude,
      count(a.neighborhood_id) as completed_quests,
      count(distinct a.user_id) as active_participants,
      count(distinct a.place_id) as active_places
    from public.neighborhoods n
    left join activity a on a.neighborhood_id = n.id
    group by n.id
  )
  select jsonb_build_object(
    'window_start', to_char(v_start at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'window_end', to_char(v_end at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'unassigned_completions', (select count(*) from activity where neighborhood_id is null),
    'neighborhoods', coalesce((
      select jsonb_agg(to_jsonb(r) order by r.completed_quests desc, r.name, r.id) from ranked r
    ), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;

revoke all on function public.neighborhood_quest_activity(integer) from public, anon;
grant execute on function public.neighborhood_quest_activity(integer) to authenticated;
notify pgrst, 'reload schema';
commit;
