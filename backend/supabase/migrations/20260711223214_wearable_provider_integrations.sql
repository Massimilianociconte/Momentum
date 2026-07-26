-- Native provider wearables: Garmin Connect IQ, Fitbit OS and Google Health.
--
-- Security model:
--   * provider refresh/access tokens are encrypted by Edge Functions before
--     storage; no client role can read the token tables;
--   * Fitbit/Garmin device credentials are opaque, random and stored only as
--     SHA-256 hashes;
--   * pairing codes are short-lived, one-time and rate-limited by the gateway;
--   * health summaries are the only provider-health records exposed to the
--     owner, and only after explicit Google Health consent;
--   * every wearable score event has a provider-scoped idempotency key.

create table public.wearable_provider_connections (
  connection_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  provider text not null check (provider in ('GOOGLE_HEALTH', 'FITBIT_OS', 'GARMIN_CONNECT_IQ')),
  status text not null default 'PENDING'
    check (status in ('PENDING', 'CONNECTED', 'REFRESH_REQUIRED', 'REVOKED', 'ERROR')),
  provider_subject_hash text,
  access_token_ciphertext text,
  access_token_iv text,
  refresh_token_ciphertext text,
  refresh_token_iv text,
  token_expires_at timestamptz,
  scopes text[] not null default '{}',
  consented_at timestamptz,
  last_sync_at timestamptz,
  last_error_code text,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, provider)
);

create table public.wearable_oauth_states (
  state_hash text primary key,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  provider text not null check (provider = 'GOOGLE_HEALTH'),
  redirect_after text not null default 'rallymate://devices/google-health',
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at <= created_at + interval '15 minutes')
);

create table public.wearable_pairing_challenges (
  challenge_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  provider text not null check (provider in ('FITBIT_OS', 'GARMIN_CONNECT_IQ')),
  code_hash text not null unique,
  attempts smallint not null default 0 check (attempts between 0 and 10),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at <= created_at + interval '15 minutes')
);

create table public.wearable_device_tokens (
  token_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  provider text not null check (provider in ('FITBIT_OS', 'GARMIN_CONNECT_IQ')),
  token_hash text not null unique,
  display_name text not null default '',
  capabilities text[] not null default '{}',
  expires_at timestamptz not null,
  last_seen_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at <= created_at + interval '180 days')
);

create table public.wearable_gateway_rate_events (
  event_id bigint generated always as identity primary key,
  actor_hash text not null,
  action text not null check (action in ('CLAIM', 'INGEST')),
  success boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.wearable_ingest_events (
  ingest_id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  provider text not null check (provider in ('FITBIT_OS', 'GARMIN_CONNECT_IQ')),
  external_event_id text not null,
  match_id text not null,
  event_type text not null check (
    event_type in (
      'MATCH_STARTED', 'POINT_TEAM_A', 'POINT_TEAM_B', 'UNDO',
      'MATCH_PAUSED', 'MATCH_RESUMED', 'MATCH_COMPLETED'
    )
  ),
  event_at timestamptz not null,
  payload jsonb not null default '{}',
  delivered_at timestamptz,
  acknowledged_at timestamptz,
  created_at timestamptz not null default now(),
  unique (provider, external_event_id),
  check (char_length(external_event_id) between 8 and 128),
  check (char_length(match_id) between 3 and 128),
  check (pg_column_size(payload) <= 8192)
);

create table public.wearable_daily_health_summaries (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  provider text not null check (provider = 'GOOGLE_HEALTH'),
  local_date date not null,
  timezone text not null,
  steps integer not null default 0 check (steps between 0 and 500000),
  active_energy_kcal numeric(10,2) not null default 0
    check (active_energy_kcal between 0 and 100000),
  exercise_minutes integer not null default 0 check (exercise_minutes between 0 and 1440),
  average_heart_rate_bpm numeric(6,2)
    check (average_heart_rate_bpm is null or average_heart_rate_bpm between 20 and 300),
  source_updated_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, provider, local_date)
);

create table public.wearable_health_notifications (
  notification_id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  notification_hash text not null unique,
  data_type text not null,
  local_date date,
  processed_at timestamptz,
  created_at timestamptz not null default now()
);

create index wearable_provider_connections_user_status_idx
  on public.wearable_provider_connections(user_id, status);
create index wearable_oauth_states_expiry_idx
  on public.wearable_oauth_states(expires_at) where consumed_at is null;
create index wearable_pairing_challenges_expiry_idx
  on public.wearable_pairing_challenges(expires_at) where consumed_at is null;
create index wearable_device_tokens_owner_idx
  on public.wearable_device_tokens(user_id, provider)
  where revoked_at is null;
create index wearable_gateway_rate_window_idx
  on public.wearable_gateway_rate_events(actor_hash, action, created_at desc);
create index wearable_ingest_events_delivery_idx
  on public.wearable_ingest_events(user_id, ingest_id)
  where acknowledged_at is null;
create index wearable_health_summary_recent_idx
  on public.wearable_daily_health_summaries(user_id, local_date desc);
create index wearable_health_notifications_pending_idx
  on public.wearable_health_notifications(user_id, notification_id)
  where processed_at is null;
create unique index wearable_provider_subject_idx
  on public.wearable_provider_connections(provider, provider_subject_hash)
  where provider_subject_hash is not null and status = 'CONNECTED';

alter table public.wearable_provider_connections enable row level security;
alter table public.wearable_oauth_states enable row level security;
alter table public.wearable_pairing_challenges enable row level security;
alter table public.wearable_device_tokens enable row level security;
alter table public.wearable_gateway_rate_events enable row level security;
alter table public.wearable_ingest_events enable row level security;
alter table public.wearable_daily_health_summaries enable row level security;
alter table public.wearable_health_notifications enable row level security;

create policy "owner reads wearable health summaries"
  on public.wearable_daily_health_summaries
  for select to authenticated
  using ((select auth.uid()) = user_id);

-- Data API exposure is explicit for new Supabase projects (April 2026 change).
-- Sensitive provider tables remain service-role-only even with RLS enabled.
revoke all on table public.wearable_provider_connections from anon, authenticated;
revoke all on table public.wearable_oauth_states from anon, authenticated;
revoke all on table public.wearable_pairing_challenges from anon, authenticated;
revoke all on table public.wearable_device_tokens from anon, authenticated;
revoke all on table public.wearable_gateway_rate_events from anon, authenticated;
revoke all on table public.wearable_ingest_events from anon, authenticated;
revoke all on table public.wearable_daily_health_summaries from anon, authenticated;
revoke all on table public.wearable_health_notifications from anon, authenticated;
grant select on table public.wearable_daily_health_summaries to authenticated;

grant select, insert, update, delete on table
  public.wearable_provider_connections,
  public.wearable_oauth_states,
  public.wearable_pairing_challenges,
  public.wearable_device_tokens,
  public.wearable_gateway_rate_events,
  public.wearable_ingest_events,
  public.wearable_daily_health_summaries,
  public.wearable_health_notifications
to service_role;
grant usage, select on sequence public.wearable_ingest_events_ingest_id_seq
  to service_role;
grant usage, select on sequence public.wearable_gateway_rate_events_event_id_seq
  to service_role;
grant usage, select on sequence public.wearable_health_notifications_notification_id_seq
  to service_role;

create or replace function public.my_wearable_connections()
returns table (
  provider text,
  status text,
  scopes text[],
  consented_at timestamptz,
  last_sync_at timestamptz,
  active_devices bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.provider,
    c.status,
    c.scopes,
    c.consented_at,
    c.last_sync_at,
    (
      select count(*)
      from public.wearable_device_tokens d
      where d.user_id = c.user_id
        and d.provider = c.provider
        and d.revoked_at is null
        and d.expires_at > now()
    ) as active_devices
  from public.wearable_provider_connections c
  where c.user_id = auth.uid()
  order by c.provider;
$$;

revoke all on function public.my_wearable_connections() from public;
grant execute on function public.my_wearable_connections() to authenticated;

create or replace function public.claim_wearable_pairing(
  p_code_hash text,
  p_provider text,
  p_token_hash text,
  p_display_name text,
  p_capabilities text[],
  p_expires_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_challenge public.wearable_pairing_challenges%rowtype;
  v_allowed boolean;
begin
  if p_provider not in ('FITBIT_OS', 'GARMIN_CONNECT_IQ') then
    raise exception 'invalid_provider';
  end if;
  if char_length(coalesce(p_display_name, '')) > 80
     or cardinality(coalesce(p_capabilities, '{}')) > 16
     or p_expires_at > now() + interval '90 days' then
    raise exception 'invalid_pairing_payload';
  end if;

  select * into v_challenge
  from public.wearable_pairing_challenges
  where code_hash = p_code_hash
    and provider = p_provider
  for update;

  if v_challenge.challenge_id is null
     or v_challenge.consumed_at is not null
     or v_challenge.expires_at <= now()
     or v_challenge.attempts >= 10 then
    raise exception 'invalid_pairing';
  end if;

  select exists (
    select 1 from public.profiles p
    where p.user_id = v_challenge.user_id
      and (
        p.plan in ('plus', 'pro', 'coach')
        or p.premium_override
        or p.account_role in ('admin', 'super_admin')
      )
  ) into v_allowed;
  if not v_allowed then raise exception 'plan_required'; end if;

  update public.wearable_pairing_challenges
  set attempts = attempts + 1,
      consumed_at = now()
  where challenge_id = v_challenge.challenge_id;

  insert into public.wearable_device_tokens(
    user_id, provider, token_hash, display_name, capabilities, expires_at,
    last_seen_at
  ) values (
    v_challenge.user_id,
    p_provider,
    p_token_hash,
    left(trim(coalesce(p_display_name, '')), 80),
    coalesce(p_capabilities, '{}'),
    p_expires_at,
    now()
  );

  insert into public.wearable_provider_connections(
    user_id, provider, status, consented_at, updated_at
  ) values (
    v_challenge.user_id, p_provider, 'CONNECTED', now(), now()
  )
  on conflict (user_id, provider) do update set
    status = 'CONNECTED',
    consented_at = coalesce(
      public.wearable_provider_connections.consented_at,
      excluded.consented_at
    ),
    revoked_at = null,
    last_error_code = null,
    updated_at = now();

  return v_challenge.user_id;
end;
$$;

revoke all on function public.claim_wearable_pairing(
  text, text, text, text, text[], timestamptz
) from public;
grant execute on function public.claim_wearable_pairing(
  text, text, text, text, text[], timestamptz
) to service_role;

create or replace function public.consume_wearable_oauth_state(p_state_hash text)
returns table(user_id uuid, redirect_after text)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  update public.wearable_oauth_states s
  set consumed_at = now()
  where s.state_hash = p_state_hash
    and s.provider = 'GOOGLE_HEALTH'
    and s.consumed_at is null
    and s.expires_at > now()
  returning s.user_id, s.redirect_after;
end;
$$;

revoke all on function public.consume_wearable_oauth_state(text) from public;
grant execute on function public.consume_wearable_oauth_state(text) to service_role;

comment on table public.wearable_provider_connections is
  'Server-only encrypted OAuth/provider connection material.';
comment on table public.wearable_device_tokens is
  'Server-only hashes of scoped Fitbit OS/Garmin wearable credentials.';
comment on table public.wearable_ingest_events is
  'Idempotent provider event inbox drained and acknowledged by the owner phone.';
comment on table public.wearable_daily_health_summaries is
  'Opt-in Google Health daily aggregates; owner-readable and never used for ads or AI.';
