begin;

create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('d1111111-1111-4111-8111-111111111111',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'backup-free@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('d2222222-2222-4222-8222-222222222222',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'backup-plus@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles (
  user_id, name, nickname, plan, plan_expires_at
) values
  ('d1111111-1111-4111-8111-111111111111', 'Backup Free', 'backup-free', 'free', null),
  ('d2222222-2222-4222-8222-222222222222', 'Backup Plus', 'backup-plus', 'plus', now() + interval '30 days');

select is(
  has_table_privilege('anon', 'public.backups', 'SELECT'),
  false,
  'anonymous clients cannot read backups'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"d1111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$insert into public.backups(user_id, device_id, schema_ver, payload)
    values (
      'd1111111-1111-4111-8111-111111111111', 'primary', 2,
      '{"format":"rallymate-backup","v":2,"sections":{},"counts":{}}'
    )$$,
  '42501',
  'new row violates row-level security policy for table "backups"',
  'Free accounts cannot create cloud backups'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"d2222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
insert into public.backups(user_id, device_id, schema_ver, payload)
values (
  'd2222222-2222-4222-8222-222222222222', 'primary', 2,
  '{"format":"rallymate-backup","v":2,"sections":{},"counts":{}}'
);
select is(
  (select count(*)::int from public.backups),
  1,
  'Plus account can read its own backup'
);
select ok(
  (select payload_bytes > 0 from public.backups where device_id = 'primary'),
  'server computes the payload byte size'
);
select matches(
  (select payload_sha256 from public.backups where device_id = 'primary'),
  '^[0-9a-f]{64}$',
  'server computes a SHA-256 integrity fingerprint'
);
select throws_ok(
  $$insert into public.backups(user_id, device_id, schema_ver, payload)
    values (
      'd2222222-2222-4222-8222-222222222222', 'invalid', 2,
      '{"format":"wrong","v":2}'
    )$$,
  '23514',
  'backup_payload_format_invalid',
  'malformed v2 backup payload is rejected'
);
reset role;

-- Seed an owner backup as a privileged backend, then verify that a Free user
-- cannot restore it but can still delete it after a plan downgrade.
insert into public.backups(user_id, device_id, schema_ver, payload)
values (
  'd1111111-1111-4111-8111-111111111111', 'legacy', 1,
  '{"v":1,"players":[],"teams":[],"matches":[],"events":[],"trainingLogs":[]}'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"d1111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*)::int from public.backups),
  0,
  'Free account cannot read or restore an existing backup'
);
select is(
  public.delete_my_backup('legacy'),
  1,
  'downgraded owner can delete an unreadable backup through the guarded RPC'
);
reset role;

select is(
  (select count(*)::int from public.backups
   where user_id = 'd1111111-1111-4111-8111-111111111111'),
  0,
  'the guarded RPC removed only the owner backup'
);
select is(
  (select count(*)::int from public.backups
   where user_id = 'd2222222-2222-4222-8222-222222222222'),
  1,
  'one user cannot delete another user backup'
);

select * from finish();
rollback;
