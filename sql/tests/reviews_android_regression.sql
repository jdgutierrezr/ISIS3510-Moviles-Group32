\set ON_ERROR_STOP on
begin;
insert into auth.users(id) values ('10000000-0000-0000-0000-000000000003');
insert into public.users(id,name,email) values ('10000000-0000-0000-0000-000000000003','Android','android@test.invalid');
insert into public.places(id,name,latitude,longitude) values ('20000000-0000-0000-0000-000000000003','Android place',4.6,-74.0);
insert into public.quests(id,place_id,title,points_reward) values
('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000003','Existing quest',50);
insert into public.quest_objectives(id,quest_id,title,requires_photo,order_index) values
('40000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000003','Existing objective',false,1);
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
set local role authenticated;
do $$ declare r jsonb; begin
  perform public.start_quest('30000000-0000-0000-0000-000000000003');
  r := public.complete_objective('30000000-0000-0000-0000-000000000003','40000000-0000-0000-0000-000000000003');
  if not (r->>'quest_completed')::boolean or (r->>'xp_earned')::int <> 50 then raise exception 'Existing Android contract changed'; end if;
  if not (r ? 'new_badges') or not (r ? 'current_streak') then raise exception 'Completion fields missing'; end if;
end $$;
reset role;
do $$ begin
  if (select current_xp from public.users where id=auth.uid()) <> 50 then raise exception 'Review bonus awarded during completion'; end if;
  if exists(select 1 from public.quest_reviews where user_id=auth.uid()) then raise exception 'Review unexpectedly required'; end if;
end $$;
rollback;
select 'Existing Android start/complete quest RPCs still work without a review' as result;
