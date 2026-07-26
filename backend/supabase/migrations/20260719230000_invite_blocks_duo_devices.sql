-- P0 fixes from multi-agent audit:
-- 1) PROFILE invites: target_user_id is the shared profile subject, not redeemer
-- 2) redeem_invite: respect user_blocks; never re-ACCEPT BLOCKED pairs
-- 3) duo_events: allow GARMIN_CONNECT_IQ / FITBIT_OS source_device
begin;

create or replace function public.redeem_invite(p_secret text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv public.invite_tokens;
  v_uid uuid := auth.uid();
  v_duo public.duo_sessions;
  v_my_team text;
  v_other uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if (
    select count(*) from public.invite_audit a
    where a.actor_id = v_uid
      and a.action in ('REDEEM', 'FAILED')
      and a.created_at > now() - interval '10 minutes'
  ) >= 10 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;

  select * into v_inv from public.invite_tokens i
  where i.token_hash = public.invite_hash(p_secret)
     or i.code_hash = public.invite_hash(upper(trim(p_secret)))
  for update;

  if not found
     or v_inv.revoked_at is not null
     or v_inv.expires_at <= now()
     or v_inv.use_count >= v_inv.max_uses
     or v_inv.inviter_id = v_uid then
    insert into public.invite_audit(actor_id, action, success)
    values (v_uid, 'FAILED', false);
    return jsonb_build_object('ok', false, 'error', 'invite_not_available');
  end if;

  -- PROFILE: target_user_id is the profile subject (public card being shared).
  -- Targeted kinds: target_user_id is the only allowed redeemer.
  if v_inv.kind is distinct from 'PROFILE'
     and v_inv.target_user_id is not null
     and v_inv.target_user_id <> v_uid then
    insert into public.invite_audit(invite_id, actor_id, action, success)
    values (v_inv.invite_id, v_uid, 'FAILED', false);
    return jsonb_build_object('ok', false, 'error', 'invite_not_for_you');
  end if;

  -- Social safety: never re-link blocked users via invite tokens.
  if v_inv.kind in ('FRIEND', 'MATCH', 'TEAM_JOIN') then
    v_other := v_inv.inviter_id;
    if exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = v_uid and b.blocked_id = v_other)
         or (b.blocker_id = v_other and b.blocked_id = v_uid)
    ) then
      insert into public.invite_audit(invite_id, actor_id, action, success)
      values (v_inv.invite_id, v_uid, 'FAILED', false);
      return jsonb_build_object('ok', false, 'error', 'not_available');
    end if;
  end if;

  if v_inv.kind = 'FRIEND' then
    insert into public.social_contact_requests(
      requester_id, receiver_id, message, status, accepted_at
    ) values (
      v_inv.inviter_id, v_uid, 'Invito RallyMate confermato', 'ACCEPTED', now()
    )
    on conflict do nothing;
    -- Never promote BLOCKED / DECLINED into ACCEPTED via invite side-channel.
    update public.social_contact_requests
    set status = 'ACCEPTED', accepted_at = now(), updated_at = now()
    where least(requester_id, receiver_id) = least(v_uid, v_inv.inviter_id)
      and greatest(requester_id, receiver_id) = greatest(v_uid, v_inv.inviter_id)
      and status is distinct from 'BLOCKED'
      and status is distinct from 'DECLINED';
  elsif v_inv.kind = 'PROFILE' then
    if not exists (
      select 1 from public.profiles p
      where p.user_id = v_inv.target_user_id
        and p.social_enabled
        and p.map_visibility = 'PUBLIC'
    ) then
      return jsonb_build_object('ok', false, 'error', 'profile_not_available');
    end if;
  elsif v_inv.kind = 'MATCH' then
    insert into public.match_proposals(
      creator_id, receiver_id, message, status, linked_match_id
    ) values (
      v_inv.inviter_id, v_uid, 'Invito partita RallyMate confermato',
      'ACCEPTED', v_inv.match_id
    ) on conflict (creator_id, receiver_id, linked_match_id)
      where linked_match_id is not null
      do update set status = 'ACCEPTED'
      where public.match_proposals.status is distinct from 'BLOCKED';
  elsif v_inv.kind = 'TEAM_JOIN' then
    insert into public.team_memberships(
      team_id, user_id, member_role, status, joined_at
    ) values (
      v_inv.team_id, v_uid, 'MEMBER', 'ACCEPTED', now()
    )
    on conflict (team_id, user_id) do update
      set status = 'ACCEPTED', joined_at = now()
      where public.team_memberships.status is distinct from 'BLOCKED';
  elsif v_inv.kind = 'TEAM_LINK' then
    if not exists (
      select 1 from public.teams t
      where t.team_id = v_inv.target_team_id and t.owner_id = v_uid
    ) then
      return jsonb_build_object('ok', false, 'error', 'target_team_not_owned');
    end if;
    insert into public.team_connections(team_low, team_high, connected_by)
    values (
      least(v_inv.team_id, v_inv.target_team_id),
      greatest(v_inv.team_id, v_inv.target_team_id),
      v_uid
    )
    on conflict do nothing;
  elsif v_inv.kind = 'DUO' then
    if not public.has_duo_access(v_uid) then
      return jsonb_build_object('ok', false, 'error', 'premium_required');
    end if;
    select * into v_duo from public.duo_sessions
    where session_id = v_inv.duo_session_id for update;
    if not found
       or v_duo.status not in ('PENDING', 'ACTIVE')
       or v_duo.code_expires_at <= now()
       or (v_duo.guest_id is not null and v_duo.guest_id <> v_uid) then
      return jsonb_build_object('ok', false, 'error', 'duo_not_available');
    end if;
    v_my_team := case v_duo.creator_team
      when 'TEAM_A' then 'TEAM_B'
      else 'TEAM_A'
    end;
    if v_duo.creator_id = v_uid then
      v_my_team := v_duo.creator_team;
    else
      update public.duo_sessions
      set guest_id = v_uid,
          guest_team = v_my_team,
          status = 'ACTIVE',
          updated_at = now()
      where session_id = v_duo.session_id;
    end if;
  end if;

  update public.invite_tokens
  set use_count = use_count + 1
  where invite_id = v_inv.invite_id;
  insert into public.invite_audit(invite_id, actor_id, action, success)
  values (v_inv.invite_id, v_uid, 'REDEEM', true);
  return jsonb_build_object(
    'ok', true,
    'kind', v_inv.kind,
    'profileUserId', v_inv.target_user_id,
    'teamId', v_inv.team_id,
    'matchId', v_inv.match_id,
    'duoSessionId', v_inv.duo_session_id,
    'format', case when v_inv.kind = 'DUO' then v_duo.format_json else null end,
    'myTeam', case when v_inv.kind = 'DUO' then v_my_team else null end
  );
end;
$$;

revoke all on function public.redeem_invite(text) from public, anon;
grant execute on function public.redeem_invite(text) to authenticated;

-- Duo wearable scoring devices must be accepted by cloud timeline.
do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'duo_events_source_device_valid'
  ) then
    alter table public.duo_events drop constraint duo_events_source_device_valid;
  end if;
end $$;

alter table public.duo_events
  add constraint duo_events_source_device_valid
  check (
    source_device in (
      'PHONE',
      'APPLE_WATCH',
      'WEAR_OS',
      'GARMIN_CONNECT_IQ',
      'FITBIT_OS'
    )
  ) not valid;

alter table public.duo_events validate constraint duo_events_source_device_valid;

commit;
