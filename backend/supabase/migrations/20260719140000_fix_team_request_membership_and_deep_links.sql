-- Fix team join acceptance (create membership), invite target enforcement,
-- and push deep links that land on the right in-app screens.

-- ---------------------------------------------------------------------------
-- 1. Accept team join → membership on owner's primary team
-- ---------------------------------------------------------------------------
create or replace function public.respond_social_item(
  p_kind text,
  p_item_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text := case when p_accept then 'ACCEPTED' else 'DECLINED' end;
  v_requester uuid;
  v_team uuid;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;

  if p_kind = 'proposal' then
    update public.match_proposals
       set status = v_status
     where proposal_id = p_item_id
       and receiver_id = auth.uid()
       and status = 'OPEN';
    if not found then
      return jsonb_build_object('ok', false, 'error', 'request_not_available');
    end if;
    return jsonb_build_object('ok', true, 'status', v_status);
  end if;

  if p_kind = 'team' then
    update public.team_join_requests
       set status = v_status
     where request_id = p_item_id
       and team_owner_id = auth.uid()
       and status = 'PENDING'
    returning requester_id into v_requester;
    if not found then
      return jsonb_build_object('ok', false, 'error', 'request_not_available');
    end if;
    if p_accept and v_requester is not null then
      select t.team_id into v_team
        from public.teams t
       where t.owner_id = auth.uid()
       order by t.created_at asc
       limit 1;
      if v_team is null then
        return jsonb_build_object(
          'ok', false,
          'error', 'team_not_found',
          'status', v_status
        );
      end if;
      insert into public.team_memberships(
        team_id, user_id, member_role, status, joined_at
      ) values (
        v_team, v_requester, 'MEMBER', 'ACCEPTED', now()
      )
      on conflict (team_id, user_id) do update
        set status = 'ACCEPTED',
            joined_at = coalesce(public.team_memberships.joined_at, now());
    end if;
    return jsonb_build_object(
      'ok', true,
      'status', v_status,
      'teamId', v_team
    );
  end if;

  return jsonb_build_object('ok', false, 'error', 'invalid_kind');
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. redeem_invite enforces target_user_id when set
-- ---------------------------------------------------------------------------
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
  if not found or v_inv.revoked_at is not null or v_inv.expires_at <= now()
     or v_inv.use_count >= v_inv.max_uses or v_inv.inviter_id = v_uid then
    insert into public.invite_audit(actor_id, action, success)
    values (v_uid, 'FAILED', false);
    return jsonb_build_object('ok', false, 'error', 'invite_not_available');
  end if;
  if v_inv.target_user_id is not null and v_inv.target_user_id <> v_uid then
    insert into public.invite_audit(invite_id, actor_id, action, success)
    values (v_inv.invite_id, v_uid, 'FAILED', false);
    return jsonb_build_object('ok', false, 'error', 'invite_not_for_you');
  end if;

  if v_inv.kind = 'FRIEND' then
    insert into public.social_contact_requests(
      requester_id, receiver_id, message, status, accepted_at
    ) values (
      v_inv.inviter_id, v_uid, 'Invito RallyMate confermato', 'ACCEPTED', now()
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
      v_inv.inviter_id, v_uid, 'Invito partita RallyMate confermato',
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
    'profileUserId', v_inv.target_user_id,
    'teamId', v_inv.team_id, 'matchId', v_inv.match_id,
    'duoSessionId', v_inv.duo_session_id,
    'format', case when v_inv.kind = 'DUO' then v_duo.format_json else null end,
    'myTeam', case when v_inv.kind = 'DUO' then v_my_team else null end);
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Push deep links → actionable screens
-- ---------------------------------------------------------------------------
create or replace function private.enqueue_social_push()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_table_name = 'social_contact_requests' then
    if tg_op = 'INSERT' then
      perform private.enqueue_push_notification(
        new.receiver_id, 'FRIEND_REQUEST', 'Nuova richiesta RallyMate',
        'Un giocatore vuole aggiungerti agli amici.',
        'rallymate://friends?tab=requests',
        'friend_request:' || new.request_id || ':created',
        jsonb_build_object('requestId', new.request_id), 'HIGH', interval '48 hours'
      );
    elsif old.status is distinct from new.status and new.status = 'ACCEPTED' then
      perform private.enqueue_push_notification(
        new.requester_id, 'FRIEND_ACCEPTED', 'Richiesta accettata',
        'Ora potete organizzare una partita insieme.',
        'rallymate://friends',
        'friend_request:' || new.request_id || ':accepted',
        jsonb_build_object('requestId', new.request_id), 'NORMAL', interval '48 hours'
      );
    end if;
  elsif tg_table_name = 'match_proposals' then
    if tg_op = 'INSERT' and new.receiver_id is not null then
      perform private.enqueue_push_notification(
        new.receiver_id, 'MATCH_PROPOSAL', 'Nuova proposta di partita',
        'Apri RallyMate per vedere e rispondere alla proposta.',
        'rallymate://social?focus=inbox',
        'match_proposal:' || new.proposal_id || ':created',
        jsonb_build_object('proposalId', new.proposal_id), 'HIGH', interval '48 hours'
      );
    elsif old.status is distinct from new.status and new.status = 'ACCEPTED' then
      perform private.enqueue_push_notification(
        new.creator_id, 'MATCH_PROPOSAL_ACCEPTED', 'Proposta accettata',
        'La proposta di partita è stata accettata.',
        'rallymate://social?focus=inbox',
        'match_proposal:' || new.proposal_id || ':accepted',
        jsonb_build_object('proposalId', new.proposal_id), 'HIGH', interval '48 hours'
      );
    end if;
  elsif tg_table_name = 'team_join_requests' then
    if tg_op = 'INSERT' then
      perform private.enqueue_push_notification(
        new.team_owner_id, 'TEAM_REQUEST', 'Nuova richiesta team',
        'Un giocatore vuole entrare nel tuo team.',
        'rallymate://social?focus=inbox',
        'team_request:' || new.request_id || ':created',
        jsonb_build_object('requestId', new.request_id), 'HIGH', interval '48 hours'
      );
    elsif old.status is distinct from new.status and new.status = 'ACCEPTED' then
      perform private.enqueue_push_notification(
        new.requester_id, 'TEAM_REQUEST_ACCEPTED', 'Richiesta team accettata',
        'Apri RallyMate per vedere il team aggiornato.',
        'rallymate://teams',
        'team_request:' || new.request_id || ':accepted',
        jsonb_build_object('requestId', new.request_id), 'NORMAL', interval '48 hours'
      );
    end if;
  end if;
  return new;
end;
$$;

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
    -- Token secret is not stored in cleartext; land on social/teams with inbox focus.
    perform private.enqueue_push_notification(
      new.target_user_id,
      'TEAM_INVITE',
      'Invito nel team',
      coalesce(v_inviter_name, 'Un giocatore') || ' ti invita in '
        || coalesce(nullif(v_team_name, ''), 'un team RallyMate') || '.',
      'rallymate://social?focus=inbox',
      'team_invite:' || new.invite_id || ':created',
      jsonb_build_object(
        'inviteId', new.invite_id,
        'teamId', new.team_id,
        'kind', new.kind
      ),
      'HIGH',
      interval '48 hours'
    );
  elsif new.kind = 'FRIEND' then
    perform private.enqueue_push_notification(
      new.target_user_id,
      'FRIEND_REQUEST',
      'Nuovo invito amicizia',
      coalesce(v_inviter_name, 'Un giocatore') || ' ti ha inviato un invito RallyMate.',
      'rallymate://friends?tab=requests',
      'friend_invite:' || new.invite_id || ':created',
      jsonb_build_object('inviteId', new.invite_id, 'kind', new.kind),
      'HIGH',
      interval '48 hours'
    );
  elsif new.kind = 'MATCH' then
    perform private.enqueue_push_notification(
      new.target_user_id,
      'MATCH_PROPOSAL',
      'Invito a una partita',
      coalesce(v_inviter_name, 'Un giocatore') || ' ti propone una partita.',
      'rallymate://social?focus=inbox',
      'match_invite:' || new.invite_id || ':created',
      jsonb_build_object('inviteId', new.invite_id, 'kind', new.kind),
      'HIGH',
      interval '48 hours'
    );
  end if;
  return new;
end;
$$;

create or replace function private.enqueue_team_membership_push()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner uuid;
  v_member_name text;
  v_team_name text;
begin
  if tg_op = 'INSERT' and new.status = 'ACCEPTED' then
    null;
  elsif tg_op = 'UPDATE'
    and old.status is distinct from new.status
    and new.status = 'ACCEPTED' then
    null;
  else
    return new;
  end if;

  select t.owner_id, t.name into v_owner, v_team_name
  from public.teams t where t.team_id = new.team_id;
  if v_owner is null or v_owner = new.user_id then
    return new;
  end if;

  select coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Un giocatore')
    into v_member_name
  from public.profiles p where p.user_id = new.user_id;

  -- Client resolves cloud UUID via cloudId / tm_cloud_ lookup.
  perform private.enqueue_push_notification(
    v_owner,
    'TEAM_INVITE_ACCEPTED',
    'Nuovo membro nel team',
    coalesce(v_member_name, 'Un giocatore') || ' è entrato in '
      || coalesce(nullif(v_team_name, ''), 'il tuo team') || '.',
    'rallymate://teams/' || new.team_id::text,
    'team_member:' || new.team_id || ':' || new.user_id || ':accepted',
    jsonb_build_object('teamId', new.team_id, 'userId', new.user_id),
    'NORMAL',
    interval '48 hours'
  );
  return new;
end;
$$;
