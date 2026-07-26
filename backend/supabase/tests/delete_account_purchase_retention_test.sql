begin;

create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('40000000-0000-4000-8000-000000000001',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'retention-coach@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('40000000-0000-4000-8000-000000000002',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'retention-player@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles(user_id, name, plan, plan_expires_at) values
  ('40000000-0000-4000-8000-000000000001', 'Coach', 'coach',
   now() + interval '30 days'),
  ('40000000-0000-4000-8000-000000000002', 'Player', 'free', null);
insert into public.coach_profiles(coach_id)
values ('40000000-0000-4000-8000-000000000001');
insert into public.coach_packages(
  package_id, coach_id, title, type, price_cents, currency
) values (
  '40000000-0000-4000-8000-000000000010',
  '40000000-0000-4000-8000-000000000001',
  'Piano mensile', 'MONTHLY_PLAN', 4900, 'EUR'
);
insert into public.coach_purchases(
  purchase_id, package_id, coach_id, player_id,
  price_cents, commission_cents, coach_net_cents, store, store_tx_id
) values (
  '40000000-0000-4000-8000-000000000011',
  '40000000-0000-4000-8000-000000000010',
  '40000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000002',
  4900, 735, 4165, 'PLAY_STORE', 'retention-purchase-1'
);
insert into public.coach_assignments(
  assignment_id, purchase_id, coach_id, player_id, training_plan
) values (
  '40000000-0000-4000-8000-000000000012',
  '40000000-0000-4000-8000-000000000011',
  '40000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000002',
  '{"title":"Private plan"}'::jsonb
);

select is(
  (select package_title_snapshot from public.coach_purchases
   where purchase_id = '40000000-0000-4000-8000-000000000011'),
  'Piano mensile',
  'purchase insert snapshots the package title'
);
select is(
  (select package_type_snapshot from public.coach_purchases
   where purchase_id = '40000000-0000-4000-8000-000000000011'),
  'MONTHLY_PLAN',
  'purchase insert snapshots the package type'
);
select is(
  (select currency_snapshot from public.coach_purchases
   where purchase_id = '40000000-0000-4000-8000-000000000011'),
  'EUR',
  'purchase insert snapshots the currency'
);

delete from auth.users
where id = '40000000-0000-4000-8000-000000000002';

select is(
  (select count(*)::int from public.coach_purchases
   where purchase_id = '40000000-0000-4000-8000-000000000011'),
  1,
  'deleting the player preserves the accounting purchase'
);
select is(
  (select player_id from public.coach_purchases
   where purchase_id = '40000000-0000-4000-8000-000000000011'),
  null::uuid,
  'the deleted player UUID is detached from the purchase'
);
select is(
  (select count(*)::int from public.coach_assignments
   where assignment_id = '40000000-0000-4000-8000-000000000012'),
  0,
  'deleting the player removes personal assignment content'
);
select is(
  (select store_tx_id from public.coach_purchases
   where purchase_id = '40000000-0000-4000-8000-000000000011'),
  'retention-purchase-1',
  'store anti-replay evidence is retained'
);

delete from auth.users
where id = '40000000-0000-4000-8000-000000000001';

select is(
  (select count(*)::int from public.coach_purchases
   where purchase_id = '40000000-0000-4000-8000-000000000011'),
  1,
  'deleting the coach still preserves the accounting purchase'
);
select is(
  (select coach_id from public.coach_purchases
   where purchase_id = '40000000-0000-4000-8000-000000000011'),
  null::uuid,
  'the deleted coach UUID is detached from the purchase'
);
select is(
  (select package_id from public.coach_purchases
   where purchase_id = '40000000-0000-4000-8000-000000000011'),
  null::uuid,
  'the deleted coach package is detached from the purchase'
);
select is(
  (select price_cents from public.coach_purchases
   where purchase_id = '40000000-0000-4000-8000-000000000011'),
  4900,
  'the transaction amount is retained'
);
select is(
  (select package_title_snapshot || ':' || currency_snapshot
   from public.coach_purchases
   where purchase_id = '40000000-0000-4000-8000-000000000011'),
  'Piano mensile:EUR',
  'package snapshot remains after all source rows are deleted'
);

select * from finish();
rollback;
