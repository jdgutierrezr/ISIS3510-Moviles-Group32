-- ============================================
-- Wandr App - Clean database
-- Supabase / PostgreSQL
-- Drops every table and enum (schema must be recreated afterwards)
-- ============================================

drop table if exists
  event_attendees,
  events,
  user_locations,
  user_interests,
  quest_objective_completions,
  quest_objectives,
  notifications,
  friendships,
  user_badges,
  badges,
  quest_completions,
  quest_tags,
  tags,
  quests,
  places,
  users
cascade;

drop function if exists
  public.are_friends(uuid, uuid),
  public.distance_km(double precision, double precision, double precision, double precision),
  public.award_badges(uuid),
  public.start_quest(uuid),
  public.complete_objective(uuid, uuid, text),
  public.abandon_quest(uuid),
  public.rsvp_event(uuid),
  public.send_friend_request(uuid),
  public.accept_friend_request(uuid),
  public.nearby_places(double precision, double precision, double precision, place_category),
  public.nearby_quests(double precision, double precision, double precision),
  public.friends_on_map()
cascade;

-- Remove seed users from Supabase Auth (real sign-ups are kept)
delete from auth.users where id in (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444'
);

drop type if exists
  place_category,
  quest_status,
  friendship_status,
  notification_type,
  user_tier,
  energy_level
cascade;
