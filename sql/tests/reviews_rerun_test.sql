-- Local test database only: persistent fixtures verify migration reruns preserve data.
\set ON_ERROR_STOP on
begin;
insert into auth.users(id) values ('10000000-0000-0000-0000-000000000004');
insert into public.users(id,name,email,current_xp) values
('10000000-0000-0000-0000-000000000004','Rerun','rerun@test.invalid',180);
insert into public.places(id,name,latitude,longitude) values
('20000000-0000-0000-0000-000000000004','Rerun place',4.6,-74.0);
insert into public.quests(id,place_id,title) values
('30000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000004','Rerun quest');
insert into public.quest_completions(user_id,quest_id,status) values
('10000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000004','completed');
insert into storage.objects(bucket_id,name) values ('review-photos',
'10000000-0000-0000-0000-000000000004/30000000-0000-0000-0000-000000000004/photo.jpg');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',false);
select public.submit_quest_review('30000000-0000-0000-0000-000000000004',4,p_notes=>'Preserve this review',
p_photo_paths=>array['10000000-0000-0000-0000-000000000004/30000000-0000-0000-0000-000000000004/photo.jpg']);
commit;
create temporary table rerun_snapshot as select
  (select jsonb_agg(to_jsonb(r) order by id) from public.quest_reviews r) as reviews,
  (select jsonb_agg(to_jsonb(u) order by id) from public.users u) as users,
  (select jsonb_agg(to_jsonb(p) order by id) from public.places p) as places,
  (select jsonb_agg(to_jsonb(o) order by id) from storage.objects o) as photos;
-- Verify that reruns also reconcile the bucket settings without deleting objects.
update storage.buckets set public=true, file_size_limit=1 where id='review-photos';
\ir ../reviews.sql
\ir ../reviews.sql
do $$ declare v_result jsonb; begin
  if (select reviews from rerun_snapshot) is distinct from
    (select jsonb_agg(to_jsonb(r) order by id) from public.quest_reviews r)
    or (select users from rerun_snapshot) is distinct from
    (select jsonb_agg(to_jsonb(u) order by id) from public.users u)
    or (select places from rerun_snapshot) is distinct from
    (select jsonb_agg(to_jsonb(p) order by id) from public.places p)
    or (select photos from rerun_snapshot) is distinct from
    (select jsonb_agg(to_jsonb(o) order by id) from storage.objects o)
    then raise exception 'Rerun changed reviews, XP, ratings or photos'; end if;
  if not exists(select 1 from storage.buckets where id='review-photos' and not public
    and file_size_limit=10485760 and allowed_mime_types=array['image/jpeg'])
    then raise exception 'Bucket settings not reconciled'; end if;
  if (select count(*) from pg_policies where schemaname='public' and tablename='quest_reviews'
      and policyname='read own or shared reviews') <> 1 then raise exception 'Duplicate review policy'; end if;
  if (select count(*) from pg_policies where schemaname='storage' and tablename='objects'
    and policyname in ('upload own review photos','read own or shared review photos',
      'replace unsubmitted own review photos','delete unsubmitted own review photos')) <> 4
    then raise exception 'Missing or duplicate storage policies'; end if;
  v_result := public.submit_quest_review('30000000-0000-0000-0000-000000000004',5);
  if (v_result->>'xp_earned')::int <> 0 or not (v_result->>'already_submitted')::boolean
    then raise exception 'Rerun reset submission idempotency'; end if;
end $$;
select 'Repeated migration preserves reviews, photos, XP, ratings and retry behavior' as result;
