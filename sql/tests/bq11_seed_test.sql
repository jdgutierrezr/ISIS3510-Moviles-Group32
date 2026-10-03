\set ON_ERROR_STOP on
begin;
select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$ declare r jsonb; counts int[]; participants int[]; places int[]; begin
  r := public.neighborhood_quest_activity(30);
  select array_agg((n->>'completed_quests')::int order by (n->>'completed_quests')::int desc),
         array_agg((n->>'active_participants')::int order by (n->>'completed_quests')::int desc),
         array_agg((n->>'active_places')::int order by (n->>'completed_quests')::int desc)
  into counts,participants,places
  from jsonb_array_elements(r->'neighborhoods') n where n->>'name' like 'Demo · %';
  if counts <> array[8,4,2,0] or participants <> array[4,3,2,0] or places <> array[2,2,1,0]
    then raise exception 'Demo ranking does not answer BQ11: % / % / %',counts,participants,places; end if;
  if r->'neighborhoods'->0->>'name' <> 'Demo · Barrio Norte' then raise exception 'Wrong partnership priority'; end if;
  if (select count(*) from public.nearby_quests(4.6097,-74.0817,5) where title like 'Demo · %') <> 6
    then raise exception 'Demo quests are not visible on Nearby'; end if;
  if exists(select 1 from public.nearby_quests(4.6097,-74.0817,5) q
    left join public.nearby_places(4.6097,-74.0817,5) p on p.id=q.place_id
    where q.title like 'Demo · %' and p.id is null) then raise exception 'Demo pins have no coordinates'; end if;
  if (select count(*) from public.quest_completions where user_id=auth.uid()
      and quest_id::text like 'e1300000-%') <> 4 then raise exception 'Demo caller completion RLS changed'; end if;
  if exists(select 1 from public.quest_completions where status='pending' and quest_id::text like 'e1300000-%')
    then raise exception 'Seed added an active quest'; end if;
end $$;
reset role;
do $$ begin
  if (select count(*) from public.quest_completions where quest_id::text like 'e1300000-%') <> 14
    then raise exception 'Duplicate or missing demo completions after rerun'; end if;
  if (select count(*) from public.quest_objective_completions o
    join public.quest_completions c on c.id=o.completion_id where c.quest_id::text like 'e1300000-%') <> 14
    then raise exception 'Seeded completion steps are inconsistent'; end if;
  if exists(select 1 from public.places where id::text not like 'e1200000-%' and neighborhood_id::text like 'e1100000-%')
    then raise exception 'Existing catalog mapping was overwritten'; end if;
  if exists(select 1 from public.users where id in (
    'e1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000002',
    'e1000000-0000-0000-0000-000000000003','e1000000-0000-0000-0000-000000000004') and current_xp<>0)
    then raise exception 'Seed awarded XP'; end if;
end $$;
rollback;
\echo 'BQ11 demo seed assertions passed'
