begin;

create extension if not exists pgtap with schema extensions;
select plan(25);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'wear-free@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'wear-plus@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'wear-pro@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles (
  user_id, name, nickname, plan, plan_expires_at
) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Wear Free', 'wear-free', 'free', null),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'Wear Plus', 'wear-plus', 'plus', now() + interval '30 days'),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'Wear Pro', 'wear-pro', 'pro', now() + interval '30 days');

select is(
  has_table_privilege('anon', 'public.wearable_provider_connections', 'SELECT'),
  false,
  'anon cannot read encrypted provider connections'
);
select is(
  has_table_privilege('authenticated', 'public.wearable_provider_connections', 'SELECT'),
  false,
  'authenticated cannot read encrypted provider connections'
);
select is(
  has_table_privilege('authenticated', 'public.wearable_daily_health_summaries', 'SELECT'),
  true,
  'authenticated can select owner-filtered health summaries'
);
select is(
  has_table_privilege('authenticated', 'public.wearable_daily_health_summaries', 'INSERT'),
  false,
  'authenticated cannot forge health summaries'
);
select is(
  has_table_privilege('authenticated', 'public.wearable_daily_health_summaries', 'TRUNCATE'),
  false,
  'authenticated cannot truncate health summaries'
);
select is(
  has_function_privilege(
    'anon',
    'public.claim_wearable_pairing(text,text,text,text,text[],timestamptz)',
    'EXECUTE'
  ),
  false,
  'anon cannot claim wearable pairing credentials'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.claim_wearable_pairing(text,text,text,text,text[],timestamptz)',
    'EXECUTE'
  ),
  false,
  'authenticated cannot bypass the wearable gateway claim flow'
);

insert into public.wearable_pairing_challenges(
  user_id, provider, code_hash, expires_at
) values
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'FITBIT_OS', 'plus-code-hash', now() + interval '10 minutes'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'GARMIN_CONNECT_IQ', 'free-code-hash', now() + interval '10 minutes');

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
select is(
  public.claim_wearable_pairing(
    'plus-code-hash', 'FITBIT_OS', 'plus-token-hash', 'Versa test',
    array['scoring', 'offline'], now() + interval '30 days'
  ),
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid,
  'Plus account can claim a cloud wearable token'
);
reset role;

select is(
  (select count(*)::int from public.wearable_device_tokens
   where token_hash = 'plus-token-hash'),
  1,
  'pairing creates exactly one hashed device token'
);
select ok(
  (select consumed_at is not null from public.wearable_pairing_challenges
   where code_hash = 'plus-code-hash'),
  'pairing challenge is consumed atomically'
);

set local role service_role;
select throws_ok(
  $$select public.claim_wearable_pairing(
    'plus-code-hash', 'FITBIT_OS', 'another-token-hash', 'Replay',
    array['scoring'], now() + interval '30 days'
  )$$,
  'P0001',
  'invalid_pairing',
  'a consumed pairing challenge cannot be replayed'
);
select throws_ok(
  $$select public.claim_wearable_pairing(
    'free-code-hash', 'GARMIN_CONNECT_IQ', 'free-token-hash', 'Free watch',
    array['scoring'], now() + interval '30 days'
  )$$,
  'P0001',
  'plan_required',
  'Free account cannot claim paid cloud wearable sync'
);
reset role;

insert into public.wearable_oauth_states(
  state_hash, user_id, provider, expires_at
) values (
  'oauth-state-hash', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'GOOGLE_HEALTH', now() + interval '10 minutes'
);
set local role service_role;
select is(
  (select user_id from public.consume_wearable_oauth_state('oauth-state-hash')),
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc'::uuid,
  'service callback consumes a valid OAuth state'
);
select is(
  (select count(*)::int from public.consume_wearable_oauth_state('oauth-state-hash')),
  0,
  'OAuth state cannot be consumed twice'
);
reset role;

insert into public.wearable_daily_health_summaries(
  user_id, provider, local_date, timezone, steps
) values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'GOOGLE_HEALTH',
  current_date, 'Europe/Rome', 4321
);

select set_config(
  'request.jwt.claims',
  '{"sub":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*)::int from public.wearable_daily_health_summaries),
  1,
  'health summary owner can read its aggregate'
);
select is(
  (select count(*)::int from public.my_wearable_connections()),
  0,
  'provider connection RPC exposes only the current owner rows'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*)::int from public.wearable_daily_health_summaries),
  0,
  'another user cannot read health aggregates'
);
select is(
  (select count(*)::int from public.my_wearable_connections()),
  1,
  'owner RPC returns its Fitbit provider connection without token material'
);
reset role;

select is(
  has_table_privilege('authenticated', 'public.wearable_device_tokens', 'SELECT'),
  false,
  'authenticated cannot enumerate wearable device token hashes'
);

insert into public.wearable_ingest_events(
  user_id, provider, external_event_id, match_id, event_type, event_at
) values
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'FITBIT_OS',
   'shared-device-event-id', 'match-plus', 'POINT_TEAM_A', now()),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'FITBIT_OS',
   'shared-device-event-id', 'match-pro', 'POINT_TEAM_A', now());

select is(
  (select count(*)::int from public.wearable_ingest_events
   where external_event_id = 'shared-device-event-id'),
  2,
  'idempotency keys are isolated by owner account'
);

select throws_ok(
  $$insert into public.wearable_ingest_events(
      user_id, provider, external_event_id, match_id, event_type, event_at
    ) values (
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'FITBIT_OS',
      'shared-device-event-id', 'match-duplicate', 'POINT_TEAM_A', now()
    )$$,
  '23505',
  null,
  'the same owner/provider event remains idempotent'
);

select is(
  has_table_privilege('anon', 'public.wearable_outbound_commands', 'SELECT'),
  false,
  'anon cannot read commands queued for a wearable'
);
select is(
  has_table_privilege(
    'authenticated',
    'public.wearable_outbound_commands',
    'INSERT'
  ),
  false,
  'authenticated cannot enqueue wearable commands directly'
);

insert into public.wearable_outbound_commands(
  user_id, provider, target_token_id, command_type, payload, expires_at
)
select
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'FITBIT_OS',
  token_id,
  'START_MATCH',
  '{"matchId":"match-command"}'::jsonb,
  now() + interval '10 minutes'
from public.wearable_device_tokens
where token_hash = 'plus-token-hash';

select is(
  (select count(*)::int from public.wearable_outbound_commands),
  1,
  'service-side Fitbit command is persisted until acknowledgement'
);

select throws_ok(
  $$insert into public.wearable_outbound_commands(
      user_id, provider, target_token_id, command_type, payload, expires_at
    ) select
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'FITBIT_OS',
      token_id,
      'START_MATCH',
      '{"matchId":"cross-account"}'::jsonb,
      now() + interval '10 minutes'
    from public.wearable_device_tokens
    where token_hash = 'plus-token-hash'$$,
  '23503',
  null,
  'a command cannot target another account device token'
);

select * from finish();
rollback;
