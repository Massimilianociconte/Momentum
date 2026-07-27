-- Invite redemption must be idempotent.
--
-- `redeem_invite` consumes one use per call and rejects anything at
-- `use_count >= max_uses` (default 1). When the RPC succeeded server-side but
-- its response was lost — dropped connection, timeout, app killed mid-accept —
-- the client retry hit `invite_not_available` even though the membership,
-- friendship or match proposal had already been written. The user was in fact
-- joined, but the app reported a failed join.
--
-- A replay by the *same* user is now answered with the original success
-- payload, without consuming another use and without writing another audit row
-- (which would otherwise push the actor into the redeem rate limit). Every
-- inner write was already idempotent (`on conflict do update`), so this only
-- fixes the reporting, never the effect.
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
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'auth_required'); end if;
  if (select count(*) from public.invite_audit a where a.actor_id = v_uid
      and a.action in ('REDEEM', 'FAILED') and a.created_at > now() - interval '10 minutes') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  select * into v_inv from public.invite_tokens i
  where i.token_hash = public.invite_hash(p_secret)
     or i.code_hash = public.invite_hash(upper(trim(p_secret)))
  for update;

  -- Replay of a redeem this user already completed: answer with the same
  -- payload instead of reporting a failure for a join that did happen.
  if found and exists (
    select 1 from public.invite_audit a
    where a.invite_id = v_inv.invite_id
      and a.actor_id = v_uid
      and a.action = 'REDEEM'
      and a.success
  ) then
    if v_inv.kind = 'DUO' then
      select * into v_duo from public.duo_sessions
      where session_id = v_inv.duo_session_id;
      v_my_team := case
        when v_duo.creator_id = v_uid then v_duo.creator_team
        when v_duo.guest_id = v_uid then v_duo.guest_team
        else null
      end;
    end if;
    return jsonb_build_object('ok', true, 'kind', v_inv.kind,
      'replayed', true,
      'profileUserId', v_inv.target_user_id,
      'teamId', v_inv.team_id, 'matchId', v_inv.match_id,
      'duoSessionId', v_inv.duo_session_id,
      'format', case when v_inv.kind = 'DUO' then v_duo.format_json else null end,
      'myTeam', case when v_inv.kind = 'DUO' then v_my_team else null end);
  end if;

  if not found or v_inv.revoked_at is not null or v_inv.expires_at <= now()
     or v_inv.use_count >= v_inv.max_uses or v_inv.inviter_id = v_uid then
    insert into public.invite_audit(actor_id, action, success)
    values (v_uid, 'FAILED', false);
    return jsonb_build_object('ok', false, 'error', 'invite_not_available');
  end if;

  if v_inv.kind = 'FRIEND' then
    insert into public.social_contact_requests(
      requester_id, receiver_id, message, status, accepted_at
    ) values (
      v_inv.inviter_id, v_uid, 'Invito Momentum confermato', 'ACCEPTED', now()
    )
    on conflict do nothing;
    update public.social_contact_requests
    set status = 'ACCEPTED', accepted_at = now(), updated_at = now()
    where least(requester_id, receiver_id) = least(v_uid, v_inv.inviter_id)
      and greatest(requester_id, receiver_id) = greatest(v_uid, v_inv.inviter_id);
  elsif v_inv.kind = 'PROFILE' then
    if not exists (
      select 1 from public.profiles p where p.user_id = v_inv.target_user_id
        and p.social_enabled and p.map_visibility = 'PUBLIC'
    ) then
      return jsonb_build_object('ok', false, 'error', 'profile_not_available');
    end if;
  elsif v_inv.kind = 'MATCH' then
    insert into public.match_proposals(
      creator_id, receiver_id, message, status, linked_match_id
    ) values (
      v_inv.inviter_id, v_uid, 'Invito partita Momentum confermato',
      'ACCEPTED', v_inv.match_id
    ) on conflict (creator_id, receiver_id, linked_match_id)
      where linked_match_id is not null
      do update set status = 'ACCEPTED';
  elsif v_inv.kind = 'TEAM_JOIN' then
    insert into public.team_memberships(team_id, user_id, member_role, status, joined_at)
    values (v_inv.team_id, v_uid, 'MEMBER', 'ACCEPTED', now())
    on conflict (team_id, user_id) do update set status = 'ACCEPTED', joined_at = now();
  elsif v_inv.kind = 'TEAM_LINK' then
    if not exists (select 1 from public.teams t where t.team_id = v_inv.target_team_id and t.owner_id = v_uid) then
      return jsonb_build_object('ok', false, 'error', 'target_team_not_owned');
    end if;
    insert into public.team_connections(team_low, team_high, connected_by)
    values (least(v_inv.team_id, v_inv.target_team_id), greatest(v_inv.team_id, v_inv.target_team_id), v_uid)
    on conflict do nothing;
  elsif v_inv.kind = 'DUO' then
    if not public.has_duo_access(v_uid) then
      return jsonb_build_object('ok', false, 'error', 'premium_required');
    end if;
    select * into v_duo from public.duo_sessions
    where session_id = v_inv.duo_session_id for update;
    if not found or v_duo.status not in ('PENDING', 'ACTIVE')
       or v_duo.code_expires_at <= now()
       or (v_duo.guest_id is not null and v_duo.guest_id <> v_uid) then
      return jsonb_build_object('ok', false, 'error', 'duo_not_available');
    end if;
    v_my_team := case v_duo.creator_team when 'TEAM_A' then 'TEAM_B' else 'TEAM_A' end;
    if v_duo.creator_id = v_uid then
      v_my_team := v_duo.creator_team;
    else
      update public.duo_sessions set guest_id = v_uid, guest_team = v_my_team,
        status = 'ACTIVE', updated_at = now()
      where session_id = v_duo.session_id;
    end if;
  end if;

  update public.invite_tokens set use_count = use_count + 1 where invite_id = v_inv.invite_id;
  insert into public.invite_audit(invite_id, actor_id, action, success)
  values (v_inv.invite_id, v_uid, 'REDEEM', true);
  return jsonb_build_object('ok', true, 'kind', v_inv.kind,
    'replayed', false,
    'profileUserId', v_inv.target_user_id,
    'teamId', v_inv.team_id, 'matchId', v_inv.match_id,
    'duoSessionId', v_inv.duo_session_id,
    'format', case when v_inv.kind = 'DUO' then v_duo.format_json else null end,
    'myTeam', case when v_inv.kind = 'DUO' then v_my_team else null end);
end;
$$;

revoke all on function public.redeem_invite(text) from public, anon;
grant execute on function public.redeem_invite(text) to authenticated;

-- Same defect, same fix, for the targeted team invite answered from the inbox:
-- a retry after a lost response reported `invite_not_available` for a team the
-- user had already joined. A replayed decline now reports DECLINED instead of
-- an error too.
create or replace function public.respond_team_invite(
  p_invite_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv public.invite_tokens;
  v_uid uuid := auth.uid();
  v_member_name text;
  v_team_name text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select * into v_inv
  from public.invite_tokens i
  where i.invite_id = p_invite_id
  for update;
  if not found
     or v_inv.target_user_id is distinct from v_uid
     or v_inv.kind <> 'TEAM_JOIN' then
    return jsonb_build_object('ok', false, 'error', 'invite_not_available');
  end if;

  -- Replay of an answer this user already gave.
  if exists (
    select 1 from public.invite_audit a
    where a.invite_id = v_inv.invite_id
      and a.actor_id = v_uid
      and a.action = 'REDEEM'
      and a.success
  ) then
    return jsonb_build_object('ok', true, 'status', 'ACCEPTED',
      'replayed', true, 'teamId', v_inv.team_id);
  end if;
  if exists (
    select 1 from public.invite_audit a
    where a.invite_id = v_inv.invite_id
      and a.actor_id = v_uid
      and a.action = 'REVOKE'
      and a.success
  ) then
    return jsonb_build_object('ok', true, 'status', 'DECLINED',
      'replayed', true);
  end if;

  if v_inv.revoked_at is not null
     or v_inv.expires_at <= now()
     or v_inv.use_count >= v_inv.max_uses then
    return jsonb_build_object('ok', false, 'error', 'invite_not_available');
  end if;

  if not p_accept then
    update public.invite_tokens
       set revoked_at = now()
     where invite_id = v_inv.invite_id;
    insert into public.invite_audit(invite_id, actor_id, action, success)
    values (v_inv.invite_id, v_uid, 'REVOKE', true);
    return jsonb_build_object('ok', true, 'status', 'DECLINED');
  end if;

  insert into public.team_memberships(
    team_id, user_id, member_role, status, joined_at
  ) values (
    v_inv.team_id, v_uid, 'MEMBER', 'ACCEPTED', now()
  )
  on conflict (team_id, user_id) do update
    set status = 'ACCEPTED',
        joined_at = coalesce(public.team_memberships.joined_at, now());

  update public.invite_tokens
     set use_count = use_count + 1
   where invite_id = v_inv.invite_id;
  insert into public.invite_audit(invite_id, actor_id, action, success)
  values (v_inv.invite_id, v_uid, 'REDEEM', true);

  select coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Un giocatore')
    into v_member_name
  from public.profiles p where p.user_id = v_uid;
  select t.name into v_team_name from public.teams t where t.team_id = v_inv.team_id;

  perform private.enqueue_push_notification(
    v_inv.inviter_id,
    'TEAM_INVITE_ACCEPTED',
    'Invito team accettato',
    coalesce(v_member_name, 'Un giocatore') || ' è entrato in '
      || coalesce(nullif(v_team_name, ''), 'il tuo team') || '.',
    'rallymate://teams/' || v_inv.team_id::text,
    'team_invite:' || v_inv.invite_id || ':accepted',
    jsonb_build_object(
      'inviteId', v_inv.invite_id,
      'teamId', v_inv.team_id,
      'kind', 'team_invite'
    ),
    'NORMAL',
    interval '48 hours'
  );

  return jsonb_build_object(
    'ok', true,
    'status', 'ACCEPTED',
    'replayed', false,
    'teamId', v_inv.team_id
  );
end;
$$;

revoke all on function public.respond_team_invite(uuid, boolean)
  from public, anon;
grant execute on function public.respond_team_invite(uuid, boolean)
  to authenticated;

commit;
