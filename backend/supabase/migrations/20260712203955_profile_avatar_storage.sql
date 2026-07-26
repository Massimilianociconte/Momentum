-- Personal portraits are local-first. Only users with cloud-media entitlement
-- can upload; authenticated viewers receive access according to profile
-- visibility and accepted friendship. The bucket remains private.

create or replace function public.set_profile_avatar(p_avatar_path text)
returns boolean
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_path text := nullif(trim(coalesce(p_avatar_path, '')), '');
begin
  if v_user_id is null then
    raise exception 'authentication_required';
  end if;
  if v_path is not null
     and v_path <> (v_user_id::text || '/avatar.jpg') then
    raise exception 'invalid_avatar_path';
  end if;
  update public.profiles
  set avatar_url = v_path
  where user_id = v_user_id;
  return found;
end;
$$;

revoke all on function public.set_profile_avatar(text) from public, anon;
grant execute on function public.set_profile_avatar(text) to authenticated;

insert into storage.buckets(
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'profile-avatars',
  'profile-avatars',
  false,
  2097152,
  array['image/jpeg']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "profile avatar privacy read" on storage.objects;
create policy "profile avatar privacy read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'profile-avatars'
    and (
      (storage.foldername(name))[1] = (select auth.uid()::text)
      or exists (
        select 1
        from public.profiles owner_profile
        where owner_profile.user_id::text = (storage.foldername(name))[1]
          and (
            owner_profile.privacy = 'PUBLIC'
            or exists (
              select 1
              from public.social_contact_requests relationship
              where relationship.status = 'ACCEPTED'
                and (
                  (
                    relationship.requester_id = (select auth.uid())
                    and relationship.receiver_id = owner_profile.user_id
                  )
                  or (
                    relationship.receiver_id = (select auth.uid())
                    and relationship.requester_id = owner_profile.user_id
                  )
                )
            )
          )
          and not exists (
            select 1
            from public.user_blocks blocked
            where (
              blocked.blocker_id = (select auth.uid())
              and blocked.blocked_id = owner_profile.user_id
            ) or (
              blocked.blocked_id = (select auth.uid())
              and blocked.blocker_id = owner_profile.user_id
            )
          )
      )
    )
  );

drop policy if exists "profile avatar entitled insert" on storage.objects;
create policy "profile avatar entitled insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and name = (select auth.uid()::text) || '/avatar.jpg'
    and (select public.has_cloud_media_access())
  );

drop policy if exists "profile avatar entitled update" on storage.objects;
create policy "profile avatar entitled update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'profile-avatars'
    and name = (select auth.uid()::text) || '/avatar.jpg'
    and (select public.has_cloud_media_access())
  );

drop policy if exists "profile avatar owner delete" on storage.objects;
create policy "profile avatar owner delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );
