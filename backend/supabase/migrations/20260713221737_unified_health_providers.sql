-- Unified health-provider foundation.
--
-- Existing Garmin/Fitbit scoring and Google Health OAuth tables remain the
-- source of truth. This migration extends them and adds normalized,
-- privacy-minimized health aggregates. BLE identifiers remain local-only.

alter table public.wearable_provider_connections
  drop constraint if exists wearable_provider_connections_provider_check;
alter table public.wearable_provider_connections
  add constraint wearable_provider_connections_provider_check check (
    provider in (
      'GOOGLE_HEALTH', 'FITBIT_OS', 'GARMIN_CONNECT_IQ',
      'OURA_DIRECT', 'WHOOP_DIRECT', 'GARMIN_HEALTH'
    )
  );
alter table public.wearable_provider_connections
  add column if not exists connection_type text not null default 'CLOUD_OAUTH'
    check (connection_type in (
      'CLOUD_OAUTH', 'NATIVE_COMPANION', 'PROVIDER_API'
    )),
  add column if not exists support_status text not null default 'BETA'
    check (support_status in (
      'EXPERIMENTAL', 'INTERNAL', 'BETA', 'PRODUCTION'
    )),
  add column if not exists refresh_lock_id uuid,
  add column if not exists refresh_lock_expires_at timestamptz;

update public.wearable_provider_connections
set connection_type = case
      when provider in ('FITBIT_OS', 'GARMIN_CONNECT_IQ')
        then 'NATIVE_COMPANION'
      else 'CLOUD_OAUTH'
    end,
    support_status = case
      when provider in ('GOOGLE_HEALTH', 'FITBIT_OS', 'GARMIN_CONNECT_IQ')
        then 'BETA'
      else 'INTERNAL'
    end;

alter table public.wearable_oauth_states
  drop constraint if exists wearable_oauth_states_provider_check;
alter table public.wearable_oauth_states
  add constraint wearable_oauth_states_provider_check check (
    provider in ('GOOGLE_HEALTH', 'OURA_DIRECT', 'WHOOP_DIRECT', 'GARMIN_HEALTH')
  );

alter table public.wearable_daily_health_summaries
  drop constraint if exists wearable_daily_health_summaries_provider_check;
alter table public.wearable_daily_health_summaries
  add constraint wearable_daily_health_summaries_provider_check check (
    provider in ('GOOGLE_HEALTH', 'OURA_DIRECT', 'WHOOP_DIRECT', 'GARMIN_HEALTH')
  );

create table public.health_provider_features (
  provider text primary key check (provider in (
    'APPLE_HEALTH', 'HEALTH_CONNECT', 'GOOGLE_HEALTH', 'GARMIN_HEALTH',
    'OURA_HEALTH_HUB', 'OURA_DIRECT', 'WHOOP_DIRECT',
    'HELIO_STRAP_HEALTH_HUB', 'BLE_HEART_RATE', 'ZEPP_HEALTH_HUB',
    'RINGCONN_HEALTH_HUB', 'ULTRAHUMAN_HEALTH_HUB'
  )),
  rollout text not null check (rollout in (
    'DISABLED', 'INTERNAL', 'BETA', 'PRODUCTION'
  )),
  support_status text not null check (support_status in (
    'NOT_SUPPORTED', 'RESEARCH', 'EXPERIMENTAL', 'INTERNAL',
    'BETA', 'PRODUCTION', 'INDIRECT'
  )),
  capabilities text[] not null default '{}',
  updated_at timestamptz not null default now(),
  check (cardinality(capabilities) <= 32)
);

insert into public.health_provider_features(
  provider, rollout, support_status, capabilities
) values
  ('APPLE_HEALTH', 'PRODUCTION', 'PRODUCTION',
    array['HEALTH_HUB_IMPORT','WORKOUT_IMPORT','HEART_RATE','SLEEP','HRV']),
  ('HEALTH_CONNECT', 'PRODUCTION', 'PRODUCTION',
    array['HEALTH_HUB_IMPORT','WORKOUT_IMPORT','HEART_RATE','SLEEP','HRV']),
  ('GOOGLE_HEALTH', 'BETA', 'BETA',
    array['CLOUD_OAUTH','WEBHOOKS','HISTORICAL_IMPORT']),
  ('GARMIN_HEALTH', 'DISABLED', 'RESEARCH',
    array['PROVIDER_APPROVAL_REQUIRED']),
  ('OURA_HEALTH_HUB', 'BETA', 'INDIRECT',
    array['HEALTH_HUB_IMPORT','SLEEP','HRV']),
  ('OURA_DIRECT', 'DISABLED', 'INTERNAL',
    array['CLOUD_OAUTH','READINESS','SLEEP','HRV']),
  ('WHOOP_DIRECT', 'DISABLED', 'INTERNAL',
    array['CLOUD_OAUTH','WEBHOOKS','RECOVERY','STRAIN','SLEEP','HRV']),
  ('HELIO_STRAP_HEALTH_HUB', 'BETA', 'INDIRECT',
    array['HEALTH_HUB_IMPORT','HEART_RATE']),
  ('BLE_HEART_RATE', 'INTERNAL', 'EXPERIMENTAL',
    array['LIVE_HEART_RATE','DIRECT_PAIRING']),
  ('ZEPP_HEALTH_HUB', 'DISABLED', 'RESEARCH',
    array['HEALTH_HUB_IMPORT']),
  ('RINGCONN_HEALTH_HUB', 'BETA', 'INDIRECT',
    array['HEALTH_HUB_IMPORT','SLEEP','HEART_RATE']),
  ('ULTRAHUMAN_HEALTH_HUB', 'BETA', 'INDIRECT',
    array['HEALTH_HUB_IMPORT','SLEEP','HRV'])
on conflict (provider) do update set
  rollout = excluded.rollout,
  support_status = excluded.support_status,
  capabilities = excluded.capabilities,
  updated_at = now();

create table public.health_data_sources (
  source_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  provider text not null,
  source_application text not null default '',
  source_bundle_id text not null default '',
  source_device text not null default '',
  source_model text not null default '',
  connection_id uuid references public.wearable_provider_connections(connection_id)
    on delete set null,
  is_preferred boolean not null default false,
  supports_live_data boolean not null default false,
  available_metrics text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (
    user_id, provider, source_bundle_id, source_device, source_model
  ),
  check (char_length(provider) between 2 and 50),
  check (char_length(source_application) <= 120),
  check (char_length(source_bundle_id) <= 180),
  check (char_length(source_device) <= 120),
  check (char_length(source_model) <= 120),
  check (cardinality(available_metrics) <= 32)
);

create table public.health_metric_records (
  record_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  provider text not null,
  source_id uuid not null references public.health_data_sources(source_id)
    on delete cascade,
  external_record_id text,
  metric_type text not null check (metric_type in (
    'WORKOUT', 'HEART_RATE', 'ACTIVE_ENERGY', 'TOTAL_ENERGY', 'STEPS',
    'EXERCISE_MINUTES', 'DISTANCE', 'HRV', 'SLEEP', 'SLEEP_SCORE',
    'READINESS', 'RECOVERY', 'STRAIN', 'RESTING_HEART_RATE'
  )),
  start_time timestamptz not null,
  end_time timestamptz not null,
  value numeric(14,4) not null,
  unit text not null,
  aggregation_scope text not null check (aggregation_scope in (
    'DAILY', 'WORKOUT', 'MATCH', 'RECOVERY'
  )),
  metadata jsonb not null default '{}',
  content_hash text not null,
  sync_version integer not null default 1 check (sync_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, content_hash),
  check (end_time >= start_time),
  check (char_length(provider) between 2 and 50),
  check (char_length(coalesce(external_record_id, '')) <= 200),
  check (char_length(unit) between 1 and 24),
  check (char_length(content_hash) between 32 and 128),
  check (pg_column_size(metadata) <= 4096)
);

create unique index health_metric_external_record_idx
  on public.health_metric_records(
    user_id, provider, external_record_id, metric_type
  ) where external_record_id is not null;
create index health_metric_recent_idx
  on public.health_metric_records(user_id, metric_type, start_time desc);

create table public.health_source_preferences (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  metric_type text not null,
  source_id uuid not null references public.health_data_sources(source_id)
    on delete cascade,
  updated_at timestamptz not null default now(),
  primary key (user_id, metric_type),
  check (metric_type in (
    'WORKOUT', 'HEART_RATE', 'ACTIVE_ENERGY', 'TOTAL_ENERGY', 'STEPS',
    'EXERCISE_MINUTES', 'DISTANCE', 'HRV', 'SLEEP', 'SLEEP_SCORE',
    'READINESS', 'RECOVERY', 'STRAIN', 'RESTING_HEART_RATE'
  ))
);

create table public.match_health_summaries (
  summary_id uuid primary key default gen_random_uuid(),
  match_id text not null,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  primary_source_id uuid references public.health_data_sources(source_id)
    on delete set null,
  duration_seconds integer check (duration_seconds between 0 and 86400),
  avg_heart_rate numeric(6,2) check (
    avg_heart_rate is null or avg_heart_rate between 20 and 300
  ),
  max_heart_rate numeric(6,2) check (
    max_heart_rate is null or max_heart_rate between 20 and 300
  ),
  min_heart_rate numeric(6,2) check (
    min_heart_rate is null or min_heart_rate between 20 and 300
  ),
  active_energy_kcal numeric(10,2) check (
    active_energy_kcal is null or active_energy_kcal between 0 and 100000
  ),
  total_energy_kcal numeric(10,2) check (
    total_energy_kcal is null or total_energy_kcal between 0 and 100000
  ),
  steps integer check (steps is null or steps between 0 and 500000),
  distance_meters numeric(12,2) check (
    distance_meters is null or distance_meters between 0 and 1000000
  ),
  high_intensity_minutes integer check (
    high_intensity_minutes is null or high_intensity_minutes between 0 and 1440
  ),
  recovery_delta numeric(8,3),
  sleep_score numeric(6,2) check (sleep_score is null or sleep_score between 0 and 100),
  readiness_score numeric(6,2) check (readiness_score is null or readiness_score between 0 and 100),
  recovery_score numeric(6,2) check (recovery_score is null or recovery_score between 0 and 100),
  strain_score numeric(6,2) check (strain_score is null or strain_score between 0 and 100),
  data_quality text not null default 'UNKNOWN' check (
    data_quality in ('UNKNOWN', 'LOW', 'MEDIUM', 'HIGH')
  ),
  calculated_at timestamptz not null default now(),
  unique (user_id, match_id),
  check (char_length(match_id) between 3 and 128)
);

create index match_health_recent_idx
  on public.match_health_summaries(user_id, calculated_at desc);

create table public.health_sync_jobs (
  job_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  provider text not null,
  sync_type text not null check (sync_type in (
    'RECENT', 'DATE_RANGE', 'WEBHOOK_RECONCILE', 'DELETE'
  )),
  date_from timestamptz,
  date_to timestamptz,
  status text not null default 'PENDING' check (status in (
    'PENDING', 'RUNNING', 'RETRY', 'COMPLETED', 'FAILED'
  )),
  retry_count smallint not null default 0 check (retry_count between 0 and 10),
  next_retry_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  check (date_to is null or date_from is null or date_to >= date_from),
  check (char_length(provider) between 2 and 50),
  check (char_length(coalesce(last_error_code, '')) <= 100)
);

create index health_sync_jobs_pending_idx
  on public.health_sync_jobs(status, next_retry_at, created_at)
  where status in ('PENDING', 'RETRY');

create table public.health_provider_webhook_events (
  webhook_event_id bigint generated always as identity primary key,
  provider text not null check (provider in ('OURA_DIRECT', 'WHOOP_DIRECT')),
  trace_id text not null,
  provider_subject_hash text not null,
  event_type text not null,
  external_resource_id text not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  last_error_code text,
  unique (provider, trace_id),
  check (char_length(trace_id) between 8 and 128),
  check (char_length(provider_subject_hash) between 32 and 128),
  check (char_length(event_type) between 3 and 80),
  check (char_length(external_resource_id) between 1 and 200),
  check (char_length(coalesce(last_error_code, '')) <= 100)
);

create index health_provider_webhook_pending_idx
  on public.health_provider_webhook_events(provider, received_at)
  where processed_at is null;

alter table public.health_provider_features enable row level security;
alter table public.health_data_sources enable row level security;
alter table public.health_metric_records enable row level security;
alter table public.health_source_preferences enable row level security;
alter table public.match_health_summaries enable row level security;
alter table public.health_sync_jobs enable row level security;
alter table public.health_provider_webhook_events enable row level security;

create policy "authenticated reads health provider rollout"
  on public.health_provider_features for select to authenticated
  using (true);

create policy "owner reads health sources"
  on public.health_data_sources for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "premium owner inserts health sources"
  on public.health_data_sources for insert to authenticated
  with check (
    (select auth.uid()) = user_id and exists (
      select 1 from public.profiles p where p.user_id = (select auth.uid())
        and (p.plan in ('plus', 'pro', 'coach') or p.premium_override
          or p.account_role in ('admin', 'super_admin'))
    )
  );
create policy "premium owner updates health sources"
  on public.health_data_sources for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id and exists (
      select 1 from public.profiles p where p.user_id = (select auth.uid())
        and (p.plan in ('plus', 'pro', 'coach') or p.premium_override
          or p.account_role in ('admin', 'super_admin'))
    )
  );
create policy "owner deletes health sources"
  on public.health_data_sources for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "owner reads health metrics"
  on public.health_metric_records for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "premium owner inserts health metrics"
  on public.health_metric_records for insert to authenticated
  with check (
    (select auth.uid()) = user_id and exists (
      select 1 from public.profiles p where p.user_id = (select auth.uid())
        and (p.plan in ('plus', 'pro', 'coach') or p.premium_override
          or p.account_role in ('admin', 'super_admin'))
    )
  );
create policy "premium owner updates health metrics"
  on public.health_metric_records for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id and exists (
      select 1 from public.profiles p where p.user_id = (select auth.uid())
        and (p.plan in ('plus', 'pro', 'coach') or p.premium_override
          or p.account_role in ('admin', 'super_admin'))
    )
  );
create policy "owner deletes health metrics"
  on public.health_metric_records for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "owner reads health preferences"
  on public.health_source_preferences for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "owner inserts health preferences"
  on public.health_source_preferences for insert to authenticated
  with check (
    (select auth.uid()) = user_id and exists (
      select 1 from public.health_data_sources s
      where s.source_id = health_source_preferences.source_id
        and s.user_id = (select auth.uid())
    )
  );
create policy "owner updates health preferences"
  on public.health_source_preferences for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id and exists (
      select 1 from public.health_data_sources s
      where s.source_id = health_source_preferences.source_id
        and s.user_id = (select auth.uid())
    )
  );
create policy "owner deletes health preferences"
  on public.health_source_preferences for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "owner reads match health summaries"
  on public.match_health_summaries for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "premium owner inserts match health summaries"
  on public.match_health_summaries for insert to authenticated
  with check (
    (select auth.uid()) = user_id and exists (
      select 1 from public.profiles p where p.user_id = (select auth.uid())
        and (p.plan in ('plus', 'pro', 'coach') or p.premium_override
          or p.account_role in ('admin', 'super_admin'))
    )
  );
create policy "premium owner updates match health summaries"
  on public.match_health_summaries for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id and exists (
      select 1 from public.profiles p where p.user_id = (select auth.uid())
        and (p.plan in ('plus', 'pro', 'coach') or p.premium_override
          or p.account_role in ('admin', 'super_admin'))
    )
  );
create policy "owner deletes match health summaries"
  on public.match_health_summaries for delete to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.health_provider_features from anon, authenticated;
revoke all on table public.health_data_sources from anon, authenticated;
revoke all on table public.health_metric_records from anon, authenticated;
revoke all on table public.health_source_preferences from anon, authenticated;
revoke all on table public.match_health_summaries from anon, authenticated;
revoke all on table public.health_sync_jobs from anon, authenticated;
revoke all on table public.health_provider_webhook_events from anon, authenticated;
grant select on table public.health_provider_features to authenticated;
grant select, insert, update, delete on table
  public.health_data_sources,
  public.health_metric_records,
  public.health_source_preferences,
  public.match_health_summaries
to authenticated;
grant select, insert, update, delete on table
  public.health_provider_features,
  public.health_data_sources,
  public.health_metric_records,
  public.health_source_preferences,
  public.match_health_summaries,
  public.health_sync_jobs,
  public.health_provider_webhook_events
to service_role;
grant usage, select on sequence public.health_provider_webhook_events_webhook_event_id_seq
  to service_role;

create or replace function public.consume_health_oauth_state(
  p_state_hash text,
  p_provider text
)
returns table(user_id uuid, redirect_after text)
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_provider not in ('OURA_DIRECT', 'WHOOP_DIRECT', 'GARMIN_HEALTH') then
    raise exception 'invalid_provider';
  end if;
  return query
  update public.wearable_oauth_states s
  set consumed_at = now()
  where s.state_hash = p_state_hash
    and s.provider = p_provider
    and s.consumed_at is null
    and s.expires_at > now()
  returning s.user_id, s.redirect_after;
end;
$$;

revoke all on function public.consume_health_oauth_state(text, text) from public;
grant execute on function public.consume_health_oauth_state(text, text)
  to service_role;

create or replace function public.delete_my_health_provider_data(
  p_provider text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception 'unauthorized'; end if;
  if char_length(coalesce(p_provider, '')) not between 2 and 50 then
    raise exception 'invalid_provider';
  end if;
  delete from public.health_metric_records
    where user_id = v_user_id and provider = p_provider;
  delete from public.match_health_summaries s
    where s.user_id = v_user_id
      and s.primary_source_id in (
        select d.source_id from public.health_data_sources d
        where d.user_id = v_user_id and d.provider = p_provider
      );
  delete from public.health_data_sources
    where user_id = v_user_id and provider = p_provider;
  delete from public.health_sync_jobs
    where user_id = v_user_id and provider = p_provider;
end;
$$;

revoke all on function public.delete_my_health_provider_data(text) from public;
grant execute on function public.delete_my_health_provider_data(text)
  to authenticated;

comment on table public.health_metric_records is
  'Premium cloud aggregates only. High-frequency and live biometric samples remain device-local.';
comment on table public.health_sync_jobs is
  'Server-only idempotent provider synchronization queue with bounded retries.';
comment on table public.health_provider_features is
  'Server-controlled provider rollout states; no credentials or secrets.';
