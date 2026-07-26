begin;

create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('e1111111-1111-4111-8111-111111111111',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'health-a@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('e2222222-2222-4222-8222-222222222222',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'health-b@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('e3333333-3333-4333-8333-333333333333',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'health-free@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles (
  user_id, name, nickname, plan, plan_expires_at
) values
  ('e1111111-1111-4111-8111-111111111111', 'Health A', 'health-a', 'plus', now() + interval '30 days'),
  ('e2222222-2222-4222-8222-222222222222', 'Health B', 'health-b', 'plus', now() + interval '30 days'),
  ('e3333333-3333-4333-8333-333333333333', 'Health Free', 'health-free', 'free', null);

insert into public.health_data_sources (
  source_id, user_id, provider, source_application, source_bundle_id
) values
  ('f1111111-1111-4111-8111-111111111111',
   'e1111111-1111-4111-8111-111111111111',
   'OURA_DIRECT', 'Oura A', 'cloud.ouraring.com'),
  ('f2222222-2222-4222-8222-222222222222',
   'e2222222-2222-4222-8222-222222222222',
   'OURA_DIRECT', 'Oura B', 'cloud.ouraring.com');

select is(
  (
    select count(*)::int
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relrowsecurity
      and c.relname in (
        'health_provider_features', 'health_data_sources',
        'health_metric_records', 'health_source_preferences',
        'match_health_summaries', 'health_sync_jobs',
        'health_provider_webhook_events'
      )
  ),
  7,
  'all unified health tables have RLS enabled'
);
select ok(
  not has_table_privilege('anon', 'public.health_provider_features', 'SELECT'),
  'anonymous clients cannot enumerate provider rollout'
);
select ok(
  has_table_privilege(
    'authenticated', 'public.health_provider_features', 'SELECT'
  ),
  'authenticated clients can read the non-secret rollout catalog'
);
select ok(
  not has_table_privilege('authenticated', 'public.health_sync_jobs', 'SELECT'),
  'clients cannot inspect server sync jobs'
);
select ok(
  not has_table_privilege(
    'authenticated', 'public.health_provider_webhook_events', 'SELECT'
  ),
  'clients cannot inspect webhook transport metadata'
);
select ok(
  not has_function_privilege(
    'anon', 'public.delete_my_health_provider_data(text)', 'EXECUTE'
  ),
  'anonymous clients cannot delete provider data'
);
select ok(
  has_function_privilege(
    'authenticated', 'public.delete_my_health_provider_data(text)', 'EXECUTE'
  ),
  'authenticated owners retain the provider deletion RPC'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public.consume_health_oauth_state(text,text)', 'EXECUTE'
  ),
  'clients cannot consume OAuth state'
);
select ok(
  has_function_privilege(
    'service_role', 'public.consume_health_oauth_state(text,text)', 'EXECUTE'
  ),
  'only the backend role can consume OAuth state'
);
select ok(
  not has_function_privilege(
    'anon', 'public.cleanup_health_provider_data()', 'EXECUTE'
  ),
  'anonymous clients cannot execute health retention'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public.cleanup_health_provider_data()', 'EXECUTE'
  ),
  'authenticated clients cannot execute health retention'
);
select ok(
  has_function_privilege(
    'service_role', 'public.cleanup_health_provider_data()', 'EXECUTE'
  ),
  'service role can execute health retention'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"e1111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$insert into public.health_metric_records (
      user_id, provider, source_id, external_record_id, metric_type,
      start_time, end_time, value, unit, aggregation_scope, content_hash
    ) values (
      'e1111111-1111-4111-8111-111111111111', 'OURA_DIRECT',
      'f1111111-1111-4111-8111-111111111111', 'own-record', 'READINESS',
      now(), now(), 75, 'score', 'DAILY', repeat('a', 64)
    )$$,
  'a premium owner can write an aggregate tied to their own source'
);
select throws_ok(
  $$insert into public.health_metric_records (
      user_id, provider, source_id, external_record_id, metric_type,
      start_time, end_time, value, unit, aggregation_scope, content_hash
    ) values (
      'e1111111-1111-4111-8111-111111111111', 'OURA_DIRECT',
      'f2222222-2222-4222-8222-222222222222', 'cross-record', 'READINESS',
      now(), now(), 75, 'score', 'DAILY', repeat('b', 64)
    )$$,
  '23503', null,
  'a metric cannot reference another user source'
);
select throws_ok(
  $$insert into public.health_source_preferences (
      user_id, metric_type, source_id
    ) values (
      'e1111111-1111-4111-8111-111111111111', 'SLEEP',
      'f2222222-2222-4222-8222-222222222222'
    )$$,
  '42501',
  'new row violates row-level security policy for table "health_source_preferences"',
  'RLS rejects a preference that references another user source'
);
select throws_ok(
  $$insert into public.match_health_summaries (
      match_id, user_id, primary_source_id, data_quality
    ) values (
      'cross-source-match', 'e1111111-1111-4111-8111-111111111111',
      'f2222222-2222-4222-8222-222222222222', 'LOW'
    ); set constraints match_health_source_owner_fk immediate$$,
  '23503', null,
  'a match summary cannot reference another user source'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"e3333333-3333-4333-8333-333333333333","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$insert into public.health_data_sources (
      user_id, provider, source_application, source_bundle_id
    ) values (
      'e3333333-3333-4333-8333-333333333333', 'OURA_DIRECT',
      'Forbidden', 'cloud.ouraring.com'
    )$$,
  '42501',
  'new row violates row-level security policy for table "health_data_sources"',
  'a Free user cannot write cloud health sources'
);
reset role;

insert into public.health_metric_records (
  user_id, provider, source_id, external_record_id, metric_type,
  start_time, end_time, value, unit, aggregation_scope, content_hash
) values
  ('e2222222-2222-4222-8222-222222222222', 'OURA_DIRECT',
   'f2222222-2222-4222-8222-222222222222', 'old-record', 'SLEEP_SCORE',
   now() - interval '40 days', now() - interval '40 days', 70, 'score',
   'DAILY', repeat('c', 64)),
  ('e2222222-2222-4222-8222-222222222222', 'OURA_DIRECT',
   'f2222222-2222-4222-8222-222222222222', 'recent-record', 'SLEEP_SCORE',
   now() - interval '1 day', now() - interval '1 day', 80, 'score',
   'DAILY', repeat('d', 64));

select is(
  (public.cleanup_health_provider_data() ->> 'direct_metric_records')::int,
  1,
  'retention removes only direct-provider aggregates older than 30 days'
);
select is(
  (
    select count(*)::int from public.health_metric_records
    where external_record_id = 'recent-record'
  ),
  1,
  'recent direct-provider aggregates survive retention'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"e1111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$select public.delete_my_health_provider_data('OURA_DIRECT')$$,
  'the owner can delete imported provider data'
);
reset role;
select is(
  (
    select count(*)::int from public.health_metric_records
    where user_id = 'e1111111-1111-4111-8111-111111111111'
  ),
  0,
  'provider deletion removes the owner aggregates'
);
select is(
  (
    select count(*)::int from public.health_metric_records
    where user_id = 'e2222222-2222-4222-8222-222222222222'
  ),
  1,
  'provider deletion does not affect another account'
);

select * from finish();
rollback;
