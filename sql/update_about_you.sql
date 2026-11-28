-- Save "About you" answers only for the logged-in user.
-- Fixes "permission denied for table users": the app can't update users directly.
create or replace function public.update_about_you(
    p_age_range text default null,
    p_occupation text default null,
    p_notifications_enabled boolean default true
)
returns void
language sql
security definer
set search_path = public
as $$
    update public.users
    set age_range = p_age_range,
        occupation = p_occupation,
        notifications_enabled = p_notifications_enabled
    where id = auth.uid();
$$;

revoke execute on function public.update_about_you(text, text, boolean) from public, anon;
grant execute on function public.update_about_you(text, text, boolean) to authenticated;

notify pgrst, 'reload schema';