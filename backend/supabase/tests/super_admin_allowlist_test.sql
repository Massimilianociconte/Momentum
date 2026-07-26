begin;

create extension if not exists pgtap with schema extensions;
select plan(7);

-- Email allowlisted con case misto: il confronto deve essere insensibile.
insert into private.super_admin_allowlist (email)
values ('owner@test.invalid')
on conflict (email) do nothing;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'Owner@Test.Invalid', '', null,
   '{"provider":"google","providers":["google"]}', '{}', now(), now()),
  ('22222222-2222-4222-8222-222222222222',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'regular@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

select is(
  (select count(*)::int from public.profiles
   where user_id = '11111111-1111-4111-8111-111111111111'),
  0,
  'an unconfirmed allowlisted email is not promoted on signup'
);

select throws_like(
  $$select public.grant_super_admin_by_email(
    'Owner@Test.Invalid', 'direct unconfirmed attempt'
  )$$,
  '%No confirmed auth user found%',
  'the grant function itself rejects an unconfirmed email'
);

update auth.users
set email_confirmed_at = now(), updated_at = now()
where id = '11111111-1111-4111-8111-111111111111';

select is(
  (select account_role from public.profiles
   where user_id = '11111111-1111-4111-8111-111111111111'),
  'super_admin',
  'confirmation UPDATE promotes an allowlisted email case-insensitively'
);
select is(
  (select plan from public.profiles
   where user_id = '11111111-1111-4111-8111-111111111111'),
  'coach',
  'confirmed allowlisted signup gets the coach plan'
);
select is(
  (select active from public.admin_test_accounts
   where user_id = '11111111-1111-4111-8111-111111111111'),
  true,
  'allowlisted signup is tracked as active admin account'
);

select is(
  (select count(*)::int from pg_trigger
   where tgname = 'apply_super_admin_allowlist'
     and tgenabled <> 'D'),
  1,
  'one enabled INSERT/UPDATE allowlist trigger is installed'
);

insert into public.profiles (user_id, name, nickname) values
  ('22222222-2222-4222-8222-222222222222', 'Regular', 'regular');

select is(
  (select account_role from public.profiles
   where user_id = '22222222-2222-4222-8222-222222222222'),
  'user',
  'non-allowlisted signup keeps the default role'
);

select * from finish();
rollback;
