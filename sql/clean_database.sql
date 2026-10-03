-- ============================================
-- Wandr App - Clean database
-- Supabase / PostgreSQL
-- Drops every table and enum (schema must be recreated afterwards)
-- ============================================

-- Storage policies (the bucket and its files stay: Supabase only lets you delete them from the dashboard)
drop policy if exists "quest-photos: upload own" on storage.objects;
drop policy if exists "quest-photos: read own" on storage.objects;
drop policy if exists "quest-photos: replace own" on storage.objects;
drop policy if exists "quest-photos: delete own" on storage.objects;

drop table if exists
  telemetry_events,
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
  neighborhoods,
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
  public.friends_on_map(),
  public.neighborhood_quest_activity(integer)
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
