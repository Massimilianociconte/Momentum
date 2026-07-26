begin;

create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '00000000-0000-0000-0000-000000000000', 'authenticated',
  'authenticated', 'push-retention@test.invalid', '', now(),
  '{"provider":"email","providers":["email"]}', '{}', now(), now()
);

select has_function(
  'public', 'cleanup_push_notifications', array[]::text[],
  'cleanup_push_notifications() exists'
);
select ok(
  not has_function_privilege(
    'anon', 'public.cleanup_push_notifications()', 'EXECUTE'
  ),
  'anonymous callers cannot run push retention'
);
select ok(
  not has_function_privilege(
    'authenticated', 'public.cleanup_push_notifications()', 'EXECUTE'
  ),
  'authenticated callers cannot run push retention'
);
select ok(
  has_function_privilege(
    'service_role', 'public.cleanup_push_notifications()', 'EXECUTE'
  ),
  'service role can run push retention'
);

insert into public.push_devices(
  device_id, user_id, installation_id, platform, transport, environment,
  token, enabled, invalidated_at, created_at, updated_at
) values
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
   'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
   'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
   'ANDROID', 'FCM', 'PRODUCTION',
   'fcm-retention-token-abcdefghijklmnopqrstuvwxyz', true, null, now(), now()),
  ('ffffffff-ffff-4fff-8fff-ffffffffffff',
   'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
   '99999999-9999-4999-8999-999999999999',
   'IOS', 'APNS', 'SANDBOX',
   'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
   false, now() - interval '31 days', now() - interval '31 days',
   now() - interval '31 days');

insert into public.push_outbox(
  notification_id, recipient_user_id, kind, title, body, dedupe_key, status,
  expires_at, created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111',
   'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'ACCOUNT', 'Old', 'Terminal',
   'retention-old-terminal', 'SENT', now() - interval '31 days',
   now() - interval '31 days', now() - interval '31 days'),
  ('22222222-2222-4222-8222-222222222222',
   'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'ACCOUNT', 'Old', 'Expired',
   'retention-old-expired', 'RETRY', now() - interval '31 days',
   now() - interval '31 days', now() - interval '31 days'),
  ('33333333-3333-4333-8333-333333333333',
   'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'ACCOUNT', 'Recent', 'Keep',
   'retention-recent', 'SENT', now() - interval '1 hour',
   now() - interval '1 hour', now() - interval '1 hour');

insert into public.push_deliveries(
  notification_id, device_id, attempt, status, created_at
) values (
  '11111111-1111-4111-8111-111111111111',
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  1, 'SENT', now() - interval '31 days'
);

select is(
  (public.cleanup_push_notifications() ->> 'push_notifications')::int,
  2,
  'cleanup removes terminal and expired notifications older than 30 days'
);
select is(
  (public.cleanup_push_notifications() ->> 'push_devices')::int,
  0,
  'a second idempotent cleanup has no stale device left to remove'
);
select is(
  (select count(*)::int from public.push_devices
   where device_id = 'ffffffff-ffff-4fff-8fff-ffffffffffff'),
  0,
  'provider-invalidated routing identifiers are removed after 30 days'
);
select is(
  (select count(*)::int from public.push_outbox
   where dedupe_key like 'retention-%'),
  1,
  'recent notification remains available'
);
select is(
  (select dedupe_key from public.push_outbox
   where dedupe_key like 'retention-%'),
  'retention-recent',
  'the retained row is the recent notification'
);
select is(
  (select count(*)::int from public.push_deliveries
   where notification_id = '11111111-1111-4111-8111-111111111111'),
  0,
  'delivery audit is removed in cascade with its outbox row'
);

select * from finish();
rollback;
