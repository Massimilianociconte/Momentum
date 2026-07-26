begin;

-- An allowlisted address is not proof of ownership until the auth provider has
-- confirmed it.  Keep this invariant in the grant function itself so trigger,
-- service-role and manual SQL callers cannot accidentally bypass it.
create or replace function public.grant_super_admin_by_email(
  p_email text,
  p_purpose text default 'owner premium assistant testing'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
begin
  select auth_user.id into v_user_id
  from auth.users auth_user
  where lower(auth_user.email) = lower(btrim(p_email))
    and auth_user.email_confirmed_at is not null
  limit 1;

  if v_user_id is null then
    raise exception 'No confirmed auth user found for %', p_email;
  end if;

  insert into public.profiles(
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

  insert into public.admin_test_accounts(
    user_id, purpose, granted_by, active
  ) values (
    v_user_id, p_purpose, 'manual_sql', true
  )
  on conflict (user_id) do update
    set purpose = excluded.purpose,
        granted_by = excluded.granted_by,
        active = true;
end;
$$;

revoke all on function public.grant_super_admin_by_email(text, text)
  from public, anon, authenticated;
grant execute on function public.grant_super_admin_by_email(text, text)
  to service_role;

create or replace function private.apply_super_admin_allowlist()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is not null
     and new.email_confirmed_at is not null
     and exists (
       select 1
       from private.super_admin_allowlist allowlisted
       where allowlisted.email = lower(new.email)
     ) then
    begin
      perform public.grant_super_admin_by_email(
        new.email, 'owner allowlist'
      );
    exception when others then
      -- Never break an auth confirmation transaction because a secondary
      -- profile grant failed. The warning remains visible in database logs.
      raise warning 'super_admin allowlist grant failed for %: %',
        new.email, sqlerrm;
    end;
  end if;
  return new;
end;
$$;

revoke all on function private.apply_super_admin_allowlist()
  from public, anon, authenticated;

drop trigger if exists apply_super_admin_allowlist on auth.users;
create trigger apply_super_admin_allowlist
after insert or update of email, email_confirmed_at on auth.users
for each row execute function private.apply_super_admin_allowlist();

-- Repair any unconfirmed account promoted by the previous INSERT-only trigger.
update public.profiles profile
set plan = 'free',
    plan_expires_at = null,
    account_role = 'user',
    assistant_daily_limit = 20,
    assistant_live_limit = 5
from auth.users auth_user
join public.admin_test_accounts admin_account
  on admin_account.user_id = auth_user.id
where profile.user_id = auth_user.id
  and auth_user.email_confirmed_at is null
  and admin_account.purpose = 'owner allowlist'
  and profile.account_role = 'super_admin';

update public.admin_test_accounts admin_account
set active = false
from auth.users auth_user
where admin_account.user_id = auth_user.id
  and auth_user.email_confirmed_at is null
  and admin_account.purpose = 'owner allowlist';

-- Existing confirmed allowlisted accounts stay idempotently promoted; an
-- unconfirmed row will be handled only by the UPDATE trigger on confirmation.
do $$
declare
  v_email text;
begin
  for v_email in
    select auth_user.email
    from auth.users auth_user
    join private.super_admin_allowlist allowlisted
      on allowlisted.email = lower(auth_user.email)
    where auth_user.email_confirmed_at is not null
  loop
    perform public.grant_super_admin_by_email(v_email, 'owner allowlist');
  end loop;
end;
$$;

commit;
