\set ON_ERROR_STOP on
do $$ begin
  if public.bq11_test_snapshot() is distinct from (select data from public.bq11_test_before)
    then raise exception 'BQ11 seed modified original quests, profile, objective progress, reviews or photos'; end if;
end $$;
begin;
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
set local role authenticated;
do $$ declare completed jsonb; reviewed jsonb; started public.quest_completions; begin
  -- Continue the original pending quest with its existing checked first step.
  completed := public.complete_objective('b1111111-0000-0000-0000-000000000001',
    'b2222222-0000-0000-0000-000000000012','11111111-1111-1111-1111-111111111111/proof.jpg');
  if not (completed->>'quest_completed')::boolean or (completed->>'xp_earned')::int<>60
    then raise exception 'Existing photo objective could not complete after seeding'; end if;
  insert into storage.objects(bucket_id,name) values('review-photos',
    '11111111-1111-1111-1111-111111111111/b1111111-0000-0000-0000-000000000001/new.jpg');
  reviewed := public.submit_quest_review('b1111111-0000-0000-0000-000000000001',4,
    p_notes=>'Review after BQ11 seed',p_highlights=>array['Hidden Gem'],
    p_photo_paths=>array['11111111-1111-1111-1111-111111111111/b1111111-0000-0000-0000-000000000001/new.jpg']);
  if (reviewed->>'already_submitted')::boolean or (reviewed->>'xp_earned')::int<>20
    then raise exception 'Review submission failed after seeding'; end if;
  if (select current_xp from public.users where id=auth.uid())<>180 then raise exception 'Quest/review reward changed'; end if;
  -- New demo quests are also startable/reviewable by the original account;
  -- the analytics-only participants do not mark them completed for this user.
  started := public.start_quest('e1300000-0000-0000-0000-000000000006');
  completed := public.complete_objective('e1300000-0000-0000-0000-000000000006',
    'e1400000-0000-0000-0000-000000000006',null);
  if not (completed->>'quest_completed')::boolean then raise exception 'Demo quest cannot complete'; end if;
  reviewed := public.submit_quest_review('e1300000-0000-0000-0000-000000000006',5,p_notes=>'Demo quest review');
  if (reviewed->>'xp_earned')::int<>20 then raise exception 'Demo quest cannot be reviewed'; end if;
  if (select current_xp from public.users where id=auth.uid())<>230 then raise exception 'Demo quest/review reward changed'; end if;
  -- The original unstarted quest remains startable as well.
  started := public.start_quest('b1111111-0000-0000-0000-000000000003');
  if started.status<>'pending' then raise exception 'Original quest cannot be started after seed'; end if;
end $$;
commit;
update public.bq11_test_before set data=public.bq11_test_snapshot();
\echo 'Original quest completion and review flow passed after BQ11 seed'
