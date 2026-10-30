-- BQ9: What do users who haven't opened the app in the last 2 weeks have in common?
-- Run this once in Supabase -> SQL Editor.

-- 1. New columns in users
alter table public.users
    add column if not exists last_opened_at        timestamptz,
    add column if not exists age_range             text,
    add column if not exists occupation            text,
    add column if not exists notifications_enabled boolean default true,
    add column if not exists notification_channel  text;

-- 2. The app calls this every time it is opened
create or replace function public.touch_last_opened()
returns void
language sql
security definer
set search_path = public
as $$
    update public.users set last_opened_at = now() where id = auth.uid();
$$;

-- 3. Profiles: demographics and notification preferences (no names or emails)
create or replace function public.bq9_user_profiles()
returns table (user_id uuid, age_range text, occupation text,
               notifications_enabled boolean, notification_channel text)
language sql
security definer
set search_path = public
as $$
    select id, age_range, occupation, notifications_enabled, notification_channel
    from public.users;
$$;

-- 4. Last time each user opened the app (in seconds since 1970)
create or replace function public.bq9_user_last_open()
returns table (user_id uuid, last_opened_epoch double precision)
language sql
security definer
set search_path = public
as $$
    select id, extract(epoch from last_opened_at)::double precision
    from public.users;
$$;

-- 5. Quest history of each user
create or replace function public.bq9_user_quest_history()
returns table (user_id uuid, completed_count integer, abandoned_count integer, top_category text)
language sql
security definer
set search_path = public
as $$
    select qc.user_id,
           (count(*) filter (where qc.status = 'completed'))::integer,
           (count(*) filter (where qc.status not in ('completed', 'pending')))::integer,
           mode() within group (order by p.category::text) filter (where qc.status = 'completed')
    from public.quest_completions qc
    join public.quests q on q.id = qc.quest_id
    left join public.places p on p.id = q.place_id
    group by qc.user_id;
$$;

-- 6. Only logged-in users can call these functions
revoke execute on function public.touch_last_opened(), public.bq9_user_profiles(),
    public.bq9_user_last_open(), public.bq9_user_quest_history() from public, anon;
grant execute on function public.touch_last_opened(), public.bq9_user_profiles(),
    public.bq9_user_last_open(), public.bq9_user_quest_history() to authenticated;

-- 7. Test data for the users that already exist (only fills empty values)
update public.users u
set age_range = coalesce(age_range, (array['18-24', '25-34', '35-44', '45+'])[1 + floor(random() * 4)::int]),
    occupation = coalesce(occupation, (array['student', 'employee', 'freelancer', 'other'])[1 + floor(random() * 4)::int]),
    notification_channel = coalesce(notification_channel, (array['push', 'email', 'in_app'])[1 + floor(random() * 3)::int]),
    notifications_enabled = random() > 0.4,
    last_opened_at = coalesce(last_opened_at, now() - random() * interval '35 days')
where u.last_opened_at is null;
