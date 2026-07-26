-- Rebrand remaining user-facing push/invite copy to Padelandia.
-- Deep link scheme rallymate:// intentionally unchanged.

begin;

create or replace function private.enqueue_invite_push()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_inviter_name text;
  v_team_name text;
begin
  if new.target_user_id is null or new.target_user_id = new.inviter_id then
    return new;
  end if;

  select coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Un giocatore')
    into v_inviter_name
  from public.profiles p
  where p.user_id = new.inviter_id;

  if new.kind = 'TEAM_JOIN' then
    select t.name into v_team_name from public.teams t where t.team_id = new.team_id;
    perform private.enqueue_push_notification(
      new.target_user_id,
      'TEAM_INVITE',
      'Invito nel team',
      coalesce(v_inviter_name, 'Un giocatore') || ' ti invita in '
        || coalesce(nullif(v_team_name, ''), 'un team Padelandia') || '.',
      'rallymate://social?focus=inbox&kind=team_invite&inviteId='
        || new.invite_id::text,
      'team_invite:' || new.invite_id || ':created',
      jsonb_build_object(
        'inviteId', new.invite_id,
        'teamId', new.team_id,
        'kind', 'team_invite'
      ),
      'HIGH',
      interval '48 hours'
    );
  elsif new.kind = 'FRIEND' then
    perform private.enqueue_push_notification(
      new.target_user_id,
      'FRIEND_REQUEST',
      'Invito amicizia',
      coalesce(v_inviter_name, 'Un giocatore') || ' ti ha inviato un invito amicizia.',
      'rallymate://friends?tab=requests',
      'friend_invite:' || new.invite_id || ':created',
      jsonb_build_object('inviteId', new.invite_id, 'kind', 'friend_invite'),
      'HIGH',
      interval '48 hours'
    );
  elsif new.kind = 'MATCH' then
    perform private.enqueue_push_notification(
      new.target_user_id,
      'MATCH_PROPOSAL',
      'Invito a una partita',
      coalesce(v_inviter_name, 'Un giocatore') || ' ti propone una partita.',
      'rallymate://social?focus=inbox&kind=proposal',
      'match_invite:' || new.invite_id || ':created',
      jsonb_build_object('inviteId', new.invite_id, 'kind', 'proposal'),
      'HIGH',
      interval '48 hours'
    );
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- social_inbox: include targeted team invites pending acceptance
-- ---------------------------------------------------------------------------

create or replace function private.enqueue_coach_package_push()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if (old.title, old.description, old.status)
       is distinct from (new.title, new.description, new.status) then
    insert into public.push_outbox(
      recipient_user_id, kind, title, body, deep_link, payload,
      dedupe_key, priority, expires_at
    )
    select distinct p.player_id,
      'COACH_PACKAGE_UPDATED', 'Percorso coach aggiornato',
      'Sono disponibili novità nel tuo percorso Padelandia.',
      'rallymate://coach/package/' || new.package_id,
      jsonb_build_object('packageId', new.package_id),
      'coach_package:' || new.package_id || ':' ||
        extract(epoch from transaction_timestamp())::bigint,
      'NORMAL', now() + interval '7 days'
    from public.coach_purchases p
    where p.package_id = new.package_id
      and p.status = 'PAID'
    on conflict (recipient_user_id, dedupe_key) do nothing;
  end if;
  return new;
end;
$$;


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
      v_inv.inviter_id, v_uid, 'Invito Padelandia confermato', 'ACCEPTED', now()
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
      v_inv.inviter_id, v_uid, 'Invito partita Padelandia confermato',
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
grant execute on function public.redeem_invite(text) to authenticated, service_role;

-- Refresh any still-queued outbox rows.
update public.push_outbox
set title = replace(title, 'RallyMate', 'Padelandia'),
    body = replace(body, 'RallyMate', 'Padelandia')
where title ilike '%RallyMate%' or body ilike '%RallyMate%';

commit;
