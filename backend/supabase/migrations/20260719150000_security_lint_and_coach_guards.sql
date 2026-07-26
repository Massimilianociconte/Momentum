-- Security hygiene + coach integrity.
--
-- 1) Move pg_net out of public (linter extension_in_public).
-- 2) Revoke EXECUTE on internal helper SECURITY DEFINER functions that the
--    mobile client never calls (still usable by other DEFINER RPCs as owner).
-- 3) Keep intentional client RPCs executable by authenticated (required API).
-- 4) Harden coach assignment player updates (feedback is coach-only).
-- 5) block_user / end_coach_link close active coach relationships.

begin;

-- ---------------------------------------------------------------------------
-- 1. pg_net: cannot SET SCHEMA on this extension version.
--    Reinstall into extensions when safe (breaks only if public.net is required).
-- ---------------------------------------------------------------------------
create schema if not exists extensions;
grant usage on schema extensions to postgres, anon, authenticated, service_role;

do $$
begin
  if exists (
    select 1 from pg_extension e
    join pg_namespace n on n.oid = e.extnamespace
    where e.extname = 'pg_net' and n.nspname = 'public'
  ) then
    -- Prefer drop+recreate into extensions; keep public alias if drop is blocked.
    begin
      drop extension pg_net cascade;
      create extension pg_net with schema extensions;
      raise notice 'pg_net reinstalled in extensions schema';
    exception when others then
      raise notice 'pg_net reinstall skipped (keep public): %', sqlerrm;
    end;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Internal helpers: not part of the public mobile API
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as f
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'has_active_entitlement',
        'has_cloud_media_access',
        'has_duo_access',
        'has_pro_access',
        'duo_team_of'
      )
  loop
    execute format(
      'revoke all on function %s from public, anon, authenticated',
      r.f
    );
    execute format('grant execute on function %s to service_role', r.f);
    -- Other SECURITY DEFINER RPCs owned by postgres still call these as owner.
    execute format(
      'comment on function %s is %L',
      r.f,
      'Internal SECURITY DEFINER helper. Not part of the mobile RPC surface; '
      'EXECUTE revoked from authenticated intentionally (lint 0029).'
    );
  end loop;
end;
$$;

-- Re-assert intentional client API RPCs remain callable (do not break the app).
do $$
declare
  r record;
  allowed text[] := array[
    'discover_social_players', 'social_player_profile', 'send_friend_request',
    'respond_friend_request', 'cancel_friend_request', 'remove_friend',
    'block_user', 'unblock_user', 'social_relationships', 'social_inbox',
    'blocked_users', 'report_social_user', 'send_match_proposal',
    'send_team_join_request', 'respond_social_item', 'upsert_cloud_team',
    'set_team_avatar', 'my_cloud_teams', 'create_invite', 'preview_invite',
    'redeem_invite', 'revoke_invite', 'duo_create_session', 'duo_join_session',
    'duo_set_session_status', 'duo_ack_state', 'my_wearable_connections',
    'delete_my_backup', 'delete_my_health_provider_data',
    'register_my_push_device', 'deactivate_my_push_device', 'my_push_device_status',
    'create_friend_group', 'join_friend_group', 'leave_friend_group',
    'my_friend_groups', 'friend_group_leaderboard', 'remove_group_member',
    'assign_coach_training', 'coach_public_profile', 'join_coach',
    'end_coach_link', 'my_coach_athletes', 'my_coaches', 'my_coach_link_code',
    'set_profile_avatar'
  ];
begin
  for r in
    select p.oid::regprocedure as f, p.proname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and p.proname = any (allowed)
  loop
    execute format('grant execute on function %s to authenticated', r.f);
    execute format(
      'comment on function %s is %L',
      r.f,
      'Intentional mobile API SECURITY DEFINER RPC. Authenticated EXECUTE is '
      'required; function body enforces auth.uid() and business rules. '
      'Supabase lint 0029 is an expected advisory for this pattern.'
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Coach assignment: players cannot overwrite coach feedback or free-form status
-- ---------------------------------------------------------------------------
create or replace function public._guard_assignment_player_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.player_id and auth.uid() <> old.coach_id then
    if new.training_plan is distinct from old.training_plan
       or new.coach_id is distinct from old.coach_id
       or new.player_id is distinct from old.player_id
       or new.purchase_id is distinct from old.purchase_id
       or new.feedback is distinct from old.feedback then
      raise exception 'players may only update progress';
    end if;
    -- Athletes may keep ASSIGNED/IN_PROGRESS or mark COMPLETED only.
    if new.status is distinct from old.status
       and new.status not in ('ASSIGNED', 'IN_PROGRESS', 'COMPLETED') then
      raise exception 'players may not set assignment status %', new.status;
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Block severs coach links and soft-expires open assignments
-- ---------------------------------------------------------------------------
create or replace function public.block_user(p_other_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or p_other_id is null or p_other_id = auth.uid() then
    return false;
  end if;

  insert into public.user_blocks(blocker_id, blocked_id)
  values (auth.uid(), p_other_id)
  on conflict do nothing;

  update public.social_contact_requests
     set status = 'BLOCKED', accepted_at = null, updated_at = now()
   where least(requester_id, receiver_id) = least(auth.uid(), p_other_id)
     and greatest(requester_id, receiver_id) = greatest(auth.uid(), p_other_id);

  -- End both directions of coach-athlete relationships.
  update public.coach_athletes
     set status = 'ENDED', ended_at = coalesce(ended_at, now())
   where status = 'ACTIVE'
     and (
       (coach_id = auth.uid() and athlete_id = p_other_id)
       or (coach_id = p_other_id and athlete_id = auth.uid())
     );

  update public.coach_assignments
     set status = 'EXPIRED', updated_at = now()
   where status in ('ASSIGNED', 'IN_PROGRESS')
     and (
       (coach_id = auth.uid() and player_id = p_other_id)
       or (coach_id = p_other_id and player_id = auth.uid())
     );

  return true;
end;
$$;

-- Soft-expire open assignments when either party ends the link.
create or replace function public.end_coach_link(p_coach_id uuid, p_athlete_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if p_coach_id is null or p_athlete_id is null then
    return jsonb_build_object('ok', false, 'error', 'invalid_args');
  end if;
  if v_uid not in (p_coach_id, p_athlete_id) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;

  update public.coach_athletes
     set status = 'ENDED', ended_at = now()
   where coach_id = p_coach_id
     and athlete_id = p_athlete_id
     and status = 'ACTIVE';
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  update public.coach_assignments
     set status = 'EXPIRED', updated_at = now()
   where coach_id = p_coach_id
     and player_id = p_athlete_id
     and status in ('ASSIGNED', 'IN_PROGRESS');

  return jsonb_build_object('ok', true);
end;
$$;

-- Avatar storage: active coach-athlete may read the other party portrait.
do $$
begin
  if exists (
    select 1 from storage.buckets where id = 'profile-avatars'
  ) then
    drop policy if exists "profile avatars coach athlete read" on storage.objects;
    create policy "profile avatars coach athlete read"
      on storage.objects
      for select to authenticated
      using (
        bucket_id = 'profile-avatars'
        and exists (
          select 1
          from public.coach_athletes ca
          where ca.status = 'ACTIVE'
            and (
              (
                ca.coach_id = (select auth.uid())
                and (storage.foldername(name))[1] = ca.athlete_id::text
              )
              or (
                ca.athlete_id = (select auth.uid())
                and (storage.foldername(name))[1] = ca.coach_id::text
              )
            )
        )
      );
  end if;
exception when others then
  raise notice 'profile avatar coach policy skipped: %', sqlerrm;
end;
$$;

commit;
