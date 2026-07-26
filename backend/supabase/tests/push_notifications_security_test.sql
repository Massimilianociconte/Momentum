begin;

create extension if not exists pgtap with schema extensions;
select plan(21);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'push-a@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'push-b@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles(
  user_id, name, nickname, privacy, plan, social_enabled, map_visibility
) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Push A', 'push-a',
   'PUBLIC', 'free', true, 'PUBLIC'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'Push B', 'push-b',
   'PUBLIC', 'free', true, 'PUBLIC');

select has_table('public', 'push_devices', 'push token registry exists');
select has_table('public', 'push_outbox', 'push outbox exists');
select has_table('public', 'push_deliveries', 'push delivery audit exists');
select ok(
  not has_table_privilege('authenticated', 'public.push_devices', 'SELECT'),
  'authenticated users cannot read raw routing tokens'
);
select ok(
  not has_table_privilege('authenticated', 'public.push_outbox', 'SELECT'),
  'authenticated users cannot enumerate other notification content'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.register_my_push_device(uuid,text,text,text,text,text,text)',
    'EXECUTE'
  ),
  'authenticated users can register only through the guarded RPC'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.register_my_push_device(uuid,text,text,text,text,text,text)',
    'EXECUTE'
  ),
  'anonymous callers cannot register tokens'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.claim_push_notifications(integer)',
    'EXECUTE'
  ),
  'app users cannot claim the server push queue'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}',
  true
);
set local role authenticated;

select lives_ok(
  $$select public.register_my_push_device(
    '11111111-1111-4111-8111-111111111111',
    'ANDROID', 'FCM', 'PRODUCTION',
    'fcm-token-abcdefghijklmnopqrstuvwxyz0123456789',
    '1.0.0', 'it-IT'
  )$$,
  'an authenticated install can register a valid FCM token'
);
select is(
  public.register_my_push_device(
    '11111111-1111-4111-8111-111111111111',
    'ANDROID', 'FCM', 'PRODUCTION',
    'fcm-token-abcdefghijklmnopqrstuvwxyz0123456789',
    '1.0.1', 'it-IT'
  )->>'ok',
  'true',
  'token refresh is idempotent for the same installation'
);
select throws_ok(
  $$select public.register_my_push_device(
    '11111111-1111-4111-8111-111111111111',
    'IOS', 'APNS', 'SANDBOX', 'not-a-token', '', ''
  )$$,
  '22023',
  'invalid push token',
  'malformed APNs tokens are rejected server-side'
);
select lives_ok(
  $$select public.send_friend_request(
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'Giochiamo?'
  )$$,
  'social request still succeeds with the push trigger enabled'
);

reset role;
select is(
  (select count(*)::int from public.push_devices
    where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
      and enabled),
  1,
  'the token is stored once and remains private'
);
select is(
  (select count(*)::int from public.push_outbox
    where recipient_user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
      and kind = 'FRIEND_REQUEST'),
  1,
  'a friend request enqueues exactly one recipient notification'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  public.respond_friend_request(
    (select request_id from public.social_contact_requests
      where requester_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
    true
  )->>'status',
  'ACCEPTED',
  'recipient can accept the request with push triggers enabled'
);

reset role;
select is(
  (select count(*)::int from public.push_outbox
    where recipient_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
      and kind = 'FRIEND_ACCEPTED'),
  1,
  'acceptance enqueues one notification back to the requester'
);

set local role service_role;
select is(
  (select kind from public.claim_push_notifications(1)),
  'FRIEND_REQUEST',
  'dispatcher claims HIGH priority work before NORMAL work'
);
reset role;
select is(
  (select status from public.push_outbox where kind = 'FRIEND_REQUEST'),
  'PROCESSING',
  'claimed work is leased instead of being selected twice'
);
select is(
  (select attempt_count from public.push_outbox where kind = 'FRIEND_REQUEST'),
  1,
  'claiming increments the delivery attempt atomically'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  public.deactivate_my_push_device(
    '11111111-1111-4111-8111-111111111111'
  )->>'deactivated',
  '1',
  'the owner can deactivate the current installation before logout'
);
reset role;
select is(
  (select count(*)::int from public.push_devices),
  0,
  'deactivation immediately removes the current raw routing identifier'
);

select * from finish();
rollback;
