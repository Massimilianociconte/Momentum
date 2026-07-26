-- DeepSeek assistant gating + owner test account controls.
--
-- Security note: this also tightens the original profile insert policy so a
-- client cannot create its own row with plan='pro' before RevenueCat/webhooks.

alter table public.profiles
  add column if not exists account_role text not null default 'user'
    check (account_role in ('user', 'admin', 'super_admin')),
  add column if not exists assistant_enabled boolean not null default true,
  add column if not exists assistant_daily_limit int not null default 20
    check (assistant_daily_limit between 0 and 500),
  add column if not exists assistant_live_limit int not null default 5
    check (assistant_live_limit between 0 and 100),
  add column if not exists last_basic_sync_at timestamptz;

create index if not exists profiles_account_role_idx
  on public.profiles (account_role);

-- Allow the new app-help assistant context.
alter table public.assistant_queries
  drop constraint if exists assistant_queries_mode_check;

alter table public.assistant_queries
  add constraint assistant_queries_mode_check
  check (mode in ('RULES', 'LIVE_MATCH', 'POST_MATCH', 'TRAINING', 'APP_HELP'));

create table if not exists public.admin_test_accounts (
  user_id uuid primary key references public.profiles (user_id) on delete cascade,
  purpose text not null default 'owner testing',
  granted_by text not null default 'manual',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.admin_test_accounts enable row level security;

drop policy if exists "admin test account read own" on public.admin_test_accounts;
create policy "admin test account read own"
  on public.admin_test_accounts
  for select using (auth.uid() = user_id);

-- Recreate profile policies with immutable privileged columns on client writes.
drop policy if exists "own profile insert" on public.profiles;
create policy "own profile insert" on public.profiles
  for insert with check (
    auth.uid() = user_id
    and plan = 'free'
    and account_role = 'user'
    and assistant_enabled = true
    and assistant_daily_limit = 20
    and assistant_live_limit = 5
  );

drop policy if exists "own profile write" on public.profiles;
create policy "own profile write" on public.profiles
  for update using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and plan = (select p.plan from public.profiles p where p.user_id = auth.uid())
    and account_role = (
      select p.account_role from public.profiles p where p.user_id = auth.uid()
    )
    and assistant_enabled = (
      select p.assistant_enabled from public.profiles p
      where p.user_id = auth.uid()
    )
    and assistant_daily_limit = (
      select p.assistant_daily_limit from public.profiles p
      where p.user_id = auth.uid()
    )
    and assistant_live_limit = (
      select p.assistant_live_limit from public.profiles p
      where p.user_id = auth.uid()
    )
  );

-- Manual owner/test grant. Execute from Supabase SQL editor as project owner
-- after creating your normal email/password account in the app.
create or replace function public.grant_super_admin_by_email(
  p_email text,
  p_purpose text default 'owner premium assistant testing'
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
begin
  select id into v_user_id
  from auth.users
  where lower(email) = lower(p_email)
  limit 1;

  if v_user_id is null then
    raise exception 'No auth user found for %', p_email;
  end if;

  insert into public.profiles (
    user_id,
    name,
    plan,
    account_role,
    assistant_enabled,
    assistant_daily_limit,
    assistant_live_limit
  )
  values (
    v_user_id,
    split_part(p_email, '@', 1),
    'coach',
    'super_admin',
    true,
    200,
    30
  )
  on conflict (user_id) do update
    set plan = 'coach',
        account_role = 'super_admin',
        assistant_enabled = true,
        assistant_daily_limit = 200,
        assistant_live_limit = 30;

  insert into public.admin_test_accounts (user_id, purpose, granted_by, active)
  values (v_user_id, p_purpose, 'manual_sql', true)
  on conflict (user_id) do update
    set purpose = excluded.purpose,
        granted_by = excluded.granted_by,
        active = true;
end;
$$;

revoke all on function public.grant_super_admin_by_email(text, text) from public;

comment on column public.profiles.account_role is
  'user/admin/super_admin. Only service role/manual SQL may change it.';
comment on column public.profiles.assistant_enabled is
  'Server-side kill switch for Rally Pro Assistant access.';
comment on table public.admin_test_accounts is
  'Owner-only privileged test accounts for subscription bypass validation.';
