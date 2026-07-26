begin;

create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('10000000-0000-4000-8000-000000000001',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'active@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('10000000-0000-4000-8000-000000000002',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'expired@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('10000000-0000-4000-8000-000000000003',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'lifetime@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('10000000-0000-4000-8000-000000000004',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'override@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles (
  user_id, name, plan, plan_expires_at, premium_override
) values
  ('10000000-0000-4000-8000-000000000001', 'Active', 'pro', now() + interval '1 day', false),
  ('10000000-0000-4000-8000-000000000002', 'Expired', 'coach', now() - interval '1 second', false),
  ('10000000-0000-4000-8000-000000000003', 'Lifetime', 'coach', null, false),
  ('10000000-0000-4000-8000-000000000004', 'Override', 'free', null, true);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select ok(
  public.has_active_entitlement(
    '10000000-0000-4000-8000-000000000001', array['pro', 'coach']
  ),
  'future expiry grants the requested entitlement'
);

select is(
  public.has_active_entitlement(
    '10000000-0000-4000-8000-000000000002', array['pro', 'coach']
  ),
  false,
  'callers cannot probe another account entitlement'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);

select is(
  public.has_active_entitlement(
    '10000000-0000-4000-8000-000000000002', array['pro', 'coach']
  ),
  false,
  'past expiry denies the stored paid plan'
);
select is(public.has_pro_access('10000000-0000-4000-8000-000000000002'), false,
  'Pro helper denies an expired plan');
select is(public.has_duo_access('10000000-0000-4000-8000-000000000002'), false,
  'Duo helper denies an expired plan');
select is(public.has_cloud_media_access(), false,
  'backup/media helper denies an expired plan');
select is(
  public.my_coach_link_code()->>'error',
  'coach_required',
  'expired Coach cannot create or recover an athlete link code'
);

reset role;
insert into public.wearable_pairing_challenges(
  user_id, provider, code_hash, expires_at
) values (
  '10000000-0000-4000-8000-000000000002',
  'FITBIT_OS', 'expired-entitlement-code', now() + interval '10 minutes'
);
select set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);
set local role service_role;
select throws_ok(
  $$select public.claim_wearable_pairing(
    'expired-entitlement-code', 'FITBIT_OS', 'expired-token', 'Expired watch',
    array['scoring'], now() + interval '30 days'
  )$$,
  'P0001',
  'plan_required',
  'expired paid plan cannot claim a wearable pairing challenge'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  public.has_pro_access('10000000-0000-4000-8000-000000000003'),
  false,
  'NULL expiry fails closed for the subscription-only catalog'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated"}',
  true
);
select ok(public.has_duo_access('10000000-0000-4000-8000-000000000004'),
  'explicit premium override remains valid');

select is(
  has_function_privilege(
    'anon', 'public.has_active_entitlement(uuid,text[])', 'EXECUTE'
  ),
  false,
  'anonymous callers cannot execute the entitlement helper'
);
select ok(
  has_function_privilege(
    'authenticated', 'public.has_active_entitlement(uuid,text[])', 'EXECUTE'
  ),
  'authenticated callers can evaluate their own entitlement'
);
select ok(
  has_function_privilege(
    'service_role', 'public.has_active_entitlement(uuid,text[])', 'EXECUTE'
  ),
  'service-side Edge functions can evaluate entitlements'
);

select * from finish();
rollback;
