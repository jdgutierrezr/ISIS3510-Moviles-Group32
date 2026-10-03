-- Optional BQ11 visualization data for the seeded demo project only.
-- Run after bq11.sql in the demo project. The base seed is optional.
-- Do not rerun seed_data.sql on an existing project. These labeled demo neighborhoods are synthetic groupings,
-- not verified geographic boundaries or production partnership evidence.
-- Reruns preserve existing completions, reviews and dates; no XP is awarded.
begin;

-- Dedicated analytics identities have no sign-in credentials. Existing demo
-- accounts are not given extra completions, objectives, XP or streak changes.
do $$ begin
  if exists(select 1 from auth.users where id in (
    'e1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000002',
    'e1000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000004') and email is not null)
  or exists(select 1 from public.users where id in (
    'e1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000002',
    'e1000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000004')
    and (name not like 'BQ11 Demo %' or email not like 'analytics-%@bq11-demo.invalid')) then
    raise exception 'BQ11 demo identity IDs conflict with existing users. No demo data was added.';
  end if;
end $$;
insert into auth.users(id) values
('e1000000-0000-0000-0000-000000000001'),('e1000000-0000-0000-0000-000000000002'),
('e1000000-0000-0000-0000-000000000003'),('e1000000-0000-0000-0000-000000000004')
on conflict(id) do nothing;
insert into public.users(id,name,email) values
('e1000000-0000-0000-0000-000000000001','BQ11 Demo 1','analytics-1@bq11-demo.invalid'),
('e1000000-0000-0000-0000-000000000002','BQ11 Demo 2','analytics-2@bq11-demo.invalid'),
('e1000000-0000-0000-0000-000000000003','BQ11 Demo 3','analytics-3@bq11-demo.invalid'),
('e1000000-0000-0000-0000-000000000004','BQ11 Demo 4','analytics-4@bq11-demo.invalid')
on conflict(id) do nothing;

-- Coordinates place the demo markers within the discovery map around Bogotá.
insert into public.neighborhoods(id,name,city,latitude,longitude) values
('e1100000-0000-0000-0000-000000000001','Demo · Barrio Norte','Bogotá',4.6220,-74.0690),
('e1100000-0000-0000-0000-000000000002','Demo · Barrio Centro','Bogotá',4.6097,-74.0817),
('e1100000-0000-0000-0000-000000000003','Demo · Barrio Sur','Bogotá',4.5960,-74.0760),
('e1100000-0000-0000-0000-000000000004','Demo · Barrio Oeste','Bogotá',4.6090,-74.0990)
on conflict(id) do nothing;

insert into public.places(id,name,category,address,latitude,longitude,neighborhood_id) values
('e1200000-0000-0000-0000-000000000001','Demo · Café del Norte','restaurant','Synthetic demo location',4.6220,-74.0690,'e1100000-0000-0000-0000-000000000001'),
('e1200000-0000-0000-0000-000000000002','Demo · Galería Norte','culture','Synthetic demo location',4.6230,-74.0700,'e1100000-0000-0000-0000-000000000001'),
('e1200000-0000-0000-0000-000000000003','Demo · Mercado Central','restaurant','Synthetic demo location',4.6097,-74.0817,'e1100000-0000-0000-0000-000000000002'),
('e1200000-0000-0000-0000-000000000004','Demo · Parque Central','park','Synthetic demo location',4.6105,-74.0820,'e1100000-0000-0000-0000-000000000002'),
('e1200000-0000-0000-0000-000000000005','Demo · Taller del Sur','culture','Synthetic demo location',4.5960,-74.0760,'e1100000-0000-0000-0000-000000000003'),
('e1200000-0000-0000-0000-000000000006','Demo · Jardín del Oeste','park','Synthetic demo location',4.6090,-74.0990,'e1100000-0000-0000-0000-000000000004')
on conflict(id) do nothing;

insert into public.quests(id,place_id,title,description,difficulty_level,estimated_duration,points_reward) values
('e1300000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','Demo · Discover northern coffee','BQ11 demo quest at Café del Norte.',1,20,30),
('e1300000-0000-0000-0000-000000000002','e1200000-0000-0000-0000-000000000002','Demo · Explore northern art','BQ11 demo quest at Galería Norte.',1,30,40),
('e1300000-0000-0000-0000-000000000003','e1200000-0000-0000-0000-000000000003','Demo · Taste the central market','BQ11 demo quest at Mercado Central.',1,25,30),
('e1300000-0000-0000-0000-000000000004','e1200000-0000-0000-0000-000000000004','Demo · Walk through the central park','BQ11 demo quest at Parque Central.',1,20,30),
('e1300000-0000-0000-0000-000000000005','e1200000-0000-0000-0000-000000000005','Demo · Visit a southern workshop','BQ11 demo quest at Taller del Sur.',1,30,40),
('e1300000-0000-0000-0000-000000000006','e1200000-0000-0000-0000-000000000006','Demo · Discover the western garden','BQ11 demo quest with zero recent completions.',1,20,30)
on conflict(id) do nothing;

-- Each quest can also be started/completed normally in the app by a demo user
-- who has not already completed it. No pending quest is created by this seed.
insert into public.quest_objectives(id,quest_id,title,requires_photo,order_index)
select ('e1400000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid,
       ('e1300000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid,
       'Visit the demo place and explore', false, 1
from generate_series(1,6) i
on conflict(id) do nothing;

-- Refuse collisions in the reserved demo IDs rather than attaching activity to
-- an unrelated catalog record. Existing normal catalog rows are never updated.
do $$ begin
  if exists (
    select 1 from generate_series(1,6) i
    join public.quests q on q.id = ('e1300000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid
    join public.places p on p.id = ('e1200000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid
    join public.quest_objectives o on o.id = ('e1400000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid
    where q.place_id <> p.id or q.title not like 'Demo · %'
      or p.name not like 'Demo · %' or o.quest_id <> q.id
      or p.neighborhood_id is distinct from ('e1100000-0000-0000-0000-' || lpad(
        (case when i <= 2 then 1 when i <= 4 then 2 when i = 5 then 3 else 4 end)::text,12,'0'))::uuid
  ) or exists (
    select 1 from public.neighborhoods
    where id in (
      'e1100000-0000-0000-0000-000000000001', 'e1100000-0000-0000-0000-000000000002',
      'e1100000-0000-0000-0000-000000000003', 'e1100000-0000-0000-0000-000000000004')
      and (name not like 'Demo · %' or city <> 'Bogotá')
  ) then
    raise exception 'BQ11 demo catalog IDs conflict with existing data. Seed transaction rolled back.';
  end if;
end $$;

-- North: 8 participations / 4 distinct users / 2 places.
-- Center: 4 participations / 3 distinct users / 2 places.
-- South: 2 participations / 2 distinct users / 1 place. West: 0.
with participants(user_id,quest_number,days_ago) as (values
('e1000000-0000-0000-0000-000000000001'::uuid,1,1),
('e1000000-0000-0000-0000-000000000002'::uuid,1,2),
('e1000000-0000-0000-0000-000000000003'::uuid,1,3),
('e1000000-0000-0000-0000-000000000004'::uuid,1,4),
('e1000000-0000-0000-0000-000000000001'::uuid,2,5),
('e1000000-0000-0000-0000-000000000002'::uuid,2,6),
('e1000000-0000-0000-0000-000000000003'::uuid,2,7),
('e1000000-0000-0000-0000-000000000004'::uuid,2,8),
('e1000000-0000-0000-0000-000000000001'::uuid,3,2),
('e1000000-0000-0000-0000-000000000002'::uuid,3,3),
('e1000000-0000-0000-0000-000000000002'::uuid,4,4),
('e1000000-0000-0000-0000-000000000003'::uuid,4,5),
('e1000000-0000-0000-0000-000000000001'::uuid,5,6),
('e1000000-0000-0000-0000-000000000004'::uuid,5,7)
)
insert into public.quest_completions(user_id,quest_id,status,completed_at,created_at)
select user_id, ('e1300000-0000-0000-0000-' || lpad(quest_number::text,12,'0'))::uuid,
       'completed', now() - make_interval(days => days_ago), now() - make_interval(days => days_ago)
from participants
on conflict(user_id,quest_id) do nothing;

-- Fully checked seeded completions, consistent with the app's objective view.
insert into public.quest_objective_completions(completion_id,objective_id,completed_at)
select c.id,o.id,c.completed_at
from public.quest_completions c
join public.quest_objectives o on o.quest_id=c.quest_id
where c.quest_id in (
  'e1300000-0000-0000-0000-000000000001', 'e1300000-0000-0000-0000-000000000002',
  'e1300000-0000-0000-0000-000000000003', 'e1300000-0000-0000-0000-000000000004',
  'e1300000-0000-0000-0000-000000000005')
  and c.user_id in (
    'e1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000002',
    'e1000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000004')
  and c.status='completed' and c.completed_at is not null
on conflict(completion_id,objective_id) do nothing;

commit;
