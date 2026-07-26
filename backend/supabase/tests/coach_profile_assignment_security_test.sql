begin;

create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('30000000-0000-4000-8000-000000000001',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'coach@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('30000000-0000-4000-8000-000000000002',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'athlete@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('30000000-0000-4000-8000-000000000003',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'outsider@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles(user_id, name, plan, plan_expires_at) values
  ('30000000-0000-4000-8000-000000000001', 'Coach', 'coach', now() + interval '30 days'),
  ('30000000-0000-4000-8000-000000000002', 'Athlete', 'free', null),
  ('30000000-0000-4000-8000-000000000003', 'Outsider', 'free', null);
insert into public.coach_profiles(coach_id, athlete_link_code)
values ('30000000-0000-4000-8000-000000000001', 'SECRET01');
insert into public.coach_athletes(coach_id, athlete_id, status)
values (
  '30000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000002',
  'ACTIVE'
);
insert into public.coach_packages(
  package_id, coach_id, title, type, price_cents
) values (
  '30000000-0000-4000-8000-000000000010',
  '30000000-0000-4000-8000-000000000001',
  'Program', 'DIGITAL_PROGRAM', 1000
);
insert into public.coach_purchases(
  purchase_id, package_id, coach_id, player_id,
  price_cents, commission_cents, coach_net_cents, store, store_tx_id
) values (
  '30000000-0000-4000-8000-000000000011',
  '30000000-0000-4000-8000-000000000010',
  '30000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000002',
  1000, 150, 850, 'PLAY_STORE', 'coach-security-test'
);

select is(
  has_column_privilege(
    'authenticated', 'public.coach_profiles', 'athlete_link_code', 'SELECT'
  ),
  false,
  'authenticated users cannot select the bearer link code'
);
select is(
  has_column_privilege(
    'authenticated', 'public.coach_profiles', 'verified', 'UPDATE'
  ),
  false,
  'coaches cannot update their verified badge'
);
select is(
  has_column_privilege(
    'authenticated', 'public.coach_profiles', 'rating_avg', 'UPDATE'
  ),
  false,
  'coaches cannot forge their rating'
);
select is(
  has_table_privilege('authenticated', 'public.coach_assignments', 'INSERT'),
  false,
  'clients cannot bypass the assignment RPC with a direct insert'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select lives_ok(
  $$update public.coach_profiles
      set bio = 'Profilo aggiornato'
    where coach_id = '30000000-0000-4000-8000-000000000001'$$,
  'a coach can still update allowed public fields'
);
select throws_like(
  $$update public.coach_profiles
      set verified = true
    where coach_id = '30000000-0000-4000-8000-000000000001'$$,
  '%permission denied%',
  'a direct verified badge forgery is rejected'
);

select is(
  public.assign_coach_training(
    '30000000-0000-4000-8000-000000000002',
    '{"title":"Footwork","sessionsTarget":3}'::jsonb,
    null
  )->>'ok',
  'true',
  'an active coach can assign training to a linked athlete'
);
select is(
  (select count(*)::int from public.coach_assignments
    where coach_id = '30000000-0000-4000-8000-000000000001'
      and player_id = '30000000-0000-4000-8000-000000000002'),
  1,
  'the assignment RPC persists exactly one row'
);
select is(
  public.assign_coach_training(
    '30000000-0000-4000-8000-000000000003',
    '{"title":"Unauthorized"}'::jsonb,
    null
  )->>'error',
  'athlete_not_linked',
  'an unlinked athlete cannot receive a manual assignment'
);
select is(
  public.assign_coach_training(
    '30000000-0000-4000-8000-000000000003',
    '{"title":"Wrong purchase"}'::jsonb,
    '30000000-0000-4000-8000-000000000011'
  )->>'error',
  'purchase_not_valid',
  'a purchase cannot be reused for a different player'
);
select is(
  has_function_privilege(
    'anon', 'public.assign_coach_training(uuid,jsonb,uuid)', 'EXECUTE'
  ),
  false,
  'anonymous callers cannot assign training'
);
select ok(
  has_function_privilege(
    'authenticated', 'public.assign_coach_training(uuid,jsonb,uuid)', 'EXECUTE'
  ),
  'authenticated coaches can execute the guarded assignment RPC'
);

select * from finish();
rollback;
