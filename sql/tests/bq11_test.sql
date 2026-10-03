\set ON_ERROR_STOP on
begin;
-- Lower boundary is inclusive; this completion belongs to neither caller nor friends.
insert into public.quest_completions(user_id,quest_id,status,completed_at) values
('10000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000001','completed',now()-interval '30 days');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$ declare r jsonb; short jsonb; begin
  r := public.neighborhood_quest_activity(30);
  if r->'neighborhoods'->0->>'name' <> 'Test North'
    or (r->'neighborhoods'->0->>'completed_quests')::int <> 4
    or (r->'neighborhoods'->0->>'active_participants')::int <> 3
    or (r->'neighborhoods'->0->>'active_places')::int <> 2
    then raise exception 'BQ11 aggregation, ranking, distinct counts or inclusive boundary failed: %',r; end if;
  if (r->'neighborhoods'->1->>'completed_quests')::int <> 1
    or (r->'neighborhoods'->2->>'completed_quests')::int <> 0
    or (r->>'unassigned_completions')::int <> 1
    then raise exception 'Zero activity / unassigned coverage failed'; end if;
  if (r->>'window_end')::timestamptz - (r->>'window_start')::timestamptz <> interval '30 days'
    then raise exception 'Incorrect reporting window'; end if;
  if (select count(*) from public.quest_completions) <> 3 then raise exception 'Completion RLS changed'; end if;
  if r::text like '%user_id%' then raise exception 'Identity leaked in analytics'; end if;
  short := public.neighborhood_quest_activity(1);
  if (short->'neighborhoods'->0->>'completed_quests')::int <> 1 then raise exception 'Window filter failed'; end if;
  begin
    perform public.neighborhood_quest_activity(0);
    raise exception 'Invalid window accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.neighborhood_quest_activity(null);
    raise exception 'Null window accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.neighborhood_quest_activity(366);
    raise exception 'Unbounded window accepted';
  exception when invalid_parameter_value then null; end;
  begin
    insert into public.neighborhoods(name,city,latitude,longitude) values('Unauthorized','Bogotá',4.6,-74);
    raise exception 'Authenticated catalog write allowed';
  exception when insufficient_privilege then null; end;
  if not exists(select 1 from public.nearby_quests(4.61,-74.08,1)) then raise exception 'Nearby quests missing'; end if;
  if exists(select 1 from public.nearby_quests(4.61,-74.08,1) where distance_km > 1) then raise exception 'Radius filtering failed'; end if;
  if (select count(*) from public.nearby_quests(4.61,-74.08,5)) <= (select count(*) from public.nearby_quests(4.61,-74.08,1)) then raise exception 'Radius widening failed'; end if;
  if exists(select 1 from public.nearby_quests(4.61,-74.08,5) q
      left join public.nearby_places(4.61,-74.08,5) p on p.id=q.place_id where p.id is null)
    then raise exception 'Quest/place coordinate join failed'; end if;
  if exists(select 1 from public.nearby_quests(0,0,1)) then raise exception 'Expected empty nearby results'; end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
set local role authenticated;
do $$ begin
  begin
    perform public.neighborhood_quest_activity();
    raise exception 'Missing identity accepted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role anon;
do $$ begin
  begin
    perform public.neighborhood_quest_activity();
    raise exception 'Anonymous caller allowed';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
-- Verify delete behavior, deterministic ties, and empty analytics without changing persistent fixtures.
update public.quest_completions set completed_at = now()+interval '1 day';
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
do $$ declare r jsonb; begin
  r := public.neighborhood_quest_activity();
  if (r->'neighborhoods'->0->>'completed_quests')::int <> 0 then raise exception 'Empty activity failed'; end if;
  if r->'neighborhoods'->0->>'name' <> 'Test North' then raise exception 'Tie ordering unstable'; end if;
end $$;
delete from public.neighborhoods;
do $$ declare r jsonb; begin
  r := public.neighborhood_quest_activity();
  if r->'neighborhoods' <> '[]'::jsonb then raise exception 'No-neighborhood result failed'; end if;
  if exists(select 1 from public.places where neighborhood_id is not null) then raise exception 'Deleted-neighborhood FK failed'; end if;
end $$;
rollback;
\echo 'BQ11 integration assertions passed'
