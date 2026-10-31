-- BQ12: category engagement for business accounts.
-- Run after schema_creation.sql, rls_rules.sql and rpc_functions.sql.
-- Installs the shared testing code 1234. Accounts still activate through the RPC.
begin;

alter table public.users
  add column if not exists is_business boolean not null default false;

-- Existing profile writes use column-level grants. Never grant this column to clients.
revoke insert (is_business), update (is_business) on public.users from public, anon, authenticated;

-- One shared invitation code for the demo. Only its SHA-256 hash is stored.
create table if not exists public.business_access_config (
  singleton boolean primary key default true check (singleton),
  code_hash bytea not null check (octet_length(code_hash) = 32)
);
alter table public.business_access_config enable row level security;
revoke all on public.business_access_config from public, anon, authenticated;

-- Running this migration also replaces any previously configured code with 1234.
insert into public.business_access_config(singleton, code_hash)
values (true, sha256(convert_to('1234', 'UTF8')))
on conflict (singleton) do update set code_hash = excluded.code_hash;

create or replace function public.activate_business_access(p_code text)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  -- Retrying after a lost response is safe for an already activated account.
  if exists (select 1 from public.users where id = v_user_id and is_business) then
    return true;
  end if;

  if p_code is null or length(p_code) not between 4 and 128 then
    raise exception 'Invalid business access code' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.business_access_config
    where code_hash = sha256(convert_to(p_code, 'UTF8'))
  ) then
    raise exception 'Invalid business access code' using errcode = '22023';
  end if;

  update public.users set is_business = true where id = v_user_id;
  if not found then
    raise exception 'User profile not found' using errcode = '42501';
  end if;
  return true;
end;
$$;

create or replace function public.get_category_engagement()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, pg_temp
as $$
declare
  v_end timestamptz := now();
  v_start timestamptz := v_end - interval '30 days';
  v_categories jsonb;
begin
  if auth.uid() is null or not exists (
    select 1 from public.users where id = auth.uid() and is_business
  ) then
    raise exception 'Business access required' using errcode = '42501';
  end if;

  -- Aggregate across users without exposing their identities or changing completion RLS.
  with activity as (
    select p.category, c.user_id
    from public.quest_completions c
    join public.quests q on q.id = c.quest_id
    join public.places p on p.id = q.place_id
    where c.status = 'completed'
      and c.completed_at >= v_start and c.completed_at <= v_end
  ), totals as (
    select category::text as category,
      count(*) as completed_quests,
      count(distinct user_id) as unique_participants
    from activity
    group by category
  ), categories as (
    select value::text as category
    from unnest(enum_range(null::public.place_category)) as value
  ), ranked as (
    select c.category,
      coalesce(t.completed_quests, 0) as completed_quests,
      coalesce(t.unique_participants, 0) as unique_participants
    from categories c left join totals t using (category)
  )
  select jsonb_agg(to_jsonb(r) order by
    r.completed_quests desc, r.unique_participants desc, r.category)
  into v_categories from ranked r;

  return jsonb_build_object(
    'window_start', to_char(v_start at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'window_end', to_char(v_end at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'generated_at', to_char(v_end at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'categories', coalesce(v_categories, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.activate_business_access(text) from public, anon;
revoke all on function public.get_category_engagement() from public, anon;
grant execute on function public.activate_business_access(text) to authenticated;
grant execute on function public.get_category_engagement() to authenticated;
notify pgrst, 'reload schema';
commit;
