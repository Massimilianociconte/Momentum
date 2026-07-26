begin;

create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
   '00000000-0000-0000-0000-000000000000', 'authenticated',
   'authenticated', 'coach@test.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles (user_id, name, nickname, plan) values
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'Coach', 'coach', 'coach');

insert into public.coach_profiles (coach_id) values
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd');

-- ============================================ commission rate server-side
-- Il rate è imposto dal trigger in base al tipo: qualunque valore scritto
-- dal client viene ignorato (revenue bypass, PRD I3).

insert into public.coach_packages
  (package_id, coach_id, title, type, price_cents, commission_rate)
values
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1',
   'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
   'Digital plan', 'DIGITAL_PROGRAM', 4900, 0.000),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2',
   'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
   'Live lesson', 'LIVE_1TO1', 6000, 0.999);

select is(
  (select commission_rate::numeric from public.coach_packages
   where package_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'),
  0.150::numeric,
  'digital package: client-supplied 0 rate is overridden to 15%'
);

select is(
  (select commission_rate::numeric from public.coach_packages
   where package_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2'),
  0.100::numeric,
  'live package: client-supplied 0.999 rate is overridden to 10%'
);

update public.coach_packages
set commission_rate = 0.001
where package_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1';

select is(
  (select commission_rate::numeric from public.coach_packages
   where package_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'),
  0.150::numeric,
  'update cannot lower the rate: trigger re-derives it from the type'
);

-- Difesa in profondità: anche senza trigger il CHECK respinge rate fuori
-- dal range di business 5%-30%.
alter table public.coach_packages
  disable trigger coach_packages_enforce_commission;
select throws_ok(
  $$insert into public.coach_packages
      (coach_id, title, type, price_cents, commission_rate)
    values
      ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
       'Bypass attempt', 'DIGITAL_PROGRAM', 4900, 0.000)$$,
  '23514',
  null,
  'CHECK constraint rejects out-of-range rates even without the trigger'
);
alter table public.coach_packages
  enable trigger coach_packages_enforce_commission;

-- ============================================ assistant quota claim atomico

select is(
  (select count(*)::int
   from unnest(array['anon', 'authenticated']) as who(role_name)
   where has_function_privilege(
     who.role_name,
     'public.claim_assistant_slot(text,text,text,text,uuid,int,int)',
     'EXECUTE'
   )),
  0,
  'clients cannot claim assistant slots directly'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.claim_assistant_slot(text,text,text,text,uuid,int,int)',
    'EXECUTE'
  ),
  'edge function (service role) can claim assistant slots'
);

select isnt(
  (select query_id from public.claim_assistant_slot(
    null, 'RULES', 'q1', 'hash1',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 2, 30)),
  null::uuid,
  'first claim within the daily limit returns a pending row'
);

select is(
  (select used_today from public.claim_assistant_slot(
    null, 'RULES', 'q2', 'hash2',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 2, 30)),
  1,
  'second claim sees the pending row from the first claim'
);

select is(
  (select reason from public.claim_assistant_slot(
    null, 'RULES', 'q3', 'hash3',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 2, 30)),
  'daily_limit',
  'third claim over the daily limit is rejected without inserting'
);

select isnt(
  (select query_id from public.claim_assistant_slot(
    'match-live-1', 'LIVE_MATCH', 'q4', 'hash4',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 10, 1)),
  null::uuid,
  'live claim within the per-match limit returns a pending row'
);

select is(
  (select reason from public.claim_assistant_slot(
    'match-live-1', 'LIVE_MATCH', 'q5', 'hash5',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 10, 1)),
  'live_limit',
  'second live claim on the same match is rejected'
);

-- Cache-hit rimborsati: una riga finalizzata cached = true non conta.
-- A questo punto l'utente ha 3 righe pending (q1, q2, q4).
insert into public.assistant_queries
  (user_id, mode, question, question_hash, answer, cached)
values
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
   'RULES', 'q-cached', 'hash-cached', 'cached answer', true);

select is(
  (select used_today from public.claim_assistant_slot(
    null, 'RULES', 'q6', 'hash6',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 10, 30)),
  3,
  'cached rows do not consume the daily quota'
);

select * from finish();
rollback;
