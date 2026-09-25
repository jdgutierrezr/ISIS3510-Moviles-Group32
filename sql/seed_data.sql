-- ============================================
-- Wandr App - Seed data (mock)
-- Supabase / PostgreSQL
-- Data themed around Bogota, Colombia
-- ============================================

-- ============================================
-- Auth users (Supabase Auth)
-- Password for every seed user: password123
-- ============================================

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at) values
('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'valentina.gomez@example.com', extensions.crypt('password123', extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'santiago.ramirez@example.com', extensions.crypt('password123', extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
('00000000-0000-0000-0000-000000000000', '33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'camila.torres@example.com', extensions.crypt('password123', extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
('00000000-0000-0000-0000-000000000000', '44444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated', 'juan.suarez@example.com', extensions.crypt('password123', extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;

-- ============================================
-- Users (profiles)
-- ============================================

insert into users (id, name, email, profile_picture, current_xp, level, current_streak, tier, energy_level) values
('11111111-1111-1111-1111-111111111111', 'Valentina Gomez', 'valentina.gomez@example.com', 'https://example.com/avatars/valentina.png', 1250, 8, 5, 'trailblazer', 'active'),
('22222222-2222-2222-2222-222222222222', 'Santiago Ramirez', 'santiago.ramirez@example.com', 'https://example.com/avatars/santiago.png', 420, 3, 2, 'bogota_scout', 'relaxed'),
('33333333-3333-3333-3333-333333333333', 'Camila Torres', 'camila.torres@example.com', 'https://example.com/avatars/camila.png', 2800, 14, 12, 'pathfinder', 'active'),
('44444444-4444-4444-4444-444444444444', 'Juan David Suarez', 'juan.suarez@example.com', null, 60, 1, 1, 'bogota_scout', null);

-- ============================================
-- Places
-- ============================================

insert into places (id, name, category, address, latitude, longitude, average_rating, cover_image_url) values
('a1111111-0000-0000-0000-000000000001', 'Parque Simon Bolivar', 'park', 'Calle 63 #68-95, Bogota', 4.6579, -74.0940, 4.7, 'https://example.com/places/simon_bolivar.jpg'),
('a1111111-0000-0000-0000-000000000002', 'Andres Carne de Res', 'bar', 'Calle 3 #11a-56, Chia', 4.8623, -74.0339, 4.5, 'https://example.com/places/andres_carne_de_res.jpg'),
('a1111111-0000-0000-0000-000000000003', 'Museo del Oro', 'museum', 'Carrera 6 #15-88, La Candelaria', 4.6015, -74.0721, 4.8, 'https://example.com/places/museo_del_oro.jpg'),
('a1111111-0000-0000-0000-000000000004', 'La Puerta Falsa', 'restaurant', 'Calle 11 #6-50, La Candelaria', 4.5972, -74.0745, 4.6, 'https://example.com/places/puerta_falsa.jpg'),
('a1111111-0000-0000-0000-000000000005', 'Festival Jazz al Parque', 'event', 'Parque El Country, Bogota', 4.6690, -74.0530, 4.7, 'https://example.com/places/jazz_al_parque.jpg'),
('a1111111-0000-0000-0000-000000000006', 'Comuna 13 Grafiti Tour', 'culture', 'Carrera 5 #10-30, La Candelaria', 4.5964, -74.0759, 4.9, 'https://example.com/places/grafiti_tour.jpg'),
('a1111111-0000-0000-0000-000000000007', 'Cerro de Monserrate', 'outdoors', 'Carrera 2 Este #21-48, Bogota', 4.6053, -74.0555, 4.6, 'https://example.com/places/monserrate.jpg');

-- ============================================
-- Quests
-- ============================================

insert into quests (id, place_id, title, description, difficulty_level, estimated_duration, points_reward, cover_image_url) values
('b1111111-0000-0000-0000-000000000001', 'a1111111-0000-0000-0000-000000000001', 'Morning run in Simon Bolivar', 'Complete a 3km run through Parque Simon Bolivar before 9am', 2, 30, 50, 'https://example.com/quests/1.jpg'),
('b1111111-0000-0000-0000-000000000002', 'a1111111-0000-0000-0000-000000000002', 'Dance the night away', 'Order a drink and dance at least one song at Andres Carne de Res', 1, 20, 20, 'https://example.com/quests/2.jpg'),
('b1111111-0000-0000-0000-000000000003', 'a1111111-0000-0000-0000-000000000003', 'Discover pre-Columbian gold', 'Visit the main exhibit at the Museo del Oro', 2, 60, 40, 'https://example.com/quests/3.jpg'),
('b1111111-0000-0000-0000-000000000004', 'a1111111-0000-0000-0000-000000000004', 'Try a traditional tamal', 'Have breakfast with a buddy from the app at La Puerta Falsa', 1, 45, 30, 'https://example.com/quests/4.jpg'),
('b1111111-0000-0000-0000-000000000005', 'a1111111-0000-0000-0000-000000000005', 'Catch a live set', 'Attend at least one performance at Jazz al Parque', 3, 90, 70, 'https://example.com/quests/5.jpg'),
('b1111111-0000-0000-0000-000000000006', 'a1111111-0000-0000-0000-000000000006', 'Street art scavenger hunt', 'Find and photograph 3 murals on the Comuna 13 Grafiti Tour', 3, 50, 60, 'https://example.com/quests/6.jpg'),
('b1111111-0000-0000-0000-000000000007', 'a1111111-0000-0000-0000-000000000007', 'Climb Monserrate', 'Reach the top of Cerro de Monserrate on foot', 4, 120, 90, 'https://example.com/quests/7.jpg');

-- ============================================
-- QuestObjectives
-- ============================================

insert into quest_objectives (id, quest_id, title, requires_photo, order_index) values
('b2222222-0000-0000-0000-000000000011', 'b1111111-0000-0000-0000-000000000001', 'Arrive at Parque Simon Bolivar', false, 1),
('b2222222-0000-0000-0000-000000000012', 'b1111111-0000-0000-0000-000000000001', 'Run 3km around the lake', false, 2),
('b2222222-0000-0000-0000-000000000013', 'b1111111-0000-0000-0000-000000000001', 'Take a photo at the finish line', true, 3),
('b2222222-0000-0000-0000-000000000021', 'b1111111-0000-0000-0000-000000000002', 'Arrive at Andres Carne de Res', false, 1),
('b2222222-0000-0000-0000-000000000022', 'b1111111-0000-0000-0000-000000000002', 'Order a signature drink', false, 2),
('b2222222-0000-0000-0000-000000000023', 'b1111111-0000-0000-0000-000000000002', 'Take a photo on the dance floor', true, 3),
('b2222222-0000-0000-0000-000000000031', 'b1111111-0000-0000-0000-000000000003', 'Arrive at Museo del Oro', false, 1),
('b2222222-0000-0000-0000-000000000032', 'b1111111-0000-0000-0000-000000000003', 'Visit the main exhibit', false, 2),
('b2222222-0000-0000-0000-000000000033', 'b1111111-0000-0000-0000-000000000003', 'Take a photo of the Balsa Muisca', true, 3),
('b2222222-0000-0000-0000-000000000041', 'b1111111-0000-0000-0000-000000000004', 'Arrive at La Puerta Falsa', false, 1),
('b2222222-0000-0000-0000-000000000042', 'b1111111-0000-0000-0000-000000000004', 'Order a tamal with hot chocolate', false, 2),
('b2222222-0000-0000-0000-000000000043', 'b1111111-0000-0000-0000-000000000004', 'Take a photo with your buddy', true, 3),
('b2222222-0000-0000-0000-000000000051', 'b1111111-0000-0000-0000-000000000005', 'Arrive at Parque El Country', false, 1),
('b2222222-0000-0000-0000-000000000052', 'b1111111-0000-0000-0000-000000000005', 'Watch a full performance', false, 2),
('b2222222-0000-0000-0000-000000000053', 'b1111111-0000-0000-0000-000000000005', 'Take a photo of the stage', true, 3),
('b2222222-0000-0000-0000-000000000061', 'b1111111-0000-0000-0000-000000000006', 'Meet the tour at the starting point', false, 1),
('b2222222-0000-0000-0000-000000000062', 'b1111111-0000-0000-0000-000000000006', 'Find 3 murals along the route', false, 2),
('b2222222-0000-0000-0000-000000000063', 'b1111111-0000-0000-0000-000000000006', 'Take a photo of your favorite mural', true, 3),
('b2222222-0000-0000-0000-000000000071', 'b1111111-0000-0000-0000-000000000007', 'Start the trail at the base', false, 1),
('b2222222-0000-0000-0000-000000000072', 'b1111111-0000-0000-0000-000000000007', 'Reach the summit', false, 2),
('b2222222-0000-0000-0000-000000000073', 'b1111111-0000-0000-0000-000000000007', 'Take a photo of the city from the top', true, 3);

-- ============================================
-- Tags
-- ============================================

insert into tags (id, name) values
('c1111111-0000-0000-0000-000000000001', 'outdoors'),
('c1111111-0000-0000-0000-000000000002', 'social'),
('c1111111-0000-0000-0000-000000000003', 'food'),
('c1111111-0000-0000-0000-000000000004', 'culture'),
('c1111111-0000-0000-0000-000000000005', 'nightlife'),
('c1111111-0000-0000-0000-000000000006', 'fitness'),
('c1111111-0000-0000-0000-000000000007', 'music');

-- ============================================
-- QuestTags
-- ============================================

insert into quest_tags (quest_id, tag_id) values
('b1111111-0000-0000-0000-000000000001', 'c1111111-0000-0000-0000-000000000001'),
('b1111111-0000-0000-0000-000000000001', 'c1111111-0000-0000-0000-000000000006'),
('b1111111-0000-0000-0000-000000000002', 'c1111111-0000-0000-0000-000000000005'),
('b1111111-0000-0000-0000-000000000002', 'c1111111-0000-0000-0000-000000000002'),
('b1111111-0000-0000-0000-000000000003', 'c1111111-0000-0000-0000-000000000004'),
('b1111111-0000-0000-0000-000000000004', 'c1111111-0000-0000-0000-000000000003'),
('b1111111-0000-0000-0000-000000000004', 'c1111111-0000-0000-0000-000000000002'),
('b1111111-0000-0000-0000-000000000005', 'c1111111-0000-0000-0000-000000000007'),
('b1111111-0000-0000-0000-000000000005', 'c1111111-0000-0000-0000-000000000002'),
('b1111111-0000-0000-0000-000000000006', 'c1111111-0000-0000-0000-000000000004'),
('b1111111-0000-0000-0000-000000000007', 'c1111111-0000-0000-0000-000000000001'),
('b1111111-0000-0000-0000-000000000007', 'c1111111-0000-0000-0000-000000000006');

-- ============================================
-- UserInterests
-- ============================================

insert into user_interests (user_id, tag_id) values
('11111111-1111-1111-1111-111111111111', 'c1111111-0000-0000-0000-000000000001'),
('11111111-1111-1111-1111-111111111111', 'c1111111-0000-0000-0000-000000000004'),
('11111111-1111-1111-1111-111111111111', 'c1111111-0000-0000-0000-000000000006'),
('22222222-2222-2222-2222-222222222222', 'c1111111-0000-0000-0000-000000000005'),
('22222222-2222-2222-2222-222222222222', 'c1111111-0000-0000-0000-000000000007'),
('33333333-3333-3333-3333-333333333333', 'c1111111-0000-0000-0000-000000000002'),
('33333333-3333-3333-3333-333333333333', 'c1111111-0000-0000-0000-000000000003'),
('33333333-3333-3333-3333-333333333333', 'c1111111-0000-0000-0000-000000000007'),
('44444444-4444-4444-4444-444444444444', 'c1111111-0000-0000-0000-000000000004');

-- ============================================
-- QuestCompletions
-- ============================================

insert into quest_completions (id, user_id, quest_id, status, completed_at) values
('d1111111-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'b1111111-0000-0000-0000-000000000001', 'completed', now() - interval '5 days'),
('d1111111-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'b1111111-0000-0000-0000-000000000003', 'completed', now() - interval '3 days'),
('d1111111-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'b1111111-0000-0000-0000-000000000002', 'completed', now() - interval '2 days'),
('d1111111-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222', 'b1111111-0000-0000-0000-000000000007', 'pending', null),
('d1111111-0000-0000-0000-000000000005', '33333333-3333-3333-3333-333333333333', 'b1111111-0000-0000-0000-000000000004', 'completed', now() - interval '1 day'),
('d1111111-0000-0000-0000-000000000006', '33333333-3333-3333-3333-333333333333', 'b1111111-0000-0000-0000-000000000005', 'abandoned', null),
('d1111111-0000-0000-0000-000000000007', '44444444-4444-4444-4444-444444444444', 'b1111111-0000-0000-0000-000000000006', 'completed', now() - interval '6 hours');

-- ============================================
-- QuestObjectiveCompletions
-- ============================================

insert into quest_objective_completions (completion_id, objective_id, proof_photo, completed_at) values
-- Valentina: Morning run (completed)
('d1111111-0000-0000-0000-000000000001', 'b2222222-0000-0000-0000-000000000011', null, now() - interval '5 days 1 hour'),
('d1111111-0000-0000-0000-000000000001', 'b2222222-0000-0000-0000-000000000012', null, now() - interval '5 days 20 minutes'),
('d1111111-0000-0000-0000-000000000001', 'b2222222-0000-0000-0000-000000000013', 'https://example.com/proof/1.jpg', now() - interval '5 days'),
-- Valentina: Museo del Oro (completed)
('d1111111-0000-0000-0000-000000000002', 'b2222222-0000-0000-0000-000000000031', null, now() - interval '3 days 1 hour'),
('d1111111-0000-0000-0000-000000000002', 'b2222222-0000-0000-0000-000000000032', null, now() - interval '3 days 10 minutes'),
('d1111111-0000-0000-0000-000000000002', 'b2222222-0000-0000-0000-000000000033', 'https://example.com/proof/2.jpg', now() - interval '3 days'),
-- Santiago: Andres Carne de Res (completed)
('d1111111-0000-0000-0000-000000000003', 'b2222222-0000-0000-0000-000000000021', null, now() - interval '2 days 30 minutes'),
('d1111111-0000-0000-0000-000000000003', 'b2222222-0000-0000-0000-000000000022', null, now() - interval '2 days 15 minutes'),
('d1111111-0000-0000-0000-000000000003', 'b2222222-0000-0000-0000-000000000023', 'https://example.com/proof/5.jpg', now() - interval '2 days'),
-- Santiago: Monserrate (pending, 1 of 3)
('d1111111-0000-0000-0000-000000000004', 'b2222222-0000-0000-0000-000000000071', null, now() - interval '30 minutes'),
-- Camila: La Puerta Falsa (completed)
('d1111111-0000-0000-0000-000000000005', 'b2222222-0000-0000-0000-000000000041', null, now() - interval '1 day 45 minutes'),
('d1111111-0000-0000-0000-000000000005', 'b2222222-0000-0000-0000-000000000042', null, now() - interval '1 day 20 minutes'),
('d1111111-0000-0000-0000-000000000005', 'b2222222-0000-0000-0000-000000000043', 'https://example.com/proof/3.jpg', now() - interval '1 day'),
-- Camila: Jazz al Parque (abandoned, 1 of 3)
('d1111111-0000-0000-0000-000000000006', 'b2222222-0000-0000-0000-000000000051', null, now() - interval '4 days'),
-- Juan David: Grafiti Tour (completed)
('d1111111-0000-0000-0000-000000000007', 'b2222222-0000-0000-0000-000000000061', null, now() - interval '7 hours'),
('d1111111-0000-0000-0000-000000000007', 'b2222222-0000-0000-0000-000000000062', null, now() - interval '6 hours 20 minutes'),
('d1111111-0000-0000-0000-000000000007', 'b2222222-0000-0000-0000-000000000063', 'https://example.com/proof/4.jpg', now() - interval '6 hours');

-- ============================================
-- Badges
-- ============================================

insert into badges (id, name, description, criteria, icon_url) values
('e1111111-0000-0000-0000-000000000001', 'First steps', 'Complete your first quest', '{"quests_completed": 1}', 'https://example.com/badges/first_steps.png'),
('e1111111-0000-0000-0000-000000000002', 'Explorer', 'Complete 10 quests', '{"quests_completed": 10}', 'https://example.com/badges/explorer.png'),
('e1111111-0000-0000-0000-000000000003', 'Early bird', 'Complete a quest before 8am', '{"completions_before_hour": 8}', 'https://example.com/badges/early_bird.png'),
('e1111111-0000-0000-0000-000000000004', 'Social butterfly', 'Complete 5 quests with tag social', '{"tag": "social", "quests_completed": 5}', 'https://example.com/badges/social_butterfly.png');

-- ============================================
-- UserBadges
-- ============================================

insert into user_badges (user_id, badge_id, earned_at) values
('11111111-1111-1111-1111-111111111111', 'e1111111-0000-0000-0000-000000000001', now() - interval '5 days'),
('22222222-2222-2222-2222-222222222222', 'e1111111-0000-0000-0000-000000000001', now() - interval '2 days'),
('33333333-3333-3333-3333-333333333333', 'e1111111-0000-0000-0000-000000000001', now() - interval '1 day'),
('44444444-4444-4444-4444-444444444444', 'e1111111-0000-0000-0000-000000000001', now() - interval '6 hours');

-- ============================================
-- Friendships
-- ============================================

insert into friendships (id, user_id_1, user_id_2, status) values
('f1111111-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'accepted'),
('f1111111-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'accepted'),
('f1111111-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444', 'pending'),
('f1111111-0000-0000-0000-000000000004', '33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444', 'blocked');

-- ============================================
-- Notifications
-- ============================================

insert into notifications (id, user_id, type, content, read_status) values
('11111112-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'unlocked_badge', 'You earned the First steps badge', true),
('11111112-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'nearby_new_quest', 'A new quest is available at Parque Simon Bolivar', false),
('11111112-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'friend_request', 'Juan David Suarez sent you a friend request', false),
('11111112-0000-0000-0000-000000000004', '33333333-3333-3333-3333-333333333333', 'completed_friend_quest', 'Valentina Gomez completed Discover pre-Columbian gold', true),
('11111112-0000-0000-0000-000000000005', '44444444-4444-4444-4444-444444444444', 'unlocked_badge', 'You earned the First steps badge', false),
('11111112-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111', 'event_reminder', 'Salsa in the Park starts tomorrow at 4pm', false);

-- ============================================
-- UserLocations
-- ============================================

insert into user_locations (user_id, latitude, longitude, is_broadcasting, updated_at) values
('11111111-1111-1111-1111-111111111111', 4.6012, -74.0716, true, now() - interval '2 minutes'),
('22222222-2222-2222-2222-222222222222', 4.6050, -74.0570, true, now() - interval '5 minutes'),
('33333333-3333-3333-3333-333333333333', 4.6021, -74.0730, false, now() - interval '3 hours'),
('44444444-4444-4444-4444-444444444444', 4.5968, -74.0752, true, now() - interval '1 minute');

-- ============================================
-- Events
-- ============================================

insert into events (id, place_id, title, description, cover_image_url, starts_at, ends_at, capacity) values
('a2222222-0000-0000-0000-000000000001', 'a1111111-0000-0000-0000-000000000001', 'Salsa in the Park', 'Free open-air salsa class for all levels', 'https://example.com/events/salsa.jpg', now() + interval '1 day', now() + interval '1 day 3 hours', 100),
('a2222222-0000-0000-0000-000000000002', 'a1111111-0000-0000-0000-000000000003', 'Night at the Museo del Oro', 'Guided night tour through the gold collection', 'https://example.com/events/museo_night.jpg', now() + interval '3 days', now() + interval '3 days 2 hours', 30),
('a2222222-0000-0000-0000-000000000003', 'a1111111-0000-0000-0000-000000000007', 'Sunrise hike to Monserrate', 'Group hike to catch the sunrise over Bogota', 'https://example.com/events/sunrise_hike.jpg', now() + interval '5 days', now() + interval '5 days 4 hours', null),
('a2222222-0000-0000-0000-000000000004', null, 'Candelaria food crawl', 'Taste traditional dishes around La Candelaria', 'https://example.com/events/food_crawl.jpg', now() - interval '2 days', now() - interval '2 days' + interval '3 hours', 20);

-- ============================================
-- EventAttendees
-- ============================================

insert into event_attendees (event_id, user_id, joined_at) values
('a2222222-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', now() - interval '1 day'),
('a2222222-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', now() - interval '12 hours'),
('a2222222-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', now() - interval '3 hours'),
('a2222222-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', now() - interval '2 days'),
('a2222222-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', now() - interval '6 hours'),
('a2222222-0000-0000-0000-000000000004', '33333333-3333-3333-3333-333333333333', now() - interval '5 days'),
('a2222222-0000-0000-0000-000000000004', '44444444-4444-4444-4444-444444444444', now() - interval '4 days');
