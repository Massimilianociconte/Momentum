begin;

create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('50000000-0000-4000-8000-000000000001',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'active-coach@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('50000000-0000-4000-8000-000000000002',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'expired-coach@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('50000000-0000-4000-8000-000000000003',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'market-athlete@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles(user_id, name, plan, plan_expires_at) values
  ('50000000-0000-4000-8000-000000000001', 'Active Coach', 'coach',
   now() + interval '30 days'),
  ('50000000-0000-4000-8000-000000000002', 'Expired Coach', 'coach',
   now() - interval '1 day'),
  ('50000000-0000-4000-8000-000000000003', 'Athlete', 'free', null);
insert into public.coach_profiles(coach_id, athlete_link_code) values
  ('50000000-0000-4000-8000-000000000001', 'ACTIVE01'),
  ('50000000-0000-4000-8000-000000000002', 'EXPIRED1');
insert into public.coach_packages(
  package_id, coach_id, title, type, price_cents, status
) values
  ('50000000-0000-4000-8000-000000000010',
   '50000000-0000-4000-8000-000000000002',
   'Stale active offer', 'DIGITAL_PROGRAM', 4900, 'ACTIVE'),
  ('50000000-0000-4000-8000-000000000011',
   '50000000-0000-4000-8000-000000000002',
   'Disposable draft', 'DIGITAL_PROGRAM', 1900, 'DRAFT');
insert into public.coach_athletes(coach_id, athlete_id, status, ended_at)
values (
  '50000000-0000-4000-8000-000000000002',
  '50000000-0000-4000-8000-000000000003',
  'ENDED', now()
);

select set_config(
  'request.jwt.claims',
  '{"sub":"50000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
select lives_ok(
  $$insert into public.coach_packages(
      package_id, coach_id, title, type, price_cents, status
    ) values (
      '50000000-0000-4000-8000-000000000012',
      '50000000-0000-4000-8000-000000000001',
      'Current offer', 'MONTHLY_PLAN', 5900, 'ACTIVE'
    )$$,
  'an active Coach can create a commercial package'
);
select is(
  (select count(*)::int from public.coach_packages
   where coach_id = '50000000-0000-4000-8000-000000000001'),
  1,
  'the active coach package is persisted'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"50000000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*)::int from public.coach_packages where status = 'ACTIVE'),
  1,
  'marketplace RLS hides active-looking offers from expired coaches'
);
select is(
  public.coach_public_profile(
    '50000000-0000-4000-8000-000000000002'
  )->'packages',
  '[]'::jsonb,
  'public coach profile also hides expired commercial offers'
);
select is(
  public.join_coach('EXPIRED1')->>'error',
  'not_available',
  'a persisted link code stops working when the Coach plan expires'
);
select is(
  (select count(*)::int from public.my_coaches()
   where coach_id = '50000000-0000-4000-8000-000000000002'),
  0,
  'an expired code cannot reactivate an ended athlete relationship'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"50000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$insert into public.coach_packages(
      coach_id, title, type, price_cents, status
    ) values (
      '50000000-0000-4000-8000-000000000002',
      'Expired insert', 'DIGITAL_PROGRAM', 2900, 'ACTIVE'
    )$$,
  '42501',
  'new row violates row-level security policy for table "coach_packages"',
  'an expired Coach cannot create a package'
);
select throws_ok(
  $$update public.coach_packages
      set title = 'Commercial edit'
    where package_id = '50000000-0000-4000-8000-000000000010'$$,
  '42501',
  'new row violates row-level security policy for table "coach_packages"',
  'an expired Coach cannot edit an ACTIVE commercial offer'
);
select lives_ok(
  $$update public.coach_packages
      set status = 'ARCHIVED'
    where package_id = '50000000-0000-4000-8000-000000000010'$$,
  'an expired Coach can unpublish by archiving an offer'
);
select is(
  (select status from public.coach_packages
   where package_id = '50000000-0000-4000-8000-000000000010'),
  'ARCHIVED',
  'the expired offer is archived'
);
select lives_ok(
  $$delete from public.coach_packages
    where package_id = '50000000-0000-4000-8000-000000000011'$$,
  'an expired Coach can delete its own draft for privacy/data management'
);
select is(
  (select count(*)::int from public.coach_packages
   where package_id = '50000000-0000-4000-8000-000000000011'),
  0,
  'the expired Coach draft is deleted'
);

select * from finish();
rollback;
