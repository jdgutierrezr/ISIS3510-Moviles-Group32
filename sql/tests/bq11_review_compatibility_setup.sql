-- Local-only pre-existing quest/review state for seed non-interference tests.
alter table auth.users add column if not exists email text;
insert into auth.users(id,email) values
('11111111-1111-1111-1111-111111111111','valentina.gomez@example.com');
insert into public.users(id,name,email,current_xp,current_streak) values
('11111111-1111-1111-1111-111111111111','Valentina Gomez','valentina.gomez@example.com',100,7);
insert into public.places(id,name,latitude,longitude,average_rating) values
('a1111111-0000-0000-0000-000000000001','Existing place',4.61,-74.08,4.5);
insert into public.quests(id,place_id,title,points_reward) values
('b1111111-0000-0000-0000-000000000001','a1111111-0000-0000-0000-000000000001','Existing active quest',60),
('b1111111-0000-0000-0000-000000000002','a1111111-0000-0000-0000-000000000001','Existing reviewed quest',60),
('b1111111-0000-0000-0000-000000000003','a1111111-0000-0000-0000-000000000001','Existing startable quest',60);
insert into public.quest_objectives(id,quest_id,title,requires_photo,order_index) values
('b2222222-0000-0000-0000-000000000011','b1111111-0000-0000-0000-000000000001','First step',false,1),
('b2222222-0000-0000-0000-000000000012','b1111111-0000-0000-0000-000000000001','Photo step',true,2),
('b2222222-0000-0000-0000-000000000031','b1111111-0000-0000-0000-000000000003','Startable step',false,1);
insert into public.quest_completions(id,user_id,quest_id,status,completed_at) values
('d1111111-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','b1111111-0000-0000-0000-000000000001','pending',null),
('d1111111-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','b1111111-0000-0000-0000-000000000002','completed',now()-interval '1 day');
insert into public.quest_objective_completions(completion_id,objective_id) values
('d1111111-0000-0000-0000-000000000001','b2222222-0000-0000-0000-000000000011');
insert into storage.objects(bucket_id,name) values
('review-photos','11111111-1111-1111-1111-111111111111/b1111111-0000-0000-0000-000000000002/existing.jpg');
insert into public.quest_reviews(user_id,quest_id,place_id,rating,notes,accuracy,photo_paths) values
('11111111-1111-1111-1111-111111111111','b1111111-0000-0000-0000-000000000002',
 'a1111111-0000-0000-0000-000000000001',5,'Keep my review','spotOn',
 array['11111111-1111-1111-1111-111111111111/b1111111-0000-0000-0000-000000000002/existing.jpg']);
-- JSON snapshots capture every original row field, including timestamps/photos.
create function public.bq11_test_snapshot() returns jsonb language sql as $$
 select jsonb_build_object(
  'user',(select to_jsonb(u) from public.users u where id='11111111-1111-1111-1111-111111111111'),
  'place',(select to_jsonb(p) from public.places p where id='a1111111-0000-0000-0000-000000000001'),
  'quests',(select jsonb_agg(to_jsonb(q) order by q.id) from public.quests q where q.id::text like 'b1111111-%'),
  'objectives',(select jsonb_agg(to_jsonb(o) order by o.id) from public.quest_objectives o where o.id::text like 'b2222222-%'),
  'completions',(select jsonb_agg(to_jsonb(c) order by c.id) from public.quest_completions c where c.user_id='11111111-1111-1111-1111-111111111111'),
  'checked',(select jsonb_agg(to_jsonb(o) order by o.objective_id) from public.quest_objective_completions o join public.quest_completions c on c.id=o.completion_id where c.user_id='11111111-1111-1111-1111-111111111111'),
  'reviews',(select jsonb_agg(to_jsonb(r) order by r.id) from public.quest_reviews r where r.user_id='11111111-1111-1111-1111-111111111111'),
  'photos',(select jsonb_agg(to_jsonb(o) order by o.id) from storage.objects o)
 );
$$;
create table public.bq11_test_before(data jsonb);
insert into public.bq11_test_before select public.bq11_test_snapshot();
