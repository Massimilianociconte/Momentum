begin;

create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'member@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'outsider@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles (user_id, name, nickname, plan) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Member', 'member', 'free'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'Outsider', 'outsider', 'pro');

insert into public.friend_groups (group_id, owner_id, name, invite_code)
values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Test group',
  'RLSFIX01'
);
insert into public.friend_group_members (group_id, user_id)
values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
);

-- Production intentionally exposes groups only through guarded RPCs. Grant
-- temporary read access inside this rolled-back test to exercise RLS itself.
grant select on public.friend_groups, public.friend_group_members to authenticated;

select is(
  (select count(*)::int
   from unnest(array[
     'private.profile_privileged_fields_unchanged(uuid,text,timestamptz,boolean,text,boolean,integer,integer,integer)',
     'private.is_friend_group_member(uuid)'
   ]) as helper(signature)
   where has_function_privilege('anon', to_regprocedure(helper.signature), 'EXECUTE')),
  0,
  'anonymous clients cannot execute internal RLS helpers'
);

select is(
  (select count(*)::int
   from unnest(array[
     'private.profile_privileged_fields_unchanged(uuid,text,timestamptz,boolean,text,boolean,integer,integer,integer)',
     'private.is_friend_group_member(uuid)'
   ]) as helper(signature)
   where has_function_privilege(
     'authenticated', to_regprocedure(helper.signature), 'EXECUTE'
   )),
  2,
  'authenticated policy evaluation can execute both scoped helpers'
);

select is(
  (select count(*)::int from pg_policies
   where schemaname = 'public'
     and tablename in (
       'profiles', 'friend_groups', 'friend_group_members',
       'coach_assignments', 'coach_packages'
     )
     and roles <> array['authenticated']::name[]),
  0,
  'client-facing policies are scoped to authenticated instead of public'
);

select is(
  (select count(*)::int from pg_policies
   where schemaname = 'public' and tablename = 'coach_assignments'
     and cmd = 'SELECT'),
  1,
  'coach assignments use one combined SELECT policy'
);

select is(
  (select count(*)::int from pg_policies
   where schemaname = 'public' and tablename = 'coach_assignments'
     and cmd = 'UPDATE'),
  1,
  'coach assignments use one combined UPDATE policy'
);

select is(
  (select count(*)::int from pg_policies
   where schemaname = 'public' and tablename = 'coach_packages'
     and cmd = 'SELECT'),
  1,
  'coach packages use one SELECT policy'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.has_pro_access('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
  false,
  'caller cannot probe another account Pro entitlement'
);

update public.profiles
set bio = 'Allowed profile field'
where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
select is(
  (select bio from public.profiles
   where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  'Allowed profile field',
  'owner can still update ordinary profile fields'
);

select throws_ok(
  $$update public.profiles
    set plan_expires_at = now() + interval '100 years'
    where user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'$$,
  '42501',
  'new row violates row-level security policy for table "profiles"',
  'owner cannot forge subscription expiry'
);

select is(
  (select count(*)::int from public.friend_groups
   where group_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
  1,
  'group member can read the group without recursive RLS'
);
select is(
  (select count(*)::int from public.friend_group_members
   where group_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
  1,
  'group member can read memberships without recursive RLS'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*)::int from public.friend_group_members
   where group_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
  0,
  'non-member cannot read group memberships'
);

select * from finish();
rollback;
