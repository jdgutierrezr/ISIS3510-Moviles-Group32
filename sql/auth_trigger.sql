-- ============================================
-- Wandr App - Auth trigger
-- Supabase / PostgreSQL
-- Run after rpc_functions.sql
-- ============================================

-- ============================================
-- handle_new_user: when an account is created in auth.users,
-- create its profile in users with the same id.
-- The app sends the name in the sign up metadata ("name").
-- If there is no name, the first part of the email is used.
-- Needed because, with "Confirm email" on, the user has no session
-- right after signing up, so the app cannot insert into users.
-- ============================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, name, email)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), split_part(new.email, '@', 1)),
    new.email
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();