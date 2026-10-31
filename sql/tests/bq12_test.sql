-- Synthetic data, for the isolated Docker harness only.
\set ON_ERROR_STOP on
insert into auth.users(id)
select ('10000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid
from generate_series(1, 4) n;
insert into public.users(id, name, email)
select id, 'Test ' || id, id || '@test.invalid' from auth.users;

-- No configured code must mean no activation.
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', false);
set role authenticated;
do $$ begin
  begin
    perform public.activate_business_access('bq12-local-test-code-only');
    raise exception 'Activated without a configured code';
  exception when invalid_parameter_value then null; end;
end $$;
reset role;

insert into public.business_access_config(code_hash)
values (sha256(convert_to('bq12-local-test-code-only', 'UTF8')));
update public.users set is_business = true
where id = '10000000-0000-0000-0000-000000000004';

-- Reapplying must preserve the code and existing business accounts.
\ir ../bq12.sql
do $$ begin
  if not (select is_business from public.users
      where id = '10000000-0000-0000-0000-000000000004') then
    raise exception 'Migration reset business access';
  end if;
  if (select count(*) from public.business_access_config) <> 1 then
    raise exception 'Migration reset the invitation code';
  end if;
end $$;

begin;
insert into public.places(id, name, category, latitude, longitude) values
('20000000-0000-0000-0000-000000000001', 'Park', 'park', 4.6, -74.0),
('20000000-0000-0000-0000-000000000002', 'Museum', 'museum', 4.6, -74.0),
('20000000-0000-0000-0000-000000000003', 'Restaurant', 'restaurant', 4.6, -74.0),
('20000000-0000-0000-0000-000000000004', 'Bar', 'bar', 4.6, -74.0);
insert into public.quests(id, place_id, title)
select ('30000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
  ('20000000-0000-0000-0000-' || lpad(
    (case when n <= 7 then 1 when n = 8 then 2 when n <= 10 then 3 else 4 end)::text,
    12, '0'))::uuid,
  'Quest ' || n
from generate_series(1, 11) n;
insert into public.quest_completions(user_id, quest_id, status, completed_at) values
('10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 'completed', now() - interval '30 days'),
('10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', 'completed', now()),
('10000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000002', 'completed', now() - interval '1 day'),
('10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000003', 'completed', now() - interval '30 days 1 second'),
('10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000004', 'completed', now() + interval '1 second'),
('10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000005', 'completed', null),
('10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000006', 'pending', now()),
('10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000007', 'abandoned', now()),
('10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000008', 'completed', now()),
('10000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000008', 'completed', now()),
('10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000009', 'completed', now()),
('10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000010', 'completed', now()),
('10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000011', 'completed', now()),
('10000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000011', 'completed', now());

set local role authenticated;
do $$ declare invalid_code text; r jsonb; begin
  if (select is_business from public.users where id = auth.uid()) then
    raise exception 'Normal accounts default to business';
  end if;
  begin
    perform public.get_category_engagement();
    raise exception 'Normal account read report';
  exception when insufficient_privilege then null; end;
  begin
    update public.users set is_business = true where id = auth.uid();
    raise exception 'Client changed its own role';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.users(id, name, email, is_business)
    values (auth.uid(), 'Escalation', 'escalation@test.invalid', true);
    raise exception 'Client inserted business role';
  exception when insufficient_privilege then null; end;
  begin
    perform code_hash from public.business_access_config;
    raise exception 'Client read code hash';
  exception when insufficient_privilege then null; end;
  begin
    update public.business_access_config set code_hash = sha256('x'::bytea);
    raise exception 'Client changed activation code';
  exception when insufficient_privilege then null; end;

  foreach invalid_code in array array[null, '', 'short', repeat('x', 129), 'wrong-long-invitation-code'] loop
    begin
      perform public.activate_business_access(invalid_code);
      raise exception 'Invalid code accepted';
    exception when invalid_parameter_value then null; end;
  end loop;
  if not public.activate_business_access('bq12-local-test-code-only') then
    raise exception 'Valid activation failed';
  end if;
  if not public.activate_business_access(null) then
    raise exception 'Activation retry failed';
  end if;
  if (select is_business from public.users where id = '10000000-0000-0000-0000-000000000002') then
    raise exception 'Activation modified another account';
  end if;
  update public.users set name = 'Still editable' where id = auth.uid();
  if (select count(*) from public.quest_completions) <> 0 then
    raise exception 'Report access exposed other users raw completions';
  end if;

  r := public.get_category_engagement();
  if jsonb_array_length(r->'categories') <> 8
    or r->'categories'->0 <> '{"category":"park","completed_quests":3,"unique_participants":2}'::jsonb
    or r->'categories'->1->>'category' <> 'bar'
    or r->'categories'->2->>'category' <> 'museum'
    or r->'categories'->3 <> '{"category":"restaurant","completed_quests":2,"unique_participants":1}'::jsonb
    or (r->'categories'->4->>'completed_quests')::int <> 0 then
    raise exception 'Ranking, distinct counts, date bounds, status filters or zero categories failed: %', r;
  end if;
  if (r->>'window_end')::timestamptz - (r->>'window_start')::timestamptz <> interval '30 days'
    or r->>'generated_at' <> r->>'window_end' then
    raise exception 'Invalid report period';
  end if;
  if r::text like '%user_id%' or r::text like '%10000000%' then
    raise exception 'Report leaked participant identities';
  end if;
end $$;
reset role;

-- Empty results and revoked access.
delete from public.quest_completions;
set local role authenticated;
do $$ declare r jsonb; begin
  r := public.get_category_engagement();
  if exists (select 1 from jsonb_array_elements(r->'categories') c
    where (c->>'completed_quests')::int <> 0 or (c->>'unique_participants')::int <> 0) then
    raise exception 'Empty report contains activity';
  end if;
end $$;
reset role;
update public.users set is_business = false where id = '10000000-0000-0000-0000-000000000001';
set local role authenticated;
do $$ begin
  begin
    perform public.get_category_engagement();
    raise exception 'Revoked account read report';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub', '', true);
set local role authenticated;
do $$ begin
  begin
    perform public.get_category_engagement();
    raise exception 'Missing identity read report';
  exception when insufficient_privilege then null; end;
  begin
    perform public.activate_business_access('bq12-local-test-code-only');
    raise exception 'Missing identity activated';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role anon;
do $$ begin
  begin
    perform public.get_category_engagement();
    raise exception 'Anonymous report access';
  exception when insufficient_privilege then null; end;
  begin
    perform public.activate_business_access('bq12-local-test-code-only');
    raise exception 'Anonymous activation';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
\echo 'BQ12 integration assertions passed'
