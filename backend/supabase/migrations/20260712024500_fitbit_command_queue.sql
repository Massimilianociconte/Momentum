-- Durable, token-targeted commands from the RallyMate phone to Fitbit OS.
-- A command remains available until the watch confirms it or it expires.

alter table public.wearable_gateway_rate_events
  drop constraint if exists wearable_gateway_rate_events_action_check;
alter table public.wearable_gateway_rate_events
  add constraint wearable_gateway_rate_events_action_check
  check (action in ('CLAIM', 'INGEST', 'PULL'));

alter table public.wearable_device_tokens
  add constraint wearable_device_tokens_token_owner_key
  unique (token_id, user_id);

create table public.wearable_outbound_commands (
  command_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  provider text not null check (provider = 'FITBIT_OS'),
  target_token_id uuid not null,
  command_type text not null check (command_type in ('START_MATCH', 'REQUEST_STATE')),
  payload jsonb not null default '{}',
  expires_at timestamptz not null,
  delivered_at timestamptz,
  acknowledged_at timestamptz,
  result text check (result is null or result in ('APPLIED', 'REJECTED')),
  created_at timestamptz not null default now(),
  foreign key (target_token_id, user_id)
    references public.wearable_device_tokens(token_id, user_id)
    on delete cascade,
  check (expires_at <= created_at + interval '24 hours'),
  check (pg_column_size(payload) <= 8192)
);

create index wearable_outbound_commands_delivery_idx
  on public.wearable_outbound_commands(target_token_id, created_at)
  where acknowledged_at is null;

alter table public.wearable_outbound_commands enable row level security;
revoke all on table public.wearable_outbound_commands from anon, authenticated;
grant select, insert, update, delete on table public.wearable_outbound_commands
  to service_role;

comment on table public.wearable_outbound_commands is
  'Server-only, expiring commands delivered to one authenticated Fitbit OS companion.';
