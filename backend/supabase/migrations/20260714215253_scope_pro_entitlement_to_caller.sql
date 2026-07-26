-- Prevent an authenticated caller from probing another account's plan through
-- the boolean entitlement helper. Service-side callers retain explicit access.
create or replace function public.has_pro_access(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (uid = (select auth.uid()) or (select auth.role()) = 'service_role')
    and exists (
      select 1
      from public.profiles profile
      where profile.user_id = uid
        and (
          profile.plan in ('pro', 'coach')
          or profile.premium_override
          or profile.account_role in ('admin', 'super_admin')
        )
    ),
    false
  );
$$;

revoke all on function public.has_pro_access(uuid) from public, anon;
grant execute on function public.has_pro_access(uuid)
  to authenticated, service_role;
