-- Complete social invite flows:
-- * personalized push + precise deep links (friend / team invite / match proposal)
-- * targeted team invites appear in social_inbox and can be accepted without token
-- * match proposal accept allocates linked_match_id for mutual follow-up
-- * create_invite with target_user_id enqueues TEAM_INVITE / MATCH push with invite path

begin;

-- ---------------------------------------------------------------------------
-- Personalized social push with precise deep links
-- ---------------------------------------------------------------------------
create or replace function private.enqueue_social_push()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_name text;
begin
  if tg_table_name = 'social_contact_requests' then
    if tg_op = 'INSERT' then
      select coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Un giocatore')
        into v_name
      from public.profiles p where p.user_id = new.requester_id;
      perform private.enqueue_push_notification(
        new.receiver_id,
        'FRIEND_REQUEST',
        'Nuova richiesta di amicizia',
        coalesce(v_name, 'Un giocatore') || ' vuole aggiungerti agli amici.',
        'rallymate://friends?tab=requests',
        'friend_request:' || new.request_id || ':created',
        jsonb_build_object(
          'requestId', new.request_id,
          'fromUserId', new.requester_id,
          'kind', 'contact'
        ),
        'HIGH',
        interval '48 hours'
      );
    elsif old.status is distinct from new.status and new.status = 'ACCEPTED' then
      select coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Un giocatore')
        into v_name
      from public.profiles p where p.user_id = new.receiver_id;
      perform private.enqueue_push_notification(
        new.requester_id,
        'FRIEND_ACCEPTED',
        'Richiesta accettata',
        coalesce(v_name, 'Un giocatore') || ' ha accettato la tua amicizia.',
        'rallymate://friends',
        'friend_request:' || new.request_id || ':accepted',
        jsonb_build_object(
          'requestId', new.request_id,
          'fromUserId', new.receiver_id,
          'kind', 'contact'
        ),
        'NORMAL',
        interval '48 hours'
      );
    end if;
  elsif tg_table_name = 'match_proposals' then
    if tg_op = 'INSERT' and new.receiver_id is not null then
      select coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Un giocatore')
        into v_name
      from public.profiles p where p.user_id = new.creator_id;
      perform private.enqueue_push_notification(
        new.receiver_id,
        'MATCH_PROPOSAL',
        'Proposta di partita',
        coalesce(v_name, 'Un giocatore') || ' ti propone una partita. Apri per accettare.',
        'rallymate://social?focus=inbox&kind=proposal',
        'match_proposal:' || new.proposal_id || ':created',
        jsonb_build_object(
          'proposalId', new.proposal_id,
          'fromUserId', new.creator_id,
          'kind', 'proposal'
        ),
        'HIGH',
        interval '48 hours'
      );
    elsif old.status is distinct from new.status and new.status = 'ACCEPTED' then
      select coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Un giocatore')
        into v_name
      from public.profiles p where p.user_id = new.receiver_id;
      perform private.enqueue_push_notification(
        new.creator_id,
        'MATCH_PROPOSAL_ACCEPTED',
        'Proposta accettata',
        coalesce(v_name, 'Un giocatore')
          || ' ha accettato. Apri e crea la partita.',
        'rallymate://match/new?opponentName='
          || replace(coalesce(v_name, 'Avversario'), ' ', '%20')
          || case
               when new.linked_match_id is not null
                 then '&linkedMatchId=' || new.linked_match_id
               else ''
             end
          || '&proposalId=' || new.proposal_id::text,
        'match_proposal:' || new.proposal_id || ':accepted',
        jsonb_build_object(
          'proposalId', new.proposal_id,
          'linkedMatchId', new.linked_match_id,
          'fromUserId', new.receiver_id,
          'kind', 'proposal'
        ),
        'HIGH',
        interval '48 hours'
      );
    end if;
  elsif tg_table_name = 'team_join_requests' then
    if tg_op = 'INSERT' then
      select coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Un giocatore')
        into v_name
      from public.profiles p where p.user_id = new.requester_id;
      perform private.enqueue_push_notification(
        new.team_owner_id,
        'TEAM_REQUEST',
        'Richiesta di entrare nel team',
        coalesce(v_name, 'Un giocatore') || ' vuole entrare nel tuo team.',
        'rallymate://social?focus=inbox&kind=team',
        'team_request:' || new.request_id || ':created',
        jsonb_build_object(
          'requestId', new.request_id,
          'fromUserId', new.requester_id,
          'kind', 'team'
        ),
        'HIGH',
        interval '48 hours'
      );
    elsif old.status is distinct from new.status and new.status = 'ACCEPTED' then
      select coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Un giocatore')
        into v_name
      from public.profiles p where p.user_id = new.team_owner_id;
      perform private.enqueue_push_notification(
        new.requester_id,
        'TEAM_REQUEST_ACCEPTED',
        'Sei entrato nel team',
        coalesce(v_name, 'Un giocatore') || ' ha accettato la tua richiesta team.',
        'rallymate://teams',
        'team_request:' || new.request_id || ':accepted',
        jsonb_build_object(
          'requestId', new.request_id,
          'teamId', new.target_team_id,
          'kind', 'team'
        ),
        'NORMAL',
        interval '48 hours'
      );
    end if;
  end if;
  return new;
end;
$$;

-- Targeted invites: deep link opens social inbox (accept without raw token).
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
        || coalesce(nullif(v_team_name, ''), 'un team RallyMate') || '.',
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
-- The previous signature returned 6 columns; `create or replace` cannot change
-- a function's return type (42P13), so the old one is dropped first and the
-- grants are restored right after the new definition.
drop function if exists public.social_inbox();

create function public.social_inbox()
returns table (
  item_id uuid,
  kind text,
  from_user_id uuid,
  from_name text,
  message text,
  created_at timestamptz,
  meta jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select r.request_id,
         'contact'::text,
         r.requester_id,
         coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Giocatore'),
         r.message,
         r.created_at,
         jsonb_build_object('kind', 'contact')
  from public.social_contact_requests r
  join public.profiles p on p.user_id = r.requester_id
  where r.receiver_id = auth.uid() and r.status = 'PENDING'
    and not exists (
      select 1 from public.user_blocks b
      where b.blocker_id = auth.uid() and b.blocked_id = r.requester_id
    )
  union all
  select m.proposal_id,
         'proposal'::text,
         m.creator_id,
         coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Giocatore'),
         m.message,
         m.created_at,
         jsonb_build_object(
           'kind', 'proposal',
           'levelHint', m.level_hint,
           'linkedMatchId', m.linked_match_id
         )
  from public.match_proposals m
  join public.profiles p on p.user_id = m.creator_id
  where m.receiver_id = auth.uid() and m.status = 'OPEN'
    and not exists (
      select 1 from public.user_blocks b
      where b.blocker_id = auth.uid() and b.blocked_id = m.creator_id
    )
  union all
  select t.request_id,
         'team'::text,
         t.requester_id,
         coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Giocatore'),
         t.message,
         t.created_at,
         jsonb_build_object(
           'kind', 'team',
           'targetTeamId', t.target_team_id
         )
  from public.team_join_requests t
  join public.profiles p on p.user_id = t.requester_id
  where t.team_owner_id = auth.uid() and t.status = 'PENDING'
  union all
  -- Owner invited me into their team (targeted invite token).
  select i.invite_id,
         'team_invite'::text,
         i.inviter_id,
         coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Giocatore'),
         coalesce('Ti invita in ' || nullif(tm.name, ''), 'Invito nel team'),
         i.created_at,
         jsonb_build_object(
           'kind', 'team_invite',
           'teamId', i.team_id,
           'teamName', coalesce(tm.name, ''),
           'inviteId', i.invite_id
         )
  from public.invite_tokens i
  join public.profiles p on p.user_id = i.inviter_id
  left join public.teams tm on tm.team_id = i.team_id
  where i.target_user_id = auth.uid()
    and i.kind = 'TEAM_JOIN'
    and i.revoked_at is null
    and i.expires_at > now()
    and i.use_count < i.max_uses
  order by created_at desc;
$$;

-- ---------------------------------------------------------------------------
-- Accept / decline targeted team invite (no cleartext token needed)
-- ---------------------------------------------------------------------------
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
     or v_inv.kind <> 'TEAM_JOIN'
     or v_inv.revoked_at is not null
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
    'teamId', v_inv.team_id
  );
end;
$$;

revoke all on function public.respond_team_invite(uuid, boolean)
  from public, anon;
grant execute on function public.respond_team_invite(uuid, boolean)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Match proposal accept: allocate linked_match_id for mutual follow-up
-- Team join accept: keep membership logic from polish migration
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
  v_target uuid;
  v_linked text;
  v_creator uuid;
  v_creator_name text;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;

  if p_kind = 'proposal' then
    if p_accept then
      v_linked := 'mp_' || replace(gen_random_uuid()::text, '-', '');
      update public.match_proposals
         set status = 'ACCEPTED',
             linked_match_id = coalesce(linked_match_id, v_linked)
       where proposal_id = p_item_id
         and receiver_id = auth.uid()
         and status = 'OPEN'
      returning creator_id, linked_match_id into v_creator, v_linked;
    else
      update public.match_proposals
         set status = 'DECLINED'
       where proposal_id = p_item_id
         and receiver_id = auth.uid()
         and status = 'OPEN'
      returning creator_id into v_creator;
    end if;
    if not found then
      return jsonb_build_object('ok', false, 'error', 'request_not_available');
    end if;
    select coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Giocatore')
      into v_creator_name
    from public.profiles p where p.user_id = v_creator;
    return jsonb_build_object(
      'ok', true,
      'status', v_status,
      'linkedMatchId', v_linked,
      'creatorId', v_creator,
      'creatorName', coalesce(v_creator_name, 'Giocatore'),
      'proposalId', p_item_id
    );
  end if;

  if p_kind = 'team' then
    update public.team_join_requests
       set status = v_status
     where request_id = p_item_id
       and team_owner_id = auth.uid()
       and status = 'PENDING'
    returning requester_id, target_team_id into v_requester, v_target;
    if not found then
      return jsonb_build_object('ok', false, 'error', 'request_not_available');
    end if;
    if p_accept and v_requester is not null then
      if v_target is not null then
        select t.team_id into v_team
          from public.teams t
         where t.team_id = v_target
           and t.owner_id = auth.uid()
         limit 1;
      end if;
      if v_team is null then
        select t.team_id into v_team
          from public.teams t
         where t.owner_id = auth.uid()
         order by t.updated_at desc nulls last, t.created_at desc
         limit 1;
      end if;
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

  if p_kind = 'team_invite' then
    return public.respond_team_invite(p_item_id, p_accept);
  end if;

  return jsonb_build_object('ok', false, 'error', 'invalid_kind');
end;
$$;

revoke all on function public.respond_social_item(text, uuid, boolean)
  from public, anon;
grant execute on function public.respond_social_item(text, uuid, boolean)
  to authenticated;

-- Convenience RPC: invite a specific user into my cloud team.
create or replace function public.invite_user_to_my_team(
  p_team_id uuid,
  p_target_user_id uuid,
  p_message text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if p_team_id is null or p_target_user_id is null or p_target_user_id = v_uid then
    return jsonb_build_object('ok', false, 'error', 'invalid_receiver');
  end if;
  if not exists (
    select 1 from public.teams t
    where t.team_id = p_team_id and t.owner_id = v_uid
  ) then
    return jsonb_build_object('ok', false, 'error', 'team_not_owned');
  end if;
  if exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = v_uid and b.blocked_id = p_target_user_id)
       or (b.blocker_id = p_target_user_id and b.blocked_id = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_available');
  end if;
  if exists (
    select 1 from public.team_memberships m
    where m.team_id = p_team_id
      and m.user_id = p_target_user_id
      and m.status = 'ACCEPTED'
  ) then
    return jsonb_build_object('ok', false, 'error', 'already_member');
  end if;

  -- Reuse create_invite so hashing / rate limits stay consistent.
  v_result := public.create_invite(
    p_kind := 'TEAM_JOIN',
    p_team_id := p_team_id,
    p_target_user_id := p_target_user_id,
    p_ttl_minutes := 2880
  );
  if (v_result->>'ok')::boolean is distinct from true then
    return v_result;
  end if;
  return jsonb_build_object(
    'ok', true,
    'inviteId', v_result->>'inviteId',
    'token', v_result->>'token',
    'code', v_result->>'code',
    'expiresAt', v_result->>'expiresAt',
    'status', 'PENDING'
  );
end;
$$;

revoke all on function public.invite_user_to_my_team(uuid, uuid, text)
  from public, anon;
grant execute on function public.invite_user_to_my_team(uuid, uuid, text)
  to authenticated;

-- Dropping social_inbox() removed its grants: restore the same surface the
-- reconciliation migration established.
revoke all on function public.social_inbox() from public, anon;
grant execute on function public.social_inbox() to authenticated, service_role;

commit;
