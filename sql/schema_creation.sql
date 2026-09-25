-- ============================================
-- Wandr App - Database schema
-- Supabase / PostgreSQL
-- ============================================

-- Extensión para generar UUIDs
create extension if not exists "pgcrypto";

-- ============================================
-- ENUMs
-- ============================================

create type place_category as enum (
  'park', 'bar', 'museum', 'restaurant', 'event', 'culture', 'outdoors', 'other'
);

create type quest_status as enum (
  'pending', 'completed', 'abandoned'
);

create type friendship_status as enum (
  'pending', 'accepted', 'blocked'
);

create type notification_type as enum (
  'event_reminder', 'nearby_new_quest', 'completed_friend_quest', 'unlocked_badge', 'friend_request'
);

create type user_tier as enum (
  'bogota_scout', 'trailblazer', 'pathfinder', 'master_pathfinder'
);

create type energy_level as enum (
  'relaxed', 'active'
);

-- ============================================
-- Users
-- ============================================

-- Profile linked 1:1 to Supabase Auth (auth.users). Credentials live in auth.users.
create table users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null unique,
  profile_picture text,
  current_xp integer not null default 0 check (current_xp >= 0),
  level integer not null default 1 check (level >= 1),
  current_streak integer not null default 0 check (current_streak >= 0),
  tier user_tier not null default 'bogota_scout',
  energy_level energy_level,
  created_at timestamptz not null default now()
);

-- ============================================
-- Places
-- ============================================

create table places (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category place_category not null default 'other',
  address text,
  latitude double precision not null,
  longitude double precision not null,
  average_rating numeric(2,1) default 0.0,
  cover_image_url text,
  created_at timestamptz not null default now()
);

-- ============================================
-- Quests
-- ============================================

create table quests (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references places(id) on delete cascade,
  title text not null,
  description text,
  difficulty_level smallint check (difficulty_level between 1 and 5),
  estimated_duration integer,
  points_reward integer not null default 0,
  cover_image_url text,
  created_at timestamptz not null default now()
);

-- ============================================
-- QuestObjectives
-- ============================================

create table quest_objectives (
  id uuid primary key default gen_random_uuid(),
  quest_id uuid not null references quests(id) on delete cascade,
  title text not null,
  requires_photo boolean not null default false,
  order_index integer not null,
  created_at timestamptz not null default now(),
  unique (quest_id, order_index)
);

-- ============================================
-- Tags
-- ============================================

create table tags (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

-- ============================================
-- QuestTags
-- ============================================

create table quest_tags (
  quest_id uuid not null references quests(id) on delete cascade,
  tag_id uuid not null references tags(id) on delete cascade,
  primary key (quest_id, tag_id)
);

-- ============================================
-- QuestCompletions
-- ============================================

create table quest_completions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  quest_id uuid not null references quests(id) on delete cascade,
  status quest_status not null default 'pending',
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, quest_id)
);

-- ============================================
-- QuestObjectiveCompletions
-- ============================================

create table quest_objective_completions (
  completion_id uuid not null references quest_completions(id) on delete cascade,
  objective_id uuid not null references quest_objectives(id) on delete cascade,
  proof_photo text,
  completed_at timestamptz not null default now(),
  primary key (completion_id, objective_id)
);

-- ============================================
-- UserInterests
-- ============================================

create table user_interests (
  user_id uuid not null references users(id) on delete cascade,
  tag_id uuid not null references tags(id) on delete cascade,
  primary key (user_id, tag_id)
);

-- ============================================
-- UserLocations
-- ============================================

create table user_locations (
  user_id uuid primary key references users(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  is_broadcasting boolean not null default false,
  updated_at timestamptz not null default now()
);

-- ============================================
-- Events
-- ============================================

create table events (
  id uuid primary key default gen_random_uuid(),
  place_id uuid references places(id) on delete set null,
  title text not null,
  description text,
  cover_image_url text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  capacity integer check (capacity > 0),
  created_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

-- ============================================
-- EventAttendees (RSVP)
-- ============================================

create table event_attendees (
  event_id uuid not null references events(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

-- ============================================
-- Badges
-- ============================================

create table badges (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  criteria jsonb,
  icon_url text,
  created_at timestamptz not null default now()
);

-- ============================================
-- UserBadges
-- ============================================

create table user_badges (
  user_id uuid not null references users(id) on delete cascade,
  badge_id uuid not null references badges(id) on delete cascade,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

-- ============================================
-- Friendships
-- ============================================

create table friendships (
  id uuid primary key default gen_random_uuid(),
  user_id_1 uuid not null references users(id) on delete cascade,
  user_id_2 uuid not null references users(id) on delete cascade,
  status friendship_status not null default 'pending',
  created_at timestamptz not null default now(),
  check (user_id_1 <> user_id_2),
  unique (user_id_1, user_id_2)
);

-- ============================================
-- Notifications
-- ============================================

create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  type notification_type not null,
  content text,
  read_status boolean not null default false,
  created_at timestamptz not null default now()
);

-- ============================================
-- Index for common queries
-- ============================================

create index idx_quests_place_id on quests(place_id);
create index idx_quest_completions_user_id on quest_completions(user_id);
create index idx_quest_completions_quest_id on quest_completions(quest_id);
create index idx_quest_tags_tag_id on quest_tags(tag_id);
create index idx_user_badges_user_id on user_badges(user_id);
create index idx_friendships_user_id_1 on friendships(user_id_1);
create index idx_friendships_user_id_2 on friendships(user_id_2);
create index idx_notifications_user_id on notifications(user_id);
create index idx_notifications_user_unread on notifications(user_id, read_status);
create index idx_places_location on places(latitude, longitude);
create index idx_places_category on places(category);
create index idx_quest_objectives_quest_id on quest_objectives(quest_id);
create index idx_quest_objective_completions_objective_id on quest_objective_completions(objective_id);
create index idx_user_interests_tag_id on user_interests(tag_id);
create index idx_user_locations_broadcasting on user_locations(is_broadcasting) where is_broadcasting;
create index idx_events_starts_at on events(starts_at);
create index idx_events_place_id on events(place_id);
create index idx_event_attendees_user_id on event_attendees(user_id);
