-- ============================================
-- Wandr App - Extra test quests around Universidad de los Andes and La Candelaria
-- Optional: run after seed_data.sql. Safe to run more than once.
-- Every quest has a quick arrival step and a photo step, to test proofs and the photo journal.
-- ============================================

insert into places (id, name, category, address, latitude, longitude, average_rating, cover_image_url) values
('a3333333-0000-0000-0000-000000000001', 'Quinta de Bolivar', 'museum', 'Calle 21 #4A-30 Este, Bogota', 4.6013, -74.0636, 4.6, null),
('a3333333-0000-0000-0000-000000000002', 'Museo Botero', 'museum', 'Calle 11 #4-41, La Candelaria', 4.5967, -74.0733, 4.8, null),
('a3333333-0000-0000-0000-000000000003', 'Plaza de Bolivar', 'culture', 'Carrera 7 #11-10, Bogota', 4.5981, -74.0760, 4.7, null),
('a3333333-0000-0000-0000-000000000004', 'Chorro de Quevedo', 'culture', 'Calle 13 #2-10, La Candelaria', 4.5966, -74.0693, 4.5, null),
('a3333333-0000-0000-0000-000000000005', 'Parque de los Periodistas', 'park', 'Avenida Jimenez #4-80, Bogota', 4.6036, -74.0700, 4.2, null),
('a3333333-0000-0000-0000-000000000006', 'Biblioteca Luis Angel Arango', 'culture', 'Calle 11 #4-14, La Candelaria', 4.5970, -74.0730, 4.8, null),
('a3333333-0000-0000-0000-000000000007', 'Museo Nacional de Colombia', 'museum', 'Carrera 7 #28-66, Bogota', 4.6155, -74.0687, 4.7, null),
('a3333333-0000-0000-0000-000000000008', 'Parque de la Independencia', 'park', 'Calle 26 #5-50, Bogota', 4.6130, -74.0688, 4.4, null),
('a3333333-0000-0000-0000-000000000009', 'Teatro Colon', 'event', 'Calle 10 #5-32, La Candelaria', 4.5966, -74.0749, 4.8, null),
('a3333333-0000-0000-0000-000000000010', 'Cafe de la Candelaria', 'restaurant', 'Calle 11 #2-89, La Candelaria', 4.5977, -74.0710, 4.5, null),
('a3333333-0000-0000-0000-000000000011', 'Mirador Torre Colpatria', 'outdoors', 'Carrera 7 #24-89, Bogota', 4.6106, -74.0703, 4.6, null),
('a3333333-0000-0000-0000-000000000012', 'Plaza de Mercado La Concordia', 'restaurant', 'Carrera 1 #12B-30, La Candelaria', 4.5994, -74.0681, 4.3, null)
on conflict (id) do nothing;

insert into quests (id, place_id, title, description, difficulty_level, estimated_duration, points_reward, cover_image_url) values
('b3333333-0000-0000-0000-000000000001', 'a3333333-0000-0000-0000-000000000001', 'Walk Bolivar''s gardens', 'Visit the house and gardens of the Quinta de Bolivar', 1, 40, 30, null),
('b3333333-0000-0000-0000-000000000002', 'a3333333-0000-0000-0000-000000000002', 'Find your favorite Botero', 'Walk the Museo Botero and pick the painting you like the most', 1, 45, 35, null),
('b3333333-0000-0000-0000-000000000003', 'a3333333-0000-0000-0000-000000000003', 'Pigeons and history', 'Stand in the middle of Plaza de Bolivar and look around the four buildings', 1, 20, 20, null),
('b3333333-0000-0000-0000-000000000004', 'a3333333-0000-0000-0000-000000000004', 'Where Bogota was born', 'Find the small square of Chorro de Quevedo and its street art', 1, 25, 25, null),
('b3333333-0000-0000-0000-000000000005', 'a3333333-0000-0000-0000-000000000005', 'A pause downtown', 'Sit for a while in Parque de los Periodistas', 1, 15, 15, null),
('b3333333-0000-0000-0000-000000000006', 'a3333333-0000-0000-0000-000000000006', 'Read in the big library', 'Find a quiet table at the Luis Angel Arango and read for a bit', 2, 60, 40, null),
('b3333333-0000-0000-0000-000000000007', 'a3333333-0000-0000-0000-000000000007', 'The old panopticon', 'Visit the Museo Nacional, which used to be a prison', 2, 60, 45, null),
('b3333333-0000-0000-0000-000000000008', 'a3333333-0000-0000-0000-000000000008', 'Green break on 26th', 'Walk through Parque de la Independencia and find the planetarium', 1, 30, 25, null),
('b3333333-0000-0000-0000-000000000009', 'a3333333-0000-0000-0000-000000000009', 'Behind the curtain', 'Visit the Teatro Colon or catch a show', 2, 90, 60, null),
('b3333333-0000-0000-0000-000000000010', 'a3333333-0000-0000-0000-000000000010', 'Coffee in La Candelaria', 'Order a Colombian coffee in a cafe of La Candelaria', 1, 30, 20, null),
('b3333333-0000-0000-0000-000000000011', 'a3333333-0000-0000-0000-000000000011', 'Bogota from above', 'Go up to the viewpoint of Torre Colpatria and look for Monserrate', 2, 45, 50, null),
('b3333333-0000-0000-0000-000000000012', 'a3333333-0000-0000-0000-000000000012', 'Try a local fruit', 'Buy a fruit you have never tried at La Concordia market', 1, 30, 25, null)
on conflict (id) do nothing;

insert into quest_objectives (id, quest_id, title, requires_photo, order_index) values
('b4444444-0000-0000-0000-000000000011', 'b3333333-0000-0000-0000-000000000001', 'Arrive at the Quinta de Bolivar', false, 1),
('b4444444-0000-0000-0000-000000000012', 'b3333333-0000-0000-0000-000000000001', 'Take a photo of the gardens', true, 2),
('b4444444-0000-0000-0000-000000000021', 'b3333333-0000-0000-0000-000000000002', 'Arrive at the Museo Botero', false, 1),
('b4444444-0000-0000-0000-000000000022', 'b3333333-0000-0000-0000-000000000002', 'Take a photo of your favorite painting', true, 2),
('b4444444-0000-0000-0000-000000000031', 'b3333333-0000-0000-0000-000000000003', 'Arrive at Plaza de Bolivar', false, 1),
('b4444444-0000-0000-0000-000000000032', 'b3333333-0000-0000-0000-000000000003', 'Take a photo of the Capitolio', true, 2),
('b4444444-0000-0000-0000-000000000041', 'b3333333-0000-0000-0000-000000000004', 'Arrive at Chorro de Quevedo', false, 1),
('b4444444-0000-0000-0000-000000000042', 'b3333333-0000-0000-0000-000000000004', 'Take a photo of a mural', true, 2),
('b4444444-0000-0000-0000-000000000051', 'b3333333-0000-0000-0000-000000000005', 'Take a photo of the park', true, 1),
('b4444444-0000-0000-0000-000000000061', 'b3333333-0000-0000-0000-000000000006', 'Arrive at the library', false, 1),
('b4444444-0000-0000-0000-000000000062', 'b3333333-0000-0000-0000-000000000006', 'Read for 20 minutes', false, 2),
('b4444444-0000-0000-0000-000000000063', 'b3333333-0000-0000-0000-000000000006', 'Take a photo of the book you read', true, 3),
('b4444444-0000-0000-0000-000000000071', 'b3333333-0000-0000-0000-000000000007', 'Arrive at the Museo Nacional', false, 1),
('b4444444-0000-0000-0000-000000000072', 'b3333333-0000-0000-0000-000000000007', 'Take a photo of the old cells', true, 2),
('b4444444-0000-0000-0000-000000000081', 'b3333333-0000-0000-0000-000000000008', 'Take a photo of the planetarium', true, 1),
('b4444444-0000-0000-0000-000000000091', 'b3333333-0000-0000-0000-000000000009', 'Arrive at the Teatro Colon', false, 1),
('b4444444-0000-0000-0000-000000000092', 'b3333333-0000-0000-0000-000000000009', 'Take a photo of the main hall', true, 2),
('b4444444-0000-0000-0000-000000000101', 'b3333333-0000-0000-0000-000000000010', 'Order a coffee', false, 1),
('b4444444-0000-0000-0000-000000000102', 'b3333333-0000-0000-0000-000000000010', 'Take a photo of your cup', true, 2),
('b4444444-0000-0000-0000-000000000111', 'b3333333-0000-0000-0000-000000000011', 'Go up to the viewpoint', false, 1),
('b4444444-0000-0000-0000-000000000112', 'b3333333-0000-0000-0000-000000000011', 'Take a photo of the city', true, 2),
('b4444444-0000-0000-0000-000000000121', 'b3333333-0000-0000-0000-000000000012', 'Buy a fruit you never tried', false, 1),
('b4444444-0000-0000-0000-000000000122', 'b3333333-0000-0000-0000-000000000012', 'Take a photo of the fruit', true, 2)
on conflict (id) do nothing;

-- tags already in seed_data.sql: 1 outdoors, 2 social, 3 food, 4 culture, 6 fitness, 7 music
insert into quest_tags (quest_id, tag_id) values
('b3333333-0000-0000-0000-000000000001', 'c1111111-0000-0000-0000-000000000004'),
('b3333333-0000-0000-0000-000000000002', 'c1111111-0000-0000-0000-000000000004'),
('b3333333-0000-0000-0000-000000000003', 'c1111111-0000-0000-0000-000000000004'),
('b3333333-0000-0000-0000-000000000004', 'c1111111-0000-0000-0000-000000000004'),
('b3333333-0000-0000-0000-000000000005', 'c1111111-0000-0000-0000-000000000001'),
('b3333333-0000-0000-0000-000000000006', 'c1111111-0000-0000-0000-000000000004'),
('b3333333-0000-0000-0000-000000000007', 'c1111111-0000-0000-0000-000000000004'),
('b3333333-0000-0000-0000-000000000008', 'c1111111-0000-0000-0000-000000000001'),
('b3333333-0000-0000-0000-000000000009', 'c1111111-0000-0000-0000-000000000007'),
('b3333333-0000-0000-0000-000000000010', 'c1111111-0000-0000-0000-000000000003'),
('b3333333-0000-0000-0000-000000000011', 'c1111111-0000-0000-0000-000000000001'),
('b3333333-0000-0000-0000-000000000012', 'c1111111-0000-0000-0000-000000000003')
on conflict do nothing;
