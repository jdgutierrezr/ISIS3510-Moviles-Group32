\set ON_ERROR_STOP on
do $$ begin
  if public.bq11_test_snapshot() is distinct from (select data from public.bq11_test_before)
    then raise exception 'Reseeding changed saved reviews, active quests, profile or progress'; end if;
end $$;
begin;
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
set local role authenticated;
do $$ declare r jsonb; begin
  r := public.submit_quest_review('b1111111-0000-0000-0000-000000000001',1);
  if not (r->>'already_submitted')::boolean or (r->>'xp_earned')::int<>0 then raise exception 'Reseed broke review idempotency'; end if;
  if (select rating from public.quest_reviews where user_id=auth.uid() and quest_id='b1111111-0000-0000-0000-000000000001')<>4
    then raise exception 'Original review rating changed'; end if;
  r := public.submit_quest_review('e1300000-0000-0000-0000-000000000006',1);
  if not (r->>'already_submitted')::boolean or (r->>'xp_earned')::int<>0 then raise exception 'Demo quest review was reset by reseed'; end if;
  if not exists(select 1 from jsonb_array_elements(public.neighborhood_quest_activity()->'neighborhoods') n
    where n->>'id'='e1100000-0000-0000-0000-000000000004' and (n->>'completed_quests')::int=1)
    then raise exception 'BQ11 did not retain real demo-quest completion after reseeding'; end if;
end $$;
rollback;
\echo 'BQ11 reseed preserved reviews, photos, rewards and active quest progress'
