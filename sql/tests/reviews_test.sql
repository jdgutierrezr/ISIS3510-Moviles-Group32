\set ON_ERROR_STOP on
begin;
insert into auth.users(id) values ('10000000-0000-0000-0000-000000000001'), ('10000000-0000-0000-0000-000000000002');
insert into public.users(id,name,email,current_xp) values
('10000000-0000-0000-0000-000000000001','Reviewer','one@test.invalid',190),
('10000000-0000-0000-0000-000000000002','Reader','two@test.invalid',0);
insert into public.places(id,name,latitude,longitude) values ('20000000-0000-0000-0000-000000000001','Test place',4.6,-74.0);
insert into public.quests(id,place_id,title) values
('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Completed'),
('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','Pending');
insert into public.quest_completions(user_id,quest_id,status) values
('10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','completed'),
('10000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','completed'),
('10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000002','pending');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
do $$ declare r jsonb; begin
  begin
    perform public.submit_quest_review('30000000-0000-0000-0000-000000000002',5);
    raise exception 'Expected pending quest rejection';
  exception when others then
    if sqlerrm <> 'Complete this quest before reviewing it' then raise; end if;
  end;
  begin
    perform public.submit_quest_review('30000000-0000-0000-0000-000000000001',6);
    raise exception 'Expected rating rejection';
  exception when others then
    if sqlerrm <> 'Rating must be between 1 and 5' then raise; end if;
  end;
  begin
    perform public.submit_quest_review('30000000-0000-0000-0000-000000000001',5,p_notes=>repeat('x',501));
    raise exception 'Expected notes rejection';
  exception when others then
    if sqlerrm <> 'Notes must be at most 500 characters' then raise; end if;
  end;
  begin
    perform public.submit_quest_review('30000000-0000-0000-0000-000000000001',5,p_photo_paths => array['foreign/photo.jpg']);
    raise exception 'Expected photo rejection';
  exception when others then
    if sqlerrm <> 'Photo does not belong to this user and quest' then raise; end if;
  end;
  r := public.submit_quest_review('30000000-0000-0000-0000-000000000001',5);
  if (r->>'xp_earned')::int <> 20 then raise exception 'Wrong reward'; end if;
  r := public.submit_quest_review('30000000-0000-0000-0000-000000000001',1);
  if (r->>'xp_earned')::int <> 0 or not (r->>'already_submitted')::boolean then raise exception 'Retry awarded XP'; end if;
  if (select current_xp from public.users where id=auth.uid()) <> 210 then raise exception 'XP not atomic'; end if;
  if (select level from public.users where id=auth.uid()) <> 2 then raise exception 'Level not updated'; end if;
end $$;
set local role authenticated;
do $$ begin
  if (select count(*) from public.quest_reviews) <> 1 then raise exception 'Owner cannot read'; end if;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
insert into storage.objects(bucket_id,name) values ('review-photos',
  '10000000-0000-0000-0000-000000000002/30000000-0000-0000-0000-000000000001/photo.jpg');
do $$ begin
  if (select count(*) from public.quest_reviews) <> 0 then raise exception 'Private review leaked'; end if;
  begin
    insert into public.quest_reviews(user_id,quest_id,place_id,rating,accuracy)
    values(auth.uid(),'30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',5,'spotOn');
    raise exception 'Direct insert allowed';
  exception when insufficient_privilege then null; end;
  perform public.submit_quest_review('30000000-0000-0000-0000-000000000001',3,p_feature_on_discovery_map=>true,
    p_photo_paths=>array['10000000-0000-0000-0000-000000000002/30000000-0000-0000-0000-000000000001/photo.jpg']);
  delete from storage.objects where bucket_id='review-photos';
  if not exists(select 1 from storage.objects where bucket_id='review-photos') then raise exception 'Submitted photo deleted'; end if;
end $$;
reset role;
do $$ begin
  if (select average_rating from public.places where id='20000000-0000-0000-0000-000000000001') <> 4.0 then raise exception 'Incorrect average'; end if;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$ begin
  if (select count(*) from public.quest_reviews) <> 2 then raise exception 'Shared review not visible'; end if;
  if (select count(*) from storage.objects where bucket_id='review-photos') <> 1 then raise exception 'Shared photo not visible'; end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
do $$ begin
  begin
    perform public.submit_quest_review('30000000-0000-0000-0000-000000000001',5);
    raise exception 'Anonymous submission allowed';
  exception when others then
    if sqlerrm <> 'Not authenticated' then raise; end if;
  end;
end $$;
rollback;
select 'Review validation, idempotency, XP, rating average and RLS tests passed' as result;
