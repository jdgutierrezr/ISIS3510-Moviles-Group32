-- Additive migration; run after the existing schema, RLS, RPC and storage scripts.
-- Existing Android RPCs and objective-proof storage are unchanged.
begin;

create table public.quest_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  quest_id uuid not null references public.quests(id) on delete cascade,
  place_id uuid not null references public.places(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  notes text not null default '' check (char_length(notes) <= 500),
  highlights text[] not null default '{}' check (cardinality(highlights) <= 10),
  accuracy text not null check (accuracy in ('spotOn', 'mostly', 'notQuite')),
  feature_on_discovery_map boolean not null default false,
  photo_paths text[] not null default '{}' check (cardinality(photo_paths) <= 4),
  xp_awarded integer not null default 20 check (xp_awarded = 20),
  created_at timestamptz not null default now(),
  unique (user_id, quest_id)
);
create index quest_reviews_place_idx on public.quest_reviews(place_id);
alter table public.quest_reviews enable row level security;
revoke all on public.quest_reviews from anon, authenticated;
grant select on public.quest_reviews to authenticated;
create policy "read own or shared reviews" on public.quest_reviews
  for select to authenticated
  using (user_id = auth.uid() or feature_on_discovery_map);

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('review-photos', 'review-photos', false, 10485760, array['image/jpeg'])
on conflict (id) do nothing;
create policy "upload own review photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'review-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "read own or shared review photos" on storage.objects for select to authenticated
  using (bucket_id = 'review-photos' and (
    (storage.foldername(name))[1] = auth.uid()::text or exists (
      select 1 from public.quest_reviews r
      where r.feature_on_discovery_map and name = any(r.photo_paths)
    )
  ));
-- Photos referenced by submitted reviews are immutable. Retries reuse the same bytes/path.
create policy "replace unsubmitted own review photos" on storage.objects for update to authenticated
  using (bucket_id = 'review-photos' and (storage.foldername(name))[1] = auth.uid()::text
    and not exists (select 1 from public.quest_reviews r where name = any(r.photo_paths)))
  with check (bucket_id = 'review-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "delete unsubmitted own review photos" on storage.objects for delete to authenticated
  using (bucket_id = 'review-photos' and (storage.foldername(name))[1] = auth.uid()::text
    and not exists (select 1 from public.quest_reviews r where name = any(r.photo_paths)));

create or replace function public.submit_quest_review(
  p_quest_id uuid,
  p_rating integer,
  p_notes text default '',
  p_highlights text[] default '{}',
  p_accuracy text default 'spotOn',
  p_feature_on_discovery_map boolean default false,
  p_photo_paths text[] default '{}'
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_place_id uuid;
  v_review public.quest_reviews;
  v_user public.users;
  v_path text;
  v_level integer;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  -- Serialize repeat requests for this completion before checking for an existing review.
  perform 1 from public.quest_completions
    where user_id = v_uid and quest_id = p_quest_id and status = 'completed' for update;
  if not found then raise exception 'Complete this quest before reviewing it'; end if;
  select * into v_review from public.quest_reviews where user_id = v_uid and quest_id = p_quest_id;
  if found then
    return jsonb_build_object('review_id', v_review.id, 'xp_earned', 0,
      'already_submitted', true, 'feature_on_discovery_map', v_review.feature_on_discovery_map);
  end if;
  if p_rating is null or p_rating not between 1 and 5 then raise exception 'Rating must be between 1 and 5'; end if;
  if p_notes is null or char_length(p_notes) > 500 then raise exception 'Notes must be at most 500 characters'; end if;
  if p_accuracy is null or p_accuracy not in ('spotOn', 'mostly', 'notQuite') then raise exception 'Invalid accuracy'; end if;
  if p_highlights is null or cardinality(p_highlights) > 10 or exists (
    select 1 from unnest(p_highlights) h where h is null or char_length(h) not between 1 and 60
  ) then raise exception 'Invalid highlights'; end if;
  if p_photo_paths is null or cardinality(p_photo_paths) > 4
    or cardinality(p_photo_paths) <> (select count(distinct p) from unnest(p_photo_paths) p)
    then raise exception 'Attach at most four distinct photos'; end if;
  foreach v_path in array p_photo_paths loop
    if v_path is null or v_path not like v_uid::text || '/' || p_quest_id::text || '/%'
      then raise exception 'Photo does not belong to this user and quest'; end if;
    perform 1 from storage.objects where bucket_id = 'review-photos' and name = v_path for share;
    if not found then raise exception 'Photo does not belong to this user and quest'; end if;
  end loop;
  select place_id into v_place_id from public.quests where id = p_quest_id;
  -- Serialize ratings for the same place so concurrent submissions cannot lose an average.
  perform 1 from public.places where id = v_place_id for update;
  insert into public.quest_reviews(user_id, quest_id, place_id, rating, notes, highlights,
    accuracy, feature_on_discovery_map, photo_paths)
  values(v_uid, p_quest_id, v_place_id, p_rating, btrim(p_notes), p_highlights,
    p_accuracy, coalesce(p_feature_on_discovery_map, false), p_photo_paths) returning * into v_review;
  update public.places set average_rating = (
    select round(avg(rating), 1) from public.quest_reviews where place_id = v_place_id
  ) where id = v_place_id;
  select * into v_user from public.users where id = v_uid for update;
  v_level := greatest(v_user.level, (v_user.current_xp + 20) / 200 + 1);
  update public.users set current_xp = current_xp + 20, level = v_level,
    tier = case when v_level >= 20 then 'master_pathfinder'::public.user_tier
      when v_level >= 10 then 'pathfinder'::public.user_tier
      when v_level >= 5 then 'trailblazer'::public.user_tier
      else 'bogota_scout'::public.user_tier end
  where id = v_uid;
  return jsonb_build_object('review_id', v_review.id, 'xp_earned', 20,
    'already_submitted', false, 'feature_on_discovery_map', v_review.feature_on_discovery_map);
end;
$$;
revoke all on function public.submit_quest_review(uuid, integer, text, text[], text, boolean, text[]) from public, anon;
grant execute on function public.submit_quest_review(uuid, integer, text, text[], text, boolean, text[]) to authenticated;
commit;
