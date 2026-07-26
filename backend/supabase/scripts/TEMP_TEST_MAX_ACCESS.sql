-- =============================================================================
-- TEMP TEST: max access for all registered users (disable paid gates)
-- =============================================================================
-- Paste into Supabase Dashboard → SQL Editor → Run.
--
-- Effect while enabled:
--   • has_active_entitlement() returns true for every authenticated profile
--     (RLS, Duo, health cloud, wearables, assistant, coach commercial gates, …)
--   • Existing profiles get plan=coach, premium_override, far expiry, high
--     Pallino quotas so the mobile client unlocks all UI after profile sync
--   • New signups get the same grant via trigger
--
-- ⚠️  TESTING ONLY — do not leave this on production stores.
-- ⚠️  WARNING RC: while enabled, RevenueCat plan rows are forced to coach;
--     after REVERT you MUST re-sync billing state for real subscribers.
--     Rollback: run the REVERT section at the bottom.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1) Runtime flag (single switch)
-- ---------------------------------------------------------------------------
create table if not exists public.app_runtime_flags (
  key text primary key,
  value text not null,
  note text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.app_runtime_flags enable row level security;

-- No client policies: only service_role / SQL editor (owner) manage flags.
revoke all on table public.app_runtime_flags from public, anon, authenticated;

insert into public.app_runtime_flags (key, value, note, updated_at)
values (
  'test_max_access',
  'true',
  'TEMP: unlock all paid entitlements for every registered user. Set to false and restore has_active_entitlement to re-enable billing gates.',
  now()
)
on conflict (key) do update
set value = excluded.value,
    note = excluded.note,
    updated_at = now();

create or replace function public.is_test_max_access_enabled()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select f.value = 'true'
      from public.app_runtime_flags f
      where f.key = 'test_max_access'
    ),
    false
  );
$$;

revoke all on function public.is_test_max_access_enabled() from public, anon;
grant execute on function public.is_test_max_access_enabled()
  to service_role;

-- ---------------------------------------------------------------------------
-- 2) Entitlement gate: short-circuit when flag is on
-- ---------------------------------------------------------------------------
create or replace function public.has_active_entitlement(
  p_user_id uuid,
  p_required_plans text[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      (p_user_id = (select auth.uid()) or (select auth.role()) = 'service_role')
      and exists (
        select 1
        from public.profiles profile
        where profile.user_id = p_user_id
          and (
            -- TEMP test bypass (all paid features)
            public.is_test_max_access_enabled()
            or profile.premium_override
            or profile.account_role in ('admin', 'super_admin')
            or (
              profile.plan = any (coalesce(p_required_plans, '{}'::text[]))
              and profile.plan_expires_at > now()
            )
          )
      )
    ),
    false
  );
$$;

revoke all on function public.has_active_entitlement(uuid, text[])
  from public, anon;
grant execute on function public.has_active_entitlement(uuid, text[])
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3) Grant max plan to every existing profile (client UI + assistant quotas)
-- ---------------------------------------------------------------------------
update public.profiles
set
  plan = 'coach',
  plan_expires_at = greatest(
    coalesce(plan_expires_at, now()),
    now() + interval '365 days'
  ),
  premium_override = true,
  assistant_enabled = true,
  assistant_daily_limit = least(500, greatest(coalesce(assistant_daily_limit, 20), 200)),
  assistant_live_limit = greatest(coalesce(assistant_live_limit, 5), 50)
where true;

-- ---------------------------------------------------------------------------
-- 4) Auto-grant after signup (AFTER INSERT — RLS insert forbids override=true)
-- ---------------------------------------------------------------------------
create or replace function public.trg_test_max_access_after_profile_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.is_test_max_access_enabled() then
    update public.profiles p
    set
      plan = 'coach',
      plan_expires_at = now() + interval '365 days',
      premium_override = true,
      assistant_enabled = true,
      assistant_daily_limit = least(500, greatest(coalesce(p.assistant_daily_limit, 20), 200)),
      assistant_live_limit = least(100, greatest(coalesce(p.assistant_live_limit, 5), 50))
    where p.user_id = new.user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_test_max_access_profiles_bi on public.profiles;
drop trigger if exists trg_test_max_access_profiles_ai on public.profiles;
create trigger trg_test_max_access_profiles_ai
  after insert on public.profiles
  for each row
  execute function public.trg_test_max_access_after_profile_insert();

-- Keep max access if billing webhook tries to downgrade during the test window.
create or replace function public.trg_test_max_access_before_profile_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.is_test_max_access_enabled() then
    new.plan := 'coach';
    new.plan_expires_at := greatest(
      coalesce(new.plan_expires_at, now()),
      now() + interval '365 days'
    );
    new.premium_override := true;
    new.assistant_enabled := true;
    if new.assistant_daily_limit is null or new.assistant_daily_limit < 200 then
      new.assistant_daily_limit := 200;
    end if;
    if new.assistant_live_limit is null or new.assistant_live_limit < 50 then
      new.assistant_live_limit := 50;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_test_max_access_profiles_bu on public.profiles;
create trigger trg_test_max_access_profiles_bu
  before update on public.profiles
  for each row
  when (public.is_test_max_access_enabled())
  execute function public.trg_test_max_access_before_profile_update();

commit;

-- Quick check (run after commit):
--   select key, value, updated_at from public.app_runtime_flags;
--   select plan, premium_override, plan_expires_at, assistant_enabled,
--          assistant_daily_limit, count(*)
--     from public.profiles
--    group by 1,2,3,4,5;

-- =============================================================================
-- REVERT (run when test phase ends — restores paid gates)
-- =============================================================================
/*
begin;

update public.app_runtime_flags
set value = 'false',
    note = 'Disabled — paid subscription gates restored.',
    updated_at = now()
where key = 'test_max_access';

drop trigger if exists trg_test_max_access_profiles_ai on public.profiles;
drop trigger if exists trg_test_max_access_profiles_bu on public.profiles;
drop function if exists public.trg_test_max_access_after_profile_insert();
drop function if exists public.trg_test_max_access_before_profile_update();
drop function if exists public.is_test_max_access_enabled();

-- Restore production has_active_entitlement (no flag short-circuit)
create or replace function public.has_active_entitlement(
  p_user_id uuid,
  p_required_plans text[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      (p_user_id = (select auth.uid()) or (select auth.role()) = 'service_role')
      and exists (
        select 1
        from public.profiles profile
        where profile.user_id = p_user_id
          and (
            profile.premium_override
            or profile.account_role in ('admin', 'super_admin')
            or (
              profile.plan = any (coalesce(p_required_plans, '{}'::text[]))
              and profile.plan_expires_at > now()
            )
          )
      )
    ),
    false
  );
$$;

revoke all on function public.has_active_entitlement(uuid, text[])
  from public, anon;
grant execute on function public.has_active_entitlement(uuid, text[])
  to authenticated, service_role;

-- REQUIRED: strip test grants (otherwise premium_override keeps everyone unlocked)
update public.profiles
set plan = 'free',
    plan_expires_at = null,
    premium_override = false,
    assistant_daily_limit = 20,
    assistant_live_limit = 5
where account_role is distinct from 'admin'
  and account_role is distinct from 'super_admin';

-- Re-grant RLS helpers (same as production migration)
grant execute on function public.has_active_entitlement(uuid, text[])
  to authenticated, service_role;
grant execute on function public.has_cloud_media_access()
  to authenticated, service_role;
grant execute on function public.has_duo_access(uuid)
  to authenticated, service_role;
grant execute on function public.has_pro_access(uuid)
  to authenticated, service_role;

-- NOTE: after REVERT, re-sync real plans from RevenueCat (or re-run webhook
-- historical events) for paying users. Ledger events already APPLIED will
-- not redeliver automatically.

commit;
*/
