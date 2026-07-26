-- Production push notification outbox for RallyMate.
--
-- Client devices register only public APNs/FCM routing tokens through guarded
-- RPCs. Raw tokens and the outbox are never selectable by app roles. Social,
-- Duo and coach events enqueue idempotent rows; a server-side Edge Function
-- claims and dispatches them. Live score events intentionally never enqueue
-- push notifications.

create table public.push_devices (
  device_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  installation_id uuid not null,
  platform text not null check (platform in ('IOS', 'ANDROID', 'WATCHOS')),
  transport text not null check (transport in ('APNS', 'FCM')),
  environment text not null default 'PRODUCTION'
    check (environment in ('SANDBOX', 'PRODUCTION')),
  token text not null,
  app_version text not null default '',
  locale text not null default '',
  enabled boolean not null default true,
  last_seen_at timestamptz not null default now(),
  invalidated_at timestamptz,
  invalidation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint push_devices_token_shape check (
    (transport = 'APNS' and token ~ '^[0-9a-f]{64}$')
    or
    (transport = 'FCM' and char_length(token) between 20 and 4096
      and token !~ '[[:space:][:cntrl:]]')
  ),
  constraint push_devices_metadata_size check (
    char_length(app_version) <= 64
    and char_length(locale) <= 24
    and coalesce(char_length(invalidation_reason), 0) <= 160
  ),
  unique (transport, token),
  unique (user_id, installation_id, transport)
);

create index push_devices_active_owner_idx
  on public.push_devices(user_id, platform)
  where enabled = true;

alter table public.push_devices enable row level security;
revoke all on table public.push_devices from anon, authenticated;

create table public.push_outbox (
  notification_id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in (
    'FRIEND_REQUEST',
    'FRIEND_ACCEPTED',
    'TEAM_REQUEST',
    'TEAM_REQUEST_ACCEPTED',
    'MATCH_PROPOSAL',
    'MATCH_PROPOSAL_ACCEPTED',
    'DUO_JOINED',
    'COACH_ASSIGNMENT',
    'COACH_PACKAGE_UPDATED',
    'TRAINING_REMINDER',
    'CRITICAL_SYNC',
    'ACCOUNT'
  )),
  title text not null,
  body text not null,
  deep_link text,
  payload jsonb not null default '{}'::jsonb,
  dedupe_key text not null,
  priority text not null default 'NORMAL'
    check (priority in ('NORMAL', 'HIGH')),
  status text not null default 'PENDING'
    check (status in (
      'PENDING', 'PROCESSING', 'RETRY', 'SENT', 'PARTIAL', 'FAILED', 'SUPPRESSED'
    )),
  attempt_count int not null default 0 check (attempt_count between 0 and 8),
  next_attempt_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  claimed_at timestamptz,
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint push_outbox_content_size check (
    char_length(title) between 1 and 80
    and char_length(body) between 1 and 220
    and char_length(dedupe_key) between 1 and 180
    and coalesce(char_length(deep_link), 0) <= 512
    and coalesce(char_length(last_error), 0) <= 500
    and octet_length(payload::text) <= 4096
  ),
  constraint push_outbox_deep_link_shape check (
    deep_link is null or deep_link ~ '^rallymate://[a-zA-Z0-9]'
  ),
  unique (recipient_user_id, dedupe_key)
);

create index push_outbox_pending_idx
  on public.push_outbox(next_attempt_at, created_at)
  where status in ('PENDING', 'RETRY', 'PROCESSING');

alter table public.push_outbox enable row level security;
revoke all on table public.push_outbox from anon, authenticated;

create table public.push_deliveries (
  delivery_id bigint generated always as identity primary key,
  notification_id uuid not null
    references public.push_outbox(notification_id) on delete cascade,
  device_id uuid not null references public.push_devices(device_id) on delete cascade,
  attempt int not null check (attempt between 1 and 8),
  status text not null check (status in ('SENT', 'RETRY', 'INVALID', 'FAILED')),
  provider_message_id text,
  error_code text,
  created_at timestamptz not null default now(),
  constraint push_deliveries_diagnostics_size check (
    coalesce(char_length(provider_message_id), 0) <= 500
    and coalesce(char_length(error_code), 0) <= 160
  ),
  unique (notification_id, device_id, attempt)
);

create index push_deliveries_notification_idx
  on public.push_deliveries(notification_id, created_at desc);

alter table public.push_deliveries enable row level security;
revoke all on table public.push_deliveries from anon, authenticated;
grant usage, select on sequence public.push_deliveries_delivery_id_seq to service_role;

create or replace function public.register_my_push_device(
  p_installation_id uuid,
  p_platform text,
  p_transport text,
  p_environment text,
  p_token text,
  p_app_version text default '',
  p_locale text default ''
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_uid uuid := auth.uid();
  v_platform text := upper(trim(coalesce(p_platform, '')));
  v_transport text := upper(trim(coalesce(p_transport, '')));
  v_environment text := upper(trim(coalesce(p_environment, 'PRODUCTION')));
  v_token text := trim(coalesce(p_token, ''));
  v_device_id uuid;
begin
  if v_uid is null then
    raise sqlstate '42501' using message = 'authentication required';
  end if;
  if p_installation_id is null then
    raise sqlstate '22023' using message = 'installation id required';
  end if;
  if v_platform not in ('IOS', 'ANDROID', 'WATCHOS')
     or v_transport not in ('APNS', 'FCM')
     or v_environment not in ('SANDBOX', 'PRODUCTION') then
    raise sqlstate '22023' using message = 'invalid push device metadata';
  end if;
  if (v_transport = 'APNS' and v_token !~ '^[0-9a-f]{64}$')
     or (v_transport = 'FCM' and (
       char_length(v_token) not between 20 and 4096
       or v_token ~ '[[:space:][:cntrl:]]'
     )) then
    raise sqlstate '22023' using message = 'invalid push token';
  end if;

  -- A routing token belongs to one current installation/account. This safely
  -- handles account switching on the same physical device without exposing
  -- the previous owner or leaving a duplicate token behind.
  delete from public.push_devices
   where transport = v_transport
     and token = v_token
     and (user_id <> v_uid or installation_id <> p_installation_id);

  insert into public.push_devices(
    user_id, installation_id, platform, transport, environment, token,
    app_version, locale, enabled, last_seen_at, invalidated_at,
    invalidation_reason, updated_at
  ) values (
    v_uid, p_installation_id, v_platform, v_transport, v_environment, v_token,
    left(coalesce(p_app_version, ''), 64), left(coalesce(p_locale, ''), 24),
    true, now(), null, null, now()
  )
  on conflict (user_id, installation_id, transport) do update set
    platform = excluded.platform,
    environment = excluded.environment,
    token = excluded.token,
    app_version = excluded.app_version,
    locale = excluded.locale,
    enabled = true,
    last_seen_at = now(),
    invalidated_at = null,
    invalidation_reason = null,
    updated_at = now()
  returning device_id into v_device_id;

  return jsonb_build_object('ok', true, 'deviceId', v_device_id);
end;
$$;

create or replace function public.deactivate_my_push_device(
  p_installation_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_uid uuid := auth.uid();
  v_count int;
begin
  if v_uid is null then
    raise sqlstate '42501' using message = 'authentication required';
  end if;
  update public.push_devices
     set enabled = false,
         invalidated_at = now(),
         invalidation_reason = 'client_disabled',
         updated_at = now()
   where user_id = v_uid
     and installation_id = p_installation_id
     and enabled = true;
  get diagnostics v_count = row_count;
  return jsonb_build_object('ok', true, 'deactivated', v_count);
end;
$$;

create or replace function public.my_push_device_status()
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'configured', count(*) filter (where enabled),
    'lastSeenAt', max(last_seen_at) filter (where enabled)
  )
  from public.push_devices
  where user_id = auth.uid();
$$;

create or replace function public.claim_push_notifications(p_limit int default 50)
returns setof public.push_outbox
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.push_outbox
     set status = 'FAILED',
         updated_at = now(),
         last_error = coalesce(last_error, 'expired_or_attempts_exhausted')
   where status in ('PENDING', 'RETRY', 'PROCESSING')
     and (expires_at <= now() or (
       attempt_count >= 8
       and (status <> 'PROCESSING' or claimed_at < now() - interval '5 minutes')
     ));

  -- Recover jobs left in PROCESSING after a worker crash without immediately
  -- issuing duplicates while a healthy worker is still running.
  update public.push_outbox
     set status = 'RETRY',
         next_attempt_at = now(),
         updated_at = now(),
         last_error = 'stale_processing_lease'
   where status = 'PROCESSING'
     and claimed_at < now() - interval '5 minutes'
     and attempt_count < 8;

  return query
  with candidates as (
    select notification_id
      from public.push_outbox
     where status in ('PENDING', 'RETRY')
       and next_attempt_at <= now()
       and expires_at > now()
       and attempt_count < 8
     order by case priority when 'HIGH' then 0 else 1 end, created_at
     for update skip locked
     limit greatest(1, least(coalesce(p_limit, 50), 100))
  )
  update public.push_outbox o
     set status = 'PROCESSING',
         attempt_count = o.attempt_count + 1,
         claimed_at = now(),
         updated_at = now()
    from candidates c
   where o.notification_id = c.notification_id
  returning o.*;

end;
$$;

create or replace function private.enqueue_push_notification(
  p_recipient uuid,
  p_kind text,
  p_title text,
  p_body text,
  p_deep_link text,
  p_dedupe_key text,
  p_payload jsonb default '{}'::jsonb,
  p_priority text default 'NORMAL',
  p_expires_in interval default interval '24 hours'
) returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if p_recipient is null then return; end if;
  insert into public.push_outbox(
    recipient_user_id, kind, title, body, deep_link, payload,
    dedupe_key, priority, expires_at
  ) values (
    p_recipient, p_kind, p_title, p_body, p_deep_link,
    coalesce(p_payload, '{}'::jsonb), p_dedupe_key, p_priority,
    now() + greatest(interval '5 minutes', least(p_expires_in, interval '7 days'))
  ) on conflict (recipient_user_id, dedupe_key) do nothing;
end;
$$;

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
        'Un giocatore vuole aggiungerti agli amici.', 'rallymate://friends',
        'friend_request:' || new.request_id || ':created',
        jsonb_build_object('requestId', new.request_id), 'HIGH', interval '48 hours'
      );
    elsif old.status is distinct from new.status and new.status = 'ACCEPTED' then
      perform private.enqueue_push_notification(
        new.requester_id, 'FRIEND_ACCEPTED', 'Richiesta accettata',
        'Ora potete organizzare una partita insieme.', 'rallymate://friends',
        'friend_request:' || new.request_id || ':accepted',
        jsonb_build_object('requestId', new.request_id), 'NORMAL', interval '48 hours'
      );
    end if;
  elsif tg_table_name = 'match_proposals' then
    if tg_op = 'INSERT' and new.receiver_id is not null then
      perform private.enqueue_push_notification(
        new.receiver_id, 'MATCH_PROPOSAL', 'Nuova proposta di partita',
        'Apri RallyMate per vedere e rispondere alla proposta.', 'rallymate://social',
        'match_proposal:' || new.proposal_id || ':created',
        jsonb_build_object('proposalId', new.proposal_id), 'HIGH', interval '48 hours'
      );
    elsif old.status is distinct from new.status and new.status = 'ACCEPTED' then
      perform private.enqueue_push_notification(
        new.creator_id, 'MATCH_PROPOSAL_ACCEPTED', 'Proposta accettata',
        'La proposta di partita è stata accettata.', 'rallymate://social',
        'match_proposal:' || new.proposal_id || ':accepted',
        jsonb_build_object('proposalId', new.proposal_id), 'HIGH', interval '48 hours'
      );
    end if;
  elsif tg_table_name = 'team_join_requests' then
    if tg_op = 'INSERT' then
      perform private.enqueue_push_notification(
        new.team_owner_id, 'TEAM_REQUEST', 'Nuova richiesta team',
        'Un giocatore vuole entrare nel tuo team.', 'rallymate://teams',
        'team_request:' || new.request_id || ':created',
        jsonb_build_object('requestId', new.request_id), 'HIGH', interval '48 hours'
      );
    elsif old.status is distinct from new.status and new.status = 'ACCEPTED' then
      perform private.enqueue_push_notification(
        new.requester_id, 'TEAM_REQUEST_ACCEPTED', 'Richiesta team accettata',
        'Apri RallyMate per vedere il team aggiornato.', 'rallymate://teams',
        'team_request:' || new.request_id || ':accepted',
        jsonb_build_object('requestId', new.request_id), 'NORMAL', interval '48 hours'
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists enqueue_contact_push on public.social_contact_requests;
create trigger enqueue_contact_push
after insert or update of status on public.social_contact_requests
for each row execute function private.enqueue_social_push();

drop trigger if exists enqueue_match_proposal_push on public.match_proposals;
create trigger enqueue_match_proposal_push
after insert or update of status on public.match_proposals
for each row execute function private.enqueue_social_push();

drop trigger if exists enqueue_team_request_push on public.team_join_requests;
create trigger enqueue_team_request_push
after insert or update of status on public.team_join_requests
for each row execute function private.enqueue_social_push();

create or replace function private.enqueue_duo_join_push()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if old.guest_id is null and new.guest_id is not null then
    perform private.enqueue_push_notification(
      new.creator_id, 'DUO_JOINED', 'Duo Mode collegata',
      'Il secondo team è entrato nella partita.',
      'rallymate://match/' || new.match_id || '/duo',
      'duo:' || new.session_id || ':guest_joined',
      jsonb_build_object('sessionId', new.session_id, 'matchId', new.match_id),
      'HIGH', interval '6 hours'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists enqueue_duo_join_push on public.duo_sessions;
create trigger enqueue_duo_join_push
after update of guest_id on public.duo_sessions
for each row execute function private.enqueue_duo_join_push();

create or replace function private.enqueue_coach_push()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_table_name = 'coach_assignments' and tg_op = 'INSERT' then
    perform private.enqueue_push_notification(
      new.player_id, 'COACH_ASSIGNMENT', 'Nuovo allenamento assegnato',
      'Il tuo coach ha aggiornato il percorso di training.',
      'rallymate://training',
      'coach_assignment:' || new.assignment_id || ':created',
      jsonb_build_object('assignmentId', new.assignment_id),
      'NORMAL', interval '7 days'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists enqueue_coach_assignment_push on public.coach_assignments;
create trigger enqueue_coach_assignment_push
after insert on public.coach_assignments
for each row execute function private.enqueue_coach_push();

-- coach_packages has no updated_at in the original schema. Use the current
-- transaction timestamp in the dedupe key while preserving deterministic
-- uniqueness for a single update statement.
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
      'Sono disponibili novità nel tuo percorso RallyMate.',
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

drop trigger if exists enqueue_coach_package_push on public.coach_packages;
create trigger enqueue_coach_package_push
after update of title, description, status on public.coach_packages
for each row execute function private.enqueue_coach_package_push();

revoke all on function public.register_my_push_device(
  uuid, text, text, text, text, text, text
) from public, anon;
grant execute on function public.register_my_push_device(
  uuid, text, text, text, text, text, text
) to authenticated;

revoke all on function public.deactivate_my_push_device(uuid) from public, anon;
grant execute on function public.deactivate_my_push_device(uuid) to authenticated;

revoke all on function public.my_push_device_status() from public, anon;
grant execute on function public.my_push_device_status() to authenticated;

revoke all on function public.claim_push_notifications(int) from public, anon, authenticated;
grant execute on function public.claim_push_notifications(int) to service_role;

revoke all on function private.enqueue_push_notification(
  uuid, text, text, text, text, text, jsonb, text, interval
) from public, anon, authenticated;
revoke all on function private.enqueue_social_push() from public, anon, authenticated;
revoke all on function private.enqueue_duo_join_push() from public, anon, authenticated;
revoke all on function private.enqueue_coach_push() from public, anon, authenticated;
revoke all on function private.enqueue_coach_package_push() from public, anon, authenticated;

comment on table public.push_devices is
  'Private APNs/FCM routing tokens. App roles use guarded RPCs and cannot read tokens.';
comment on table public.push_outbox is
  'Idempotent remote-notification jobs. Live score events are intentionally excluded.';
comment on function public.claim_push_notifications(int) is
  'Claims a bounded batch with SKIP LOCKED and a five-minute crash-recovery lease.';
