-- ============================================
-- Wandr App - Row Level Security policies
-- Supabase / PostgreSQL
-- Run after schema_creation.sql
-- service_role and the SQL editor bypass these rules
-- ============================================

-- ============================================
-- Enable RLS (idempotent, in case the trigger did not run)
-- ============================================

alter table users enable row level security;
alter table places enable row level security;
alter table quests enable row level security;
alter table quest_objectives enable row level security;
alter table tags enable row level security;
alter table quest_tags enable row level security;
alter table quest_completions enable row level security;
alter table quest_objective_completions enable row level security;
alter table user_interests enable row level security;
alter table user_locations enable row level security;
alter table events enable row level security;
alter table event_attendees enable row level security;
alter table badges enable row level security;
alter table user_badges enable row level security;
alter table friendships enable row level security;
alter table notifications enable row level security;

-- ============================================
-- Helper: accepted friendship between two users
-- security definer so it can read friendships regardless of RLS
-- ============================================

create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from friendships
    where status = 'accepted'
      and ((user_id_1 = a and user_id_2 = b) or (user_id_1 = b and user_id_2 = a))
  );
$$;

-- ============================================
-- Users
-- ============================================

create policy "users: read all profiles" on users
  for select to authenticated using (true);

create policy "users: create own profile" on users
  for insert to authenticated with check (id = auth.uid());

create policy "users: update own profile" on users
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- ============================================
-- Public catalog (read only, written by service_role / admins)
-- ============================================

create policy "places: read" on places
  for select to authenticated using (true);

create policy "quests: read" on quests
  for select to authenticated using (true);

create policy "quest_objectives: read" on quest_objectives
  for select to authenticated using (true);

create policy "tags: read" on tags
  for select to authenticated using (true);

create policy "quest_tags: read" on quest_tags
  for select to authenticated using (true);

create policy "badges: read" on badges
  for select to authenticated using (true);

create policy "events: read" on events
  for select to authenticated using (true);

-- ============================================
-- QuestCompletions
-- ============================================

create policy "quest_completions: read own and friends" on quest_completions
  for select to authenticated
  using (user_id = auth.uid() or public.are_friends(auth.uid(), user_id));

create policy "quest_completions: insert own" on quest_completions
  for insert to authenticated with check (user_id = auth.uid());

create policy "quest_completions: update own" on quest_completions
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "quest_completions: delete own" on quest_completions
  for delete to authenticated using (user_id = auth.uid());

-- ============================================
-- QuestObjectiveCompletions (owned through quest_completions)
-- ============================================

create policy "quest_objective_completions: read own" on quest_objective_completions
  for select to authenticated
  using (exists (
    select 1 from quest_completions qc
    where qc.id = completion_id and qc.user_id = auth.uid()
  ));

create policy "quest_objective_completions: insert own" on quest_objective_completions
  for insert to authenticated
  with check (exists (
    select 1 from quest_completions qc
    where qc.id = completion_id and qc.user_id = auth.uid()
  ));

create policy "quest_objective_completions: delete own" on quest_objective_completions
  for delete to authenticated
  using (exists (
    select 1 from quest_completions qc
    where qc.id = completion_id and qc.user_id = auth.uid()
  ));

-- ============================================
-- UserInterests
-- ============================================

create policy "user_interests: read own" on user_interests
  for select to authenticated using (user_id = auth.uid());

create policy "user_interests: insert own" on user_interests
  for insert to authenticated with check (user_id = auth.uid());

create policy "user_interests: delete own" on user_interests
  for delete to authenticated using (user_id = auth.uid());

-- ============================================
-- UserLocations (friends only see it while broadcasting)
-- ============================================

create policy "user_locations: read own and broadcasting friends" on user_locations
  for select to authenticated
  using (
    user_id = auth.uid()
    or (is_broadcasting and public.are_friends(auth.uid(), user_id))
  );

create policy "user_locations: insert own" on user_locations
  for insert to authenticated with check (user_id = auth.uid());

create policy "user_locations: update own" on user_locations
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================
-- EventAttendees (RSVP)
-- ============================================

create policy "event_attendees: read" on event_attendees
  for select to authenticated using (true);

create policy "event_attendees: join" on event_attendees
  for insert to authenticated with check (user_id = auth.uid());

create policy "event_attendees: leave" on event_attendees
  for delete to authenticated using (user_id = auth.uid());

-- ============================================
-- UserBadges (awarded by the backend only)
-- ============================================

create policy "user_badges: read" on user_badges
  for select to authenticated using (true);

-- ============================================
-- Friendships
-- ============================================

create policy "friendships: read own" on friendships
  for select to authenticated
  using (auth.uid() in (user_id_1, user_id_2));

create policy "friendships: send request" on friendships
  for insert to authenticated
  with check (user_id_1 = auth.uid() and status = 'pending');

-- Anyone in the friendship can block; only the receiver (user_id_2) can accept
create policy "friendships: update own" on friendships
  for update to authenticated
  using (auth.uid() in (user_id_1, user_id_2))
  with check (
    status = 'blocked'
    or (status = 'accepted' and user_id_2 = auth.uid())
  );

create policy "friendships: delete own" on friendships
  for delete to authenticated
  using (auth.uid() in (user_id_1, user_id_2));

-- ============================================
-- Notifications (created by the backend only)
-- ============================================

create policy "notifications: read own" on notifications
  for select to authenticated using (user_id = auth.uid());

create policy "notifications: update own" on notifications
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "notifications: delete own" on notifications
  for delete to authenticated using (user_id = auth.uid());
