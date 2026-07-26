begin;

create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('20000000-0000-4000-8000-000000000001',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'subscriber@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('20000000-0000-4000-8000-000000000002',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'transfer-source@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('20000000-0000-4000-8000-000000000003',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'transfer-target@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles(user_id, name, plan, plan_expires_at) values
  ('20000000-0000-4000-8000-000000000001', 'Subscriber', 'free', null),
  ('20000000-0000-4000-8000-000000000002', 'Source', 'coach', now() + interval '30 days'),
  ('20000000-0000-4000-8000-000000000003', 'Target', 'free', null);

select set_config('request.jwt.claims', '{"role":"service_role"}', true);

select is(
  (public.apply_revenuecat_plan_event(
    'renewal-1', 'RENEWAL', 1000,
    '20000000-0000-4000-8000-000000000001', 'pro', now() + interval '7 days'
  )->>'applied')::boolean,
  true,
  'a new lifecycle event is applied'
);
select is(
  (select plan from public.profiles
    where user_id = '20000000-0000-4000-8000-000000000001'),
  'pro',
  'the applied event updates the profile plan'
);
select is(
  public.apply_revenuecat_plan_event(
    'renewal-1', 'RENEWAL', 1000,
    '20000000-0000-4000-8000-000000000001', 'pro', now() + interval '7 days'
  )->>'reason',
  'duplicate_event',
  'the same RevenueCat event id is idempotent'
);

select is(
  (public.apply_revenuecat_plan_event(
    'expiration-same-time', 'EXPIRATION', 1000,
    '20000000-0000-4000-8000-000000000001', 'free', null
  )->>'applied')::boolean,
  true,
  'expiration wins over an active event with the same timestamp'
);
select is(
  (select plan from public.profiles
    where user_id = '20000000-0000-4000-8000-000000000001'),
  'free',
  'expiration revokes the plan'
);
select is(
  public.apply_revenuecat_plan_event(
    'older-renewal', 'RENEWAL', 999,
    '20000000-0000-4000-8000-000000000001', 'pro', now() + interval '7 days'
  )->>'reason',
  'stale_event',
  'an out-of-order older renewal is ignored'
);
select is(
  (select plan from public.profiles
    where user_id = '20000000-0000-4000-8000-000000000001'),
  'free',
  'the stale renewal cannot resurrect access'
);

select is(
  (public.apply_revenuecat_transfer_event(
    'transfer-1', 2000,
    array['20000000-0000-4000-8000-000000000002'::uuid],
    '20000000-0000-4000-8000-000000000003'
  )->>'applied')::boolean,
  true,
  'a transfer is applied atomically'
);
select is(
  (select plan from public.profiles
    where user_id = '20000000-0000-4000-8000-000000000002'),
  'free',
  'the transfer revokes the source profile'
);
select is(
  (select plan from public.profiles
    where user_id = '20000000-0000-4000-8000-000000000003'),
  'coach',
  'the transfer grants the target profile'
);
select ok(
  (select plan_expires_at > now() from public.profiles
    where user_id = '20000000-0000-4000-8000-000000000003'),
  'the transfer preserves the authoritative future expiry'
);
select is(
  public.apply_revenuecat_transfer_event(
    'transfer-1', 2000,
    array['20000000-0000-4000-8000-000000000002'::uuid],
    '20000000-0000-4000-8000-000000000003'
  )->>'reason',
  'duplicate_event',
  'a duplicate transfer is idempotent'
);

do $$
begin
  perform public.apply_revenuecat_plan_event(
    'target-expired-after-transfer', 'EXPIRATION', 2100,
    '20000000-0000-4000-8000-000000000003', 'free', null
  );
  perform public.apply_revenuecat_plan_event(
    'source-newer-renewal', 'RENEWAL', 3000,
    '20000000-0000-4000-8000-000000000002', 'pro',
    now() + interval '14 days'
  );
end;
$$;

select is(
  public.apply_revenuecat_transfer_event(
    'stale-transfer-after-source-renewal', 2500,
    array['20000000-0000-4000-8000-000000000002'::uuid],
    '20000000-0000-4000-8000-000000000003'
  )->>'reason',
  'stale_source_event',
  'an older transfer is ignored when its source has newer lifecycle state'
);
select is(
  (select plan from public.profiles
   where user_id = '20000000-0000-4000-8000-000000000002'),
  'pro',
  'the stale transfer does not revoke the newer source entitlement'
);
select is(
  (select plan from public.profiles
   where user_id = '20000000-0000-4000-8000-000000000003'),
  'free',
  'the stale transfer cannot duplicate access onto the target'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.apply_revenuecat_plan_event(text,text,bigint,uuid,text,timestamptz)',
    'EXECUTE'
  ),
  false,
  'authenticated clients cannot apply RevenueCat events'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.apply_revenuecat_transfer_event(text,bigint,uuid[],uuid)',
    'EXECUTE'
  ),
  'the RevenueCat Edge function can apply transfers'
);

select * from finish();
rollback;
