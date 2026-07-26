begin;

create extension if not exists pgtap with schema extensions;
select plan(53);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('11111111-1111-4111-8111-111111111111',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'free-a@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('22222222-2222-4222-8222-222222222222',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'plus-a@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('33333333-3333-4333-8333-333333333333',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'plus-b@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles (
  user_id, name, nickname, privacy, plan, social_enabled,
  map_visibility, availability, plan_expires_at
) values
  ('11111111-1111-4111-8111-111111111111', 'Free A', 'free-a',
   'PRIVATE', 'free', true, 'PUBLIC', 'TODAY', null),
  ('22222222-2222-4222-8222-222222222222', 'Plus A', 'plus-a',
   'PUBLIC', 'plus', true, 'PUBLIC', 'TODAY', now() + interval '30 days'),
  ('33333333-3333-4333-8333-333333333333', 'Plus B', 'plus-b',
   'PUBLIC', 'plus', true, 'PUBLIC', 'TODAY', now() + interval '30 days');

create temporary table test_state (
  key text primary key,
  value jsonb not null
);
grant select, insert, update on test_state to authenticated;

select is(
  (select count(*)::int from pg_tables
   where schemaname = 'public' and not rowsecurity),
  0,
  'every public table has RLS enabled'
);
select is(
  (select count(*)::int
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef
     and has_function_privilege('anon', p.oid, 'EXECUTE')),
  0,
  'anon cannot execute SECURITY DEFINER functions'
);
select is(
  (select count(*)::int from pg_tables t
   where t.schemaname = 'public'
     and has_table_privilege('anon', quote_ident(t.schemaname) || '.' ||
       quote_ident(t.tablename), 'TRUNCATE')),
  0,
  'anon cannot truncate public tables'
);
select is(
  (select count(*)::int from pg_tables t
   where t.schemaname = 'public'
     and has_table_privilege('authenticated', quote_ident(t.schemaname) || '.' ||
       quote_ident(t.tablename), 'TRUNCATE')),
  0,
  'authenticated cannot truncate public tables'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  public.has_duo_access('11111111-1111-4111-8111-111111111111'),
  false,
  'Free account has no Duo entitlement'
);
select is(
  public.has_duo_access('22222222-2222-4222-8222-222222222222'),
  false,
  'caller cannot inspect another user entitlement'
);
select throws_ok(
  $$update public.profiles set premium_override = true
    where user_id = '11111111-1111-4111-8111-111111111111'$$,
  '42501',
  'new row violates row-level security policy for table "profiles"',
  'Free user cannot grant itself Premium override'
);
select throws_ok(
  $$update public.profiles set reliability_score = 100
    where user_id = '11111111-1111-4111-8111-111111111111'$$,
  '42501',
  'new row violates row-level security policy for table "profiles"',
  'client cannot forge its public reliability score'
);
select is(
  (public.send_friend_request(
    '22222222-2222-4222-8222-222222222222', 'Giochiamo?'
  )->>'ok')::boolean,
  true,
  'friend request is created through the guarded RPC'
);
insert into test_state(key, value)
select 'friend_request', jsonb_build_object('id', request_id)
from public.social_contact_requests
where requester_id = '11111111-1111-4111-8111-111111111111'
  and receiver_id = '22222222-2222-4222-8222-222222222222';
select is(
  (select count(*)::int from public.social_relationships()
   where status = 'PENDING' and direction = 'OUTGOING'),
  1,
  'requester sees one pending outgoing relationship'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (public.respond_friend_request(
    ((select value->>'id' from test_state where key = 'friend_request'))::uuid,
    true
  )->>'status'),
  'ACCEPTED',
  'receiver can accept the friend request'
);
select is(
  (select count(*)::int from public.social_relationships()
   where status = 'ACCEPTED'),
  1,
  'accepted friendship is reciprocal'
);
select ok(
  public.block_user('11111111-1111-4111-8111-111111111111'),
  'user can block a friend'
);
select is(
  (select count(*)::int from public.discover_social_players(50)
   where user_id = '11111111-1111-4111-8111-111111111111'),
  0,
  'blocked user disappears from discovery'
);
select ok(
  public.unblock_user('11111111-1111-4111-8111-111111111111'),
  'user can unblock a profile'
);
select is(
  (select count(*)::int from public.discover_social_players(50)
   where user_id = '11111111-1111-4111-8111-111111111111'),
  1,
  'explicit social visibility is not overwritten by generic profile privacy'
);
insert into test_state(key, value)
values (
  'friend_invite',
  public.create_invite('FRIEND', null, null, null, null, 30)
);
select is(
  (select (value->>'ok')::boolean from test_state where key = 'friend_invite'),
  true,
  'signed friend invite is created server-side'
);
insert into test_state(key, value)
values (
  'profile_invite',
  public.create_invite(
    'PROFILE', null, null, null, null, 30,
    '33333333-3333-4333-8333-333333333333'
  )
);
select is(
  (select (value->>'ok')::boolean from test_state where key = 'profile_invite'),
  true,
  'public profile share token is opaque and created server-side'
);
insert into test_state(key, value)
values (
  'match_proposal',
  public.send_match_proposal(
    '33333333-3333-4333-8333-333333333333', 'Partita sabato?', 'B'
  )
);
select is(
  (select value->>'status' from test_state where key = 'match_proposal'),
  'OPEN',
  'match proposal is created through the guarded RPC'
);
insert into test_state(key, value)
values (
  'team_request',
  public.send_team_join_request(
    '33333333-3333-4333-8333-333333333333', 'Cerco un team stabile'
  )
);
select is(
  (select value->>'status' from test_state where key = 'team_request'),
  'PENDING',
  'team request is created through the guarded RPC'
);
insert into test_state(key, value)
values (
  'cloud_team',
  jsonb_build_object(
    'id', public.upsert_cloud_team(
      'local-team-a', 'Team Alpha', 'AUTO', 4291359029, 'PRIVATE'
    )
  )
);
select isnt(
  (select value->>'id' from test_state where key = 'cloud_team'),
  '',
  'owner creates one cloud team with a stable local key'
);
insert into test_state(key, value)
values (
  'team_invite',
  public.create_invite(
    'TEAM_JOIN',
    ((select value->>'id' from test_state where key = 'cloud_team'))::uuid,
    null, null, null, 30
  )
);
select is(
  (select (value->>'ok')::boolean from test_state where key = 'team_invite'),
  true,
  'team owner creates a revocable membership invite'
);
select throws_ok(
  $$insert into public.match_proposals(creator_id, receiver_id)
    values (
      '22222222-2222-4222-8222-222222222222',
      '33333333-3333-4333-8333-333333333333'
    )$$,
  '42501',
  null,
  'client cannot bypass proposal validation with a direct insert'
);

insert into test_state(key, value)
values (
  'duo',
  public.duo_create_session(
    'match_security_0001',
    '{"setsToWin":2,"gamesToWinSet":6,"tieBreakAtGames":6,
      "tieBreakPoints":7,"decidingPoint":false}'::jsonb,
    'TEAM_A'
  )
);
select is(
  (select (value->>'ok')::boolean from test_state where key = 'duo'),
  true,
  'Premium user can create a Duo session'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  public.preview_invite(
    (select value->>'token' from test_state where key = 'friend_invite')
  )->>'kind',
  'FRIEND',
  'invite can be previewed before consent'
);
select is(
  (public.redeem_invite(
    (select value->>'token' from test_state where key = 'friend_invite')
  )->>'ok')::boolean,
  true,
  'confirmed friend invite is redeemed once'
);
select is(
  public.preview_invite(
    (select value->>'token' from test_state where key = 'profile_invite')
  )->>'kind',
  'PROFILE',
  'shared profile can be previewed before opening it'
);
select is(
  (public.redeem_invite(
    (select value->>'token' from test_state where key = 'profile_invite')
  )->>'ok')::boolean,
  true,
  'opening a profile requires explicit invite confirmation'
);
select is(
  (select count(*)::int from public.social_contact_requests
   where status = 'ACCEPTED'
     and least(requester_id, receiver_id) = least(
       '11111111-1111-4111-8111-111111111111'::uuid,
       '33333333-3333-4333-8333-333333333333'::uuid
     )
     and greatest(requester_id, receiver_id) = greatest(
       '11111111-1111-4111-8111-111111111111'::uuid,
       '33333333-3333-4333-8333-333333333333'::uuid
     )),
  0,
  'opening a shared profile never creates an friendship implicitly'
);
select is(
  (public.redeem_invite(
    (select value->>'token' from test_state where key = 'team_invite')
  )->>'ok')::boolean,
  true,
  'confirmed team invite creates an accepted membership'
);
select is(
  (select count(*)::int from public.my_cloud_teams()
   where team_id =
     ((select value->>'id' from test_state where key = 'cloud_team'))::uuid
     and cloud_role = 'MEMBER'),
  1,
  'accepted cloud team is visible to the invited member exactly once'
);
select is(
  public.duo_join_session(
    (select value->>'joinCode' from test_state where key = 'duo')
  )->>'error',
  'premium_required',
  'Free user cannot join Duo through a legacy code'
);
select is(
  public.has_cloud_media_access(),
  false,
  'Free account cannot upload premium team media'
);
select is(
  public.duo_ack_state(
    ((select value->>'sessionId' from test_state where key = 'duo'))::uuid,
    0,
    false
  )->>'error',
  'session_not_available',
  'non-participant cannot acknowledge a pending Duo session'
);
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  public.respond_social_item(
    'proposal',
    ((select value->>'proposalId' from test_state where key = 'match_proposal'))::uuid,
    true
  )->>'status',
  'ACCEPTED',
  'only the recipient can accept a match proposal'
);
select is(
  public.respond_social_item(
    'team',
    ((select value->>'requestId' from test_state where key = 'team_request'))::uuid,
    false
  )->>'status',
  'DECLINED',
  'team request response updates the correct table'
);
insert into test_state(key, value)
values (
  'duo_join',
  public.duo_join_session(
    (select value->>'joinCode' from test_state where key = 'duo')
  )
);
select is(
  (select value->>'myTeam' from test_state where key = 'duo_join'),
  'TEAM_B',
  'second Premium user is assigned only to the opposite team'
);
select is(
  public.has_cloud_media_access(),
  true,
  'Premium account can use cloud team media'
);
select lives_ok(
  $$insert into public.duo_events(
      event_id, session_id, match_id, ts_ms, type, team_id,
      source_device, source_method, source_user_id, source_team_id
    ) values (
      '7a786f4a-5433-4b27-9b38-2f29012e4a67',
      ((select value->>'sessionId' from test_state where key = 'duo'))::uuid,
      'match_security_0001',
      (extract(epoch from now()) * 1000)::bigint,
      'POINT_TEAM_B', 'TEAM_B',
      'WEAR_OS', 'TAP', '33333333-3333-4333-8333-333333333333', 'TEAM_B'
    )$$,
  'assigned team event passes RLS'
);
select throws_ok(
  $$insert into public.duo_events(
      event_id, session_id, match_id, ts_ms, type, team_id,
      source_device, source_method, source_user_id, source_team_id
    ) values (
      'evt_test_a_0001',
      ((select value->>'sessionId' from test_state where key = 'duo'))::uuid,
      'match_security_0001',
      (extract(epoch from now()) * 1000)::bigint,
      'POINT_TEAM_A', 'TEAM_A',
      'WEAR_OS', 'TAP', '33333333-3333-4333-8333-333333333333', 'TEAM_B'
    )$$,
  '42501',
  'new row violates row-level security policy for table "duo_events"',
  'watch cannot score for the other team'
);
select lives_ok(
  $$insert into public.duo_events(
      event_id, session_id, match_id, ts_ms, type, team_id,
      source_device, source_method, source_user_id, source_team_id
    ) values (
      '7a786f4a-5433-4b27-9b38-2f29012e4a67',
      ((select value->>'sessionId' from test_state where key = 'duo'))::uuid,
      'match_security_0001',
      (extract(epoch from now()) * 1000)::bigint,
      'POINT_TEAM_B', 'TEAM_B',
      'WEAR_OS', 'TAP', '33333333-3333-4333-8333-333333333333', 'TEAM_B'
    ) on conflict (event_id) do nothing$$,
  'idempotent retry does not duplicate an event'
);
select is(
  (select count(*)::int from public.duo_events
   where event_id = '7a786f4a-5433-4b27-9b38-2f29012e4a67'),
  1,
  'duplicate event UUID is stored once'
);
select is(
  public.duo_ack_state(
    ((select value->>'sessionId' from test_state where key = 'duo'))::uuid,
    999999,
    true
  )->>'error',
  'invalid_cursor',
  'client cannot acknowledge events it has not replayed'
);
select is(
  public.duo_ack_state(
    ((select value->>'sessionId' from test_state where key = 'duo'))::uuid,
    (select max(seq) from public.duo_events where match_id = 'match_security_0001'),
    true
  )->>'status',
  'FINALIZING',
  'one participant cannot close a two-team timeline unilaterally'
);
select lives_ok(
  $$insert into public.duo_events(
      event_id, session_id, match_id, ts_ms, type, team_id,
      source_device, source_method, source_user_id, source_team_id,
      created_locally_at
    ) values (
      'evt_test_b_late_0002',
      ((select value->>'sessionId' from test_state where key = 'duo'))::uuid,
      'match_security_0001',
      (extract(epoch from now()) * 1000)::bigint,
      'POINT_TEAM_B', 'TEAM_B', 'WEAR_OS', 'TAP',
      '33333333-3333-4333-8333-333333333333', 'TEAM_B',
      (extract(epoch from now()) * 1000)::bigint
    )$$,
  'offline event remains uploadable while Duo is finalizing'
);
select is(
  (select status from public.duo_sessions
   where session_id =
     ((select value->>'sessionId' from test_state where key = 'duo'))::uuid),
  'ACTIVE',
  'a late event reopens finalization and resets stale acknowledgements'
);
select is(
  public.duo_ack_state(
    ((select value->>'sessionId' from test_state where key = 'duo'))::uuid,
    (select max(seq) from public.duo_events where match_id = 'match_security_0001'),
    true
  )->>'status',
  'FINALIZING',
  'updated participant acknowledgement waits for the other team'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  public.duo_ack_state(
    ((select value->>'sessionId' from test_state where key = 'duo'))::uuid,
    (select max(seq) from public.duo_events where match_id = 'match_security_0001'),
    true
  )->>'status',
  'COMPLETED',
  'Duo closes only after both participants replay the same timeline'
);
select lives_ok(
  $$insert into public.duo_events(
      event_id, session_id, match_id, ts_ms, type, team_id,
      source_device, source_method, source_user_id, source_team_id,
      created_locally_at
    ) values (
      'evt_test_a_after_close',
      ((select value->>'sessionId' from test_state where key = 'duo'))::uuid,
      'match_security_0001',
      (extract(epoch from now()) * 1000)::bigint,
      'POINT_TEAM_A', 'TEAM_A', 'PHONE', 'TAP',
      '22222222-2222-4222-8222-222222222222', 'TEAM_A',
      (extract(epoch from now()) * 1000)::bigint
    )$$,
  'a recently completed Duo accepts an event created around match completion'
);
select is(
  (select status from public.duo_sessions
   where session_id =
     ((select value->>'sessionId' from test_state where key = 'duo'))::uuid),
  'ACTIVE',
  'late post-completion event reopens the two-phase acknowledgement'
);
select is(
  public.duo_ack_state(
    ((select value->>'sessionId' from test_state where key = 'duo'))::uuid,
    (select max(seq) from public.duo_events where match_id = 'match_security_0001'),
    true
  )->>'status',
  'FINALIZING',
  'creator must acknowledge the recovered timeline again'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  public.duo_ack_state(
    ((select value->>'sessionId' from test_state where key = 'duo'))::uuid,
    (select max(seq) from public.duo_events where match_id = 'match_security_0001'),
    true
  )->>'status',
  'COMPLETED',
  'guest acknowledgement closes the recovered timeline again'
);

reset role;
update public.duo_sessions
set completed_at = now() - interval '8 days'
where session_id =
  ((select value->>'sessionId' from test_state where key = 'duo'))::uuid;
select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',
  true
);
set local role authenticated;
select throws_ok(
  $$insert into public.duo_events(
      event_id, session_id, match_id, ts_ms, type, team_id,
      source_device, source_method, source_user_id, source_team_id,
      created_locally_at
    ) values (
      'evt_test_a_after_recovery_window',
      ((select value->>'sessionId' from test_state where key = 'duo'))::uuid,
      'match_security_0001',
      (extract(epoch from now()) * 1000)::bigint,
      'POINT_TEAM_A', 'TEAM_A', 'PHONE', 'TAP',
      '22222222-2222-4222-8222-222222222222', 'TEAM_A',
      (extract(epoch from now() - interval '10 minutes') * 1000)::bigint
    )$$,
  '42501',
  'new row violates row-level security policy for table "duo_events"',
  'completed Duo becomes immutable after the bounded recovery window'
);

reset role;
select * from finish();
rollback;
