-- ============================================
-- Wandr App - RPC functions
-- Supabase / PostgreSQL
-- Run after rls_rules.sql
-- Exposed as POST /rest/v1/rpc/<function_name>
-- ============================================

-- ============================================
-- Lock down writes that must go through these functions
-- (the SQL editor and service_role are not affected)
-- ============================================

-- Users can edit their profile, but not XP, level, streak or tier
revoke insert, update on users from anon, authenticated;
grant insert (id, name, email, profile_picture, energy_level) on users to authenticated;
grant update (name, profile_picture, energy_level) on users to authenticated;

-- Quest progress, RSVPs and friend requests are only created through RPC
revoke insert, update on quest_completions from anon, authenticated;
revoke insert, update on quest_objective_completions from anon, authenticated;
revoke insert, update on event_attendees from anon, authenticated;
revoke insert on friendships from anon, authenticated;

-- ============================================
-- Helper: distance in km between two points (Haversine)
-- ============================================

create or replace function public.distance_km(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
)
returns double precision
language sql
immutable
as $$
  select 6371 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2)
    + cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
  ));
$$;

-- ============================================
-- Internal: award every badge the user now qualifies for
-- Supported criteria:
--   {"quests_completed": N}
--   {"tag": "social", "quests_completed": N}
--   {"completions_before_hour": H}  (Bogota time)
-- ============================================

create or replace function public.award_badges(p_user_id uuid)
returns setof badges
language plpgsql
security definer
set search_path = public
as $$
declare
  v_badge badges;
  v_total integer;
  v_ok boolean;
begin
  select count(*) into v_total
  from quest_completions
  where user_id = p_user_id and status = 'completed';

  for v_badge in
    select * from badges b
    where not exists (
      select 1 from user_badges ub
      where ub.user_id = p_user_id and ub.badge_id = b.id
    )
  loop
    v_ok := false;

    if v_badge.criteria ? 'tag' then
      select count(distinct qc.id) >= coalesce((v_badge.criteria->>'quests_completed')::integer, 1)
      into v_ok
      from quest_completions qc
      join quest_tags qt on qt.quest_id = qc.quest_id
      join tags t on t.id = qt.tag_id
      where qc.user_id = p_user_id
        and qc.status = 'completed'
        and t.name = v_badge.criteria->>'tag';
    elsif v_badge.criteria ? 'completions_before_hour' then
      select exists (
        select 1 from quest_completions
        where user_id = p_user_id
          and status = 'completed'
          and extract(hour from completed_at at time zone 'America/Bogota')
              < (v_badge.criteria->>'completions_before_hour')::integer
      ) into v_ok;
    elsif v_badge.criteria ? 'quests_completed' then
      v_ok := v_total >= (v_badge.criteria->>'quests_completed')::integer;
    end if;

    if v_ok then
      insert into user_badges (user_id, badge_id)
      values (p_user_id, v_badge.id)
      on conflict do nothing;

      insert into notifications (user_id, type, content)
      values (p_user_id, 'unlocked_badge', 'You earned the ' || v_badge.name || ' badge');

      return next v_badge;
    end if;
  end loop;
end;
$$;

-- ============================================
-- start_quest: begin a quest (or restart an abandoned one)
-- ============================================

create or replace function public.start_quest(p_quest_id uuid)
returns quest_completions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_completion quest_completions;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_completion
  from quest_completions
  where user_id = v_uid and quest_id = p_quest_id
  for update;

  if not found then
    if not exists (select 1 from quests where id = p_quest_id) then
      raise exception 'Quest not found';
    end if;

    insert into quest_completions (user_id, quest_id)
    values (v_uid, p_quest_id)
    returning * into v_completion;
  elsif v_completion.status = 'completed' then
    raise exception 'You already completed this quest';
  elsif v_completion.status = 'abandoned' then
    delete from quest_objective_completions where completion_id = v_completion.id;

    update quest_completions
    set status = 'pending', completed_at = null, created_at = now()
    where id = v_completion.id
    returning * into v_completion;
  end if;

  return v_completion;
end;
$$;

-- ============================================
-- complete_objective: check one step of an active quest
-- When the last step is checked it also:
--   closes the quest, adds XP, updates level, tier and streak,
--   awards badges and notifies friends
-- Level = XP / 200 + 1 (never goes down)
-- Tier: 1-4 bogota_scout, 5-9 trailblazer, 10-19 pathfinder, 20+ master_pathfinder
-- ============================================

create or replace function public.complete_objective(
  p_quest_id uuid,
  p_objective_id uuid,
  p_photo_url text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := (now() at time zone 'America/Bogota')::date;
  v_completion quest_completions;
  v_objective quest_objectives;
  v_user users;
  v_total integer;
  v_done integer;
  v_reward integer := 0;
  v_level integer;
  v_last_day date;
  v_new_badges jsonb := '[]'::jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_completion
  from quest_completions
  where user_id = v_uid and quest_id = p_quest_id
  for update;

  if not found or v_completion.status <> 'pending' then
    raise exception 'Quest is not in progress';
  end if;

  select * into v_objective
  from quest_objectives
  where id = p_objective_id and quest_id = p_quest_id;

  if not found then
    raise exception 'Objective does not belong to this quest';
  end if;

  if v_objective.requires_photo and p_photo_url is null then
    raise exception 'This objective requires a photo';
  end if;

  insert into quest_objective_completions (completion_id, objective_id, proof_photo)
  values (v_completion.id, p_objective_id, p_photo_url)
  on conflict (completion_id, objective_id) do nothing;

  select count(*) into v_total from quest_objectives where quest_id = p_quest_id;
  select count(*) into v_done from quest_objective_completions where completion_id = v_completion.id;

  if v_done >= v_total then
    -- Last day the user finished a quest, before this one (for the streak)
    select max((completed_at at time zone 'America/Bogota')::date) into v_last_day
    from quest_completions
    where user_id = v_uid and status = 'completed';

    update quest_completions
    set status = 'completed', completed_at = now()
    where id = v_completion.id;

    select points_reward into v_reward from quests where id = p_quest_id;

    select * into v_user from users where id = v_uid for update;
    v_level := greatest(v_user.level, (v_user.current_xp + v_reward) / 200 + 1);

    update users set
      current_xp = current_xp + v_reward,
      level = v_level,
      current_streak = case
        when v_last_day = v_today then greatest(current_streak, 1)
        when v_last_day = v_today - 1 then current_streak + 1
        else 1
      end,
      tier = case
        when v_level >= 20 then 'master_pathfinder'::user_tier
        when v_level >= 10 then 'pathfinder'::user_tier
        when v_level >= 5 then 'trailblazer'::user_tier
        else 'bogota_scout'::user_tier
      end
    where id = v_uid
    returning * into v_user;

    select coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'name', b.name, 'icon_url', b.icon_url)), '[]'::jsonb)
    into v_new_badges
    from public.award_badges(v_uid) b;

    insert into notifications (user_id, type, content)
    select
      case when f.user_id_1 = v_uid then f.user_id_2 else f.user_id_1 end,
      'completed_friend_quest',
      v_user.name || ' completed ' || q.title
    from friendships f
    cross join quests q
    where q.id = p_quest_id
      and f.status = 'accepted'
      and v_uid in (f.user_id_1, f.user_id_2);
  end if;

  return jsonb_build_object(
    'completed_objectives', v_done,
    'total_objectives', v_total,
    'quest_completed', v_done >= v_total,
    'xp_earned', v_reward,
    'current_xp', v_user.current_xp,
    'level', v_user.level,
    'tier', v_user.tier,
    'current_streak', v_user.current_streak,
    'new_badges', v_new_badges
  );
end;
$$;

-- ============================================
-- abandon_quest: give up an active quest
-- ============================================

create or replace function public.abandon_quest(p_quest_id uuid)
returns quest_completions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_completion quest_completions;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  update quest_completions
  set status = 'abandoned'
  where user_id = v_uid and quest_id = p_quest_id and status = 'pending'
  returning * into v_completion;

  if not found then
    raise exception 'Quest is not in progress';
  end if;

  return v_completion;
end;
$$;

-- ============================================
-- rsvp_event: join an event if it has not ended and is not full
-- (leaving is a plain DELETE on event_attendees)
-- ============================================

create or replace function public.rsvp_event(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_event events;
  v_count integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Lock the event so two people cannot take the last spot at the same time
  select * into v_event from events where id = p_event_id for update;

  if not found then
    raise exception 'Event not found';
  end if;

  if coalesce(v_event.ends_at, v_event.starts_at) < now() then
    raise exception 'This event has already ended';
  end if;

  select count(*) into v_count from event_attendees where event_id = p_event_id;

  if not exists (
    select 1 from event_attendees where event_id = p_event_id and user_id = v_uid
  ) then
    if v_event.capacity is not null and v_count >= v_event.capacity then
      raise exception 'This event is full';
    end if;

    insert into event_attendees (event_id, user_id) values (p_event_id, v_uid);
    v_count := v_count + 1;
  end if;

  return jsonb_build_object(
    'event_id', p_event_id,
    'attendees', v_count,
    'capacity', v_event.capacity
  );
end;
$$;

-- ============================================
-- send_friend_request: create a pending request and notify the receiver
-- ============================================

create or replace function public.send_friend_request(p_friend_id uuid)
returns friendships
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_friendship friendships;
  v_sender_name text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_friend_id = v_uid then
    raise exception 'You cannot add yourself';
  end if;

  if not exists (select 1 from users where id = p_friend_id) then
    raise exception 'User not found';
  end if;

  if exists (
    select 1 from friendships
    where (user_id_1 = v_uid and user_id_2 = p_friend_id)
       or (user_id_1 = p_friend_id and user_id_2 = v_uid)
  ) then
    raise exception 'A friendship with this user already exists';
  end if;

  insert into friendships (user_id_1, user_id_2, status)
  values (v_uid, p_friend_id, 'pending')
  returning * into v_friendship;

  select name into v_sender_name from users where id = v_uid;

  insert into notifications (user_id, type, content)
  values (p_friend_id, 'friend_request', v_sender_name || ' sent you a friend request');

  return v_friendship;
end;
$$;

-- ============================================
-- accept_friend_request: only the receiver can accept
-- ============================================

create or replace function public.accept_friend_request(p_friendship_id uuid)
returns friendships
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_friendship friendships;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  update friendships
  set status = 'accepted'
  where id = p_friendship_id and user_id_2 = v_uid and status = 'pending'
  returning * into v_friendship;

  if not found then
    raise exception 'Friend request not found';
  end if;

  return v_friendship;
end;
$$;

-- ============================================
-- nearby_places: places inside a radius, closest first
-- ============================================

create or replace function public.nearby_places(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision default 5,
  p_category place_category default null
)
returns table (
  id uuid,
  name text,
  category place_category,
  address text,
  latitude double precision,
  longitude double precision,
  average_rating numeric,
  cover_image_url text,
  distance_km double precision
)
language sql
stable
as $$
  select * from (
    select
      p.id, p.name, p.category, p.address, p.latitude, p.longitude,
      p.average_rating, p.cover_image_url,
      public.distance_km(p_lat, p_lng, p.latitude, p.longitude) as distance_km
    from places p
    where p_category is null or p.category = p_category
  ) nearby
  where nearby.distance_km <= p_radius_km
  order by nearby.distance_km;
$$;

-- ============================================
-- nearby_quests: quests inside a radius, closest first
-- ============================================

create or replace function public.nearby_quests(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision default 5
)
returns table (
  id uuid,
  title text,
  description text,
  difficulty_level smallint,
  estimated_duration integer,
  points_reward integer,
  cover_image_url text,
  place_id uuid,
  place_name text,
  distance_km double precision
)
language sql
stable
as $$
  select * from (
    select
      q.id, q.title, q.description, q.difficulty_level, q.estimated_duration,
      q.points_reward, q.cover_image_url, p.id as place_id, p.name as place_name,
      public.distance_km(p_lat, p_lng, p.latitude, p.longitude) as distance_km
    from quests q
    join places p on p.id = q.place_id
  ) nearby
  where nearby.distance_km <= p_radius_km
  order by nearby.distance_km;
$$;

-- ============================================
-- friends_on_map: friends sharing their location, closest first
-- distance_km is null if the caller has no saved location
-- ============================================

create or replace function public.friends_on_map()
returns table (
  user_id uuid,
  name text,
  profile_picture text,
  latitude double precision,
  longitude double precision,
  updated_at timestamptz,
  distance_km double precision,
  active_quest text
)
language sql
stable
as $$
  with me as (
    select l.latitude, l.longitude
    from user_locations l
    where l.user_id = auth.uid()
  )
  select
    u.id, u.name, u.profile_picture, l.latitude, l.longitude, l.updated_at,
    case
      when me.latitude is null then null
      else public.distance_km(me.latitude, me.longitude, l.latitude, l.longitude)
    end,
    (
      select q.title
      from quest_completions qc
      join quests q on q.id = qc.quest_id
      where qc.user_id = u.id and qc.status = 'pending'
      order by qc.created_at desc
      limit 1
    )
  from user_locations l
  join users u on u.id = l.user_id
  left join me on true
  where l.is_broadcasting
    and public.are_friends(auth.uid(), l.user_id)
  order by 7 nulls last;
$$;

-- ============================================
-- Permissions: only logged-in users can call the RPC functions
-- ============================================

revoke execute on function public.award_badges(uuid) from public, anon, authenticated;

revoke execute on function public.start_quest(uuid) from public, anon;
revoke execute on function public.complete_objective(uuid, uuid, text) from public, anon;
revoke execute on function public.abandon_quest(uuid) from public, anon;
revoke execute on function public.rsvp_event(uuid) from public, anon;
revoke execute on function public.send_friend_request(uuid) from public, anon;
revoke execute on function public.accept_friend_request(uuid) from public, anon;
revoke execute on function public.nearby_places(double precision, double precision, double precision, place_category) from public, anon;
revoke execute on function public.nearby_quests(double precision, double precision, double precision) from public, anon;
revoke execute on function public.friends_on_map() from public, anon;

grant execute on function public.start_quest(uuid) to authenticated;
grant execute on function public.complete_objective(uuid, uuid, text) to authenticated;
grant execute on function public.abandon_quest(uuid) to authenticated;
grant execute on function public.rsvp_event(uuid) to authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.accept_friend_request(uuid) to authenticated;
grant execute on function public.nearby_places(double precision, double precision, double precision, place_category) to authenticated;
grant execute on function public.nearby_quests(double precision, double precision, double precision) to authenticated;
grant execute on function public.friends_on_map() to authenticated;
