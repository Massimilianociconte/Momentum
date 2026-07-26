begin;

create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'retention@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles (user_id, name, nickname, plan) values
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'Retention', 'retention', 'plus');

-- La funzione esiste ed è invocabile solo dal service role.
select has_function(
  'public', 'cleanup_transient_data', array[]::text[],
  'cleanup_transient_data() esiste'
);
select ok(
  not has_function_privilege(
    'anon', 'public.cleanup_transient_data()', 'EXECUTE'
  ),
  'anon non può eseguire la retention'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public.cleanup_transient_data()', 'EXECUTE'
  ),
  'authenticated non può eseguire la retention'
);
select ok(
  has_function_privilege(
    'service_role', 'public.cleanup_transient_data()', 'EXECUTE'
  ),
  'service_role può eseguire la retention'
);

-- Comportamento: un rate event vecchio viene eliminato, uno recente resta.
insert into public.wearable_gateway_rate_events (actor_hash, action, created_at)
values
  ('hash_old', 'INGEST', now() - interval '9 days'),
  ('hash_new', 'INGEST', now() - interval '1 hour');

select is(
  (public.cleanup_transient_data() ->> 'rate_events')::int,
  1,
  'la retention elimina solo il rate event oltre finestra'
);
select is(
  (
    select count(*)::int from public.wearable_gateway_rate_events
    where actor_hash in ('hash_old', 'hash_new')
  ),
  1,
  'il rate event recente sopravvive'
);

-- Un ingest event ACKato da oltre 30 giorni sparisce; uno pendente resta.
insert into public.wearable_ingest_events
  (user_id, provider, external_event_id, match_id, event_type, event_at,
   acknowledged_at)
values
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'FITBIT_OS', 'evt_retention_old',
   'mt_retention', 'POINT_TEAM_A',
   now() - interval '40 days', now() - interval '35 days'),
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'FITBIT_OS', 'evt_retention_live',
   'mt_retention', 'POINT_TEAM_B', now() - interval '1 hour', null);

select is(
  (public.cleanup_transient_data() ->> 'ingest_events')::int,
  1,
  'la retention elimina l''ingest ACKato oltre i 30 giorni'
);
select is(
  (
    select count(*)::int from public.wearable_ingest_events
    where external_event_id like 'evt_retention_%'
  ),
  1,
  'l''ingest non ACKato resta in inbox'
);

select * from finish();
rollback;
