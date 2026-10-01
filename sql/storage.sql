-- ============================================
-- Wandr App - Storage for quest photos
-- Supabase / PostgreSQL
-- Run after rpc_functions.sql
-- ============================================

-- Private bucket: photos are only reachable with a logged-in session
insert into storage.buckets (id, name, public)
values ('quest-photos', 'quest-photos', false)
on conflict (id) do nothing;

-- ============================================
-- Each user works only inside their own folder: quest-photos/<user id>/<quest id>/<objective id>.jpg
-- The app sends that path as p_photo_url to complete_objective
-- ============================================

create policy "quest-photos: upload own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'quest-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "quest-photos: read own" on storage.objects
  for select to authenticated
  using (bucket_id = 'quest-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- Needed to replace a photo (the app uploads with upsert)
create policy "quest-photos: replace own" on storage.objects
  for update to authenticated
  using (bucket_id = 'quest-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'quest-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "quest-photos: delete own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'quest-photos' and (storage.foldername(name))[1] = auth.uid()::text);
