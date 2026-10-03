-- Additive migration; run after the existing schema, RLS, RPC and storage scripts.
-- Existing Android RPCs and objective-proof storage are unchanged.
-- Safe to rerun against the matching schema; incompatible definitions fail atomically.
begin;

-- Serialize manual reruns. A temporary reference table lets us verify the full
-- column/default/constraint contract instead of silently accepting schema drift.
select pg_advisory_xact_lock(hashtextextended('wandr:review-migration', 0));
do $migration$
declare
  v_definition text := $definition$(
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
)$definition$;
  v_actual_columns jsonb;
  v_expected_columns jsonb;
  v_actual_constraints jsonb;
  v_expected_constraints jsonb;
begin
  -- PostgreSQL forbids temporary-to-permanent foreign keys. Verify those separately.
  execute 'create temporary table _wandr_expected_quest_reviews ' ||
    regexp_replace(v_definition, ' references public\.(users|quests|places)\(id\) on delete cascade', '', 'g') || ' on commit drop';
  if to_regclass('public.quest_reviews') is null then
    execute 'create table public.quest_reviews ' || v_definition;
  end if;
  if not exists (select 1 from pg_class where oid = 'public.quest_reviews'::regclass and relkind = 'r') then
    raise exception 'quest_reviews must be an ordinary table; no existing objects were changed';
  end if;
  select jsonb_agg(jsonb_build_array(a.attname, format_type(a.atttypid, a.atttypmod),
    a.attnotnull, pg_get_expr(d.adbin, d.adrelid), a.attidentity, a.attgenerated) order by a.attname)
  into v_actual_columns
  from pg_attribute a left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
  where a.attrelid = 'public.quest_reviews'::regclass and a.attnum > 0 and not a.attisdropped;
  select jsonb_agg(jsonb_build_array(a.attname, format_type(a.atttypid, a.atttypmod),
    a.attnotnull, pg_get_expr(d.adbin, d.adrelid), a.attidentity, a.attgenerated) order by a.attname)
  into v_expected_columns
  from pg_attribute a left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
  where a.attrelid = 'pg_temp._wandr_expected_quest_reviews'::regclass and a.attnum > 0 and not a.attisdropped;
  select jsonb_agg(jsonb_build_array(pg_get_constraintdef(oid), convalidated, condeferrable, condeferred)
    order by pg_get_constraintdef(oid)) into v_actual_constraints
  from pg_constraint where conrelid = 'public.quest_reviews'::regclass and contype <> 'f';
  select jsonb_agg(jsonb_build_array(pg_get_constraintdef(oid), convalidated, condeferrable, condeferred)
    order by pg_get_constraintdef(oid)) into v_expected_constraints
  from pg_constraint where conrelid = 'pg_temp._wandr_expected_quest_reviews'::regclass;
  if v_actual_columns is distinct from v_expected_columns
     or v_actual_constraints is distinct from v_expected_constraints then
    raise exception 'quest_reviews schema differs from the expected columns, defaults or constraints; migration rolled back. Reconcile the schema before rerunning';
  end if;
  if (select count(*) from pg_constraint where conrelid = 'public.quest_reviews'::regclass and contype = 'f') <> 3
     or (select count(*) from pg_constraint c
       join (values ('user_id', 'public.users'::regclass), ('quest_id', 'public.quests'::regclass),
                    ('place_id', 'public.places'::regclass)) expected(column_name, target) on c.confrelid = expected.target
       where c.conrelid = 'public.quest_reviews'::regclass and c.contype = 'f'
         and c.conkey = array[(select attnum from pg_attribute where attrelid = c.conrelid and attname = expected.column_name)]::smallint[]
         and c.confkey = array[(select attnum from pg_attribute where attrelid = c.confrelid and attname = 'id')]::smallint[]
         and c.confdeltype = 'c' and c.confupdtype = 'a' and c.confmatchtype = 's'
         and c.convalidated and not c.condeferrable and not c.condeferred) <> 3 then
    raise exception 'quest_reviews foreign keys differ from the expected ownership relationships; migration rolled back';
  end if;
end;
$migration$;
create index if not exists quest_reviews_place_idx on public.quest_reviews(place_id);
do $migration$
begin
  if not exists (
    select 1 from pg_index i join pg_class c on c.oid = i.indexrelid
    join pg_am am on am.oid = c.relam
    join pg_attribute a on a.attrelid = i.indrelid and a.attnum = i.indkey[0]
    where i.indexrelid = 'public.quest_reviews_place_idx'::regclass
      and i.indrelid = 'public.quest_reviews'::regclass and a.attname = 'place_id'
      and am.amname = 'btree' and i.indisvalid and i.indisready and not i.indisunique
      and i.indnatts = 1 and i.indpred is null and i.indexprs is null
  ) then
    raise exception 'quest_reviews_place_idx has an incompatible definition; migration rolled back';
  end if;
end;
$migration$;
alter table public.quest_reviews enable row level security;
revoke all on public.quest_reviews from anon, authenticated;
grant select on public.quest_reviews to authenticated;
drop policy if exists "read own or shared reviews" on public.quest_reviews;
create policy "read own or shared reviews" on public.quest_reviews
  for select to authenticated
  using (user_id = auth.uid() or feature_on_discovery_map);

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('review-photos', 'review-photos', false, 10485760, array['image/jpeg'])
on conflict (id) do update set
  name = excluded.name, public = excluded.public,
  file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "upload own review photos" on storage.objects;
create policy "upload own review photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'review-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "read own or shared review photos" on storage.objects;
create policy "read own or shared review photos" on storage.objects for select to authenticated
  using (bucket_id = 'review-photos' and (
    (storage.foldername(name))[1] = auth.uid()::text or exists (
      select 1 from public.quest_reviews r
      where r.feature_on_discovery_map and name = any(r.photo_paths)
    )
  ));
-- Photos referenced by submitted reviews are immutable. Retries reuse the same bytes/path.
drop policy if exists "replace unsubmitted own review photos" on storage.objects;
create policy "replace unsubmitted own review photos" on storage.objects for update to authenticated
  using (bucket_id = 'review-photos' and (storage.foldername(name))[1] = auth.uid()::text
    and not exists (select 1 from public.quest_reviews r where name = any(r.photo_paths)))
  with check (bucket_id = 'review-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "delete unsubmitted own review photos" on storage.objects;
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
