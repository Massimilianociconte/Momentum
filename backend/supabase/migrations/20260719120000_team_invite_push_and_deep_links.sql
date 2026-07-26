-- Team invite push notifications + improved social deep links.
--
-- When a TEAM_JOIN invite targets a specific user, that user receives a push
-- with a deep link that opens the invite redeem screen. Match proposal deep
-- links land on the social inbox. Membership acceptance notifies the inviter.

-- Expand push kind vocabulary (idempotent: drop + recreate constraint).
alter table public.push_outbox
  drop constraint if exists push_outbox_kind_check;

alter table public.push_outbox
  add constraint push_outbox_kind_check check (kind in (
    'FRIEND_REQUEST',
    'FRIEND_ACCEPTED',
    'TEAM_REQUEST',
    'TEAM_REQUEST_ACCEPTED',
    'TEAM_INVITE',
    'TEAM_INVITE_ACCEPTED',
    'MATCH_PROPOSAL',
    'MATCH_PROPOSAL_ACCEPTED',
    'DUO_JOINED',
    'COACH_ASSIGNMENT',
    'COACH_PACKAGE_UPDATED',
    'TRAINING_REMINDER',
    'CRITICAL_SYNC',
    'ACCOUNT'
  ));

-- Match proposals open the social inbox so accept/reject is immediate.
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
        'rallymate://teams',
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

-- Targeted TEAM_JOIN / FRIEND invites → push to the recipient.
create or replace function private.enqueue_invite_push()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_inviter_name text;
  v_team_name text;
  v_token_hint text;
begin
  if new.target_user_id is null then
    return new;
  end if;
  if new.target_user_id = new.inviter_id then
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
      'rallymate://teams',
      'team_invite:' || new.invite_id || ':created',
      jsonb_build_object(
        'inviteId', new.invite_id,
        'teamId', new.team_id,
        'kind', new.kind,
        'tokenHint', new.token_hint
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

drop trigger if exists enqueue_invite_push on public.invite_tokens;
create trigger enqueue_invite_push
after insert on public.invite_tokens
for each row execute function private.enqueue_invite_push();

-- When a targeted team invite is redeemed (membership accepted), notify the owner.
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

drop trigger if exists enqueue_team_membership_push on public.team_memberships;
create trigger enqueue_team_membership_push
after insert or update of status on public.team_memberships
for each row execute function private.enqueue_team_membership_push();

revoke all on function private.enqueue_invite_push() from public, anon, authenticated;
revoke all on function private.enqueue_team_membership_push() from public, anon, authenticated;
