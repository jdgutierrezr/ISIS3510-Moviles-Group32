-- ============================================
-- delete_quest: erase the user's progress on a quest (Sprint 4)
-- The quest goes back to "not started". It does not count as abandoned.
-- If it was completed, its XP is taken back (level and tier stay).
-- The steps are removed by "on delete cascade".
-- ============================================

create or replace function public.delete_quest(p_quest_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_status quest_status;
  v_reward integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  delete from quest_completions
  where user_id = v_uid and quest_id = p_quest_id
  returning status into v_status;

  if not found then
    return;
  end if;

  if v_status = 'completed' then
    select coalesce(points_reward, 0) into v_reward from quests where id = p_quest_id;
    update users
    set current_xp = greatest(current_xp - v_reward, 0)
    where id = v_uid;
  end if;
end;
$$;

revoke execute on function public.delete_quest(uuid) from public, anon;
grant execute on function public.delete_quest(uuid) to authenticated;
