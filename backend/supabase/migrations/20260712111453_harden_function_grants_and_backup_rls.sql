begin;

-- Historical migrations were edited after some remote deployments, leaving
-- default PUBLIC execute grants on SECURITY DEFINER functions. Close every
-- such function first, then explicitly reopen only the authenticated RPC
-- surface used by the mobile clients. Service-role Edge Functions retain the
-- internal helpers they need.
do $$
declare
  f regprocedure;
begin
  for f in
    select p.oid::regprocedure
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
  loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end;
$$;

do $$
declare
  f regprocedure;
begin
  foreach f in array array[
    'public.discover_social_players(int)'::regprocedure,
    'public.social_player_profile(uuid)'::regprocedure,
    'public.send_friend_request(uuid,text)'::regprocedure,
    'public.respond_friend_request(uuid,boolean)'::regprocedure,
    'public.cancel_friend_request(uuid)'::regprocedure,
    'public.remove_friend(uuid)'::regprocedure,
    'public.block_user(uuid)'::regprocedure,
    'public.unblock_user(uuid)'::regprocedure,
    'public.social_relationships()'::regprocedure,
    'public.social_inbox()'::regprocedure,
    'public.blocked_users()'::regprocedure,
    'public.report_social_user(uuid,text,text)'::regprocedure,
    'public.send_match_proposal(uuid,text,text)'::regprocedure,
    'public.send_team_join_request(uuid,text)'::regprocedure,
    'public.respond_social_item(text,uuid,boolean)'::regprocedure,
    'public.has_cloud_media_access()'::regprocedure,
    'public.upsert_cloud_team(text,text,text,bigint,text)'::regprocedure,
    'public.set_team_avatar(uuid,text)'::regprocedure,
    'public.my_cloud_teams()'::regprocedure,
    'public.create_invite(text,uuid,uuid,text,uuid,int,uuid)'::regprocedure,
    'public.preview_invite(text)'::regprocedure,
    'public.redeem_invite(text)'::regprocedure,
    'public.revoke_invite(uuid)'::regprocedure,
    'public.has_duo_access(uuid)'::regprocedure,
    'public.duo_team_of(uuid,uuid)'::regprocedure,
    'public.duo_create_session(text,jsonb,text)'::regprocedure,
    'public.duo_join_session(text)'::regprocedure,
    'public.duo_set_session_status(uuid,text)'::regprocedure,
    'public.my_wearable_connections()'::regprocedure,
    'public.delete_my_backup(text)'::regprocedure
  ] loop
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;

-- Evaluate auth context once per statement instead of once per backup row.
drop policy if exists "premium backup select" on public.backups;
drop policy if exists "premium backup insert" on public.backups;
drop policy if exists "premium backup update" on public.backups;
drop policy if exists "own backup delete" on public.backups;

create policy "premium backup select" on public.backups
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    and (select public.has_cloud_media_access())
  );

create policy "premium backup insert" on public.backups
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and (select public.has_cloud_media_access())
  );

create policy "premium backup update" on public.backups
  for update to authenticated
  using (
    (select auth.uid()) = user_id
    and (select public.has_cloud_media_access())
  )
  with check (
    (select auth.uid()) = user_id
    and (select public.has_cloud_media_access())
  );

create policy "own backup delete" on public.backups
  for delete to authenticated
  using ((select auth.uid()) = user_id);

commit;
