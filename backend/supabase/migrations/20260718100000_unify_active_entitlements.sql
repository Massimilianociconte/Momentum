begin;

-- The current paid catalog is subscription-only: a stored plan is authoritative
-- only while its RevenueCat expiry is in the future. NULL therefore fails
-- closed. premium_override and admin roles are independent audited bypasses.
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
              profile.plan = any(coalesce(p_required_plans, '{}'::text[]))
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

create or replace function public.has_cloud_media_access()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_active_entitlement(
    (select auth.uid()),
    array['plus', 'pro', 'coach']::text[]
  );
$$;

create or replace function public.has_duo_access(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_active_entitlement(
    uid,
    array['plus', 'pro', 'coach']::text[]
  );
$$;

create or replace function public.has_pro_access(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_active_entitlement(
    uid,
    array['pro', 'coach']::text[]
  );
$$;

revoke all on function public.has_cloud_media_access() from public, anon;
revoke all on function public.has_duo_access(uuid) from public, anon;
revoke all on function public.has_pro_access(uuid) from public, anon;
grant execute on function public.has_cloud_media_access()
  to authenticated, service_role;
grant execute on function public.has_duo_access(uuid)
  to authenticated, service_role;
grant execute on function public.has_pro_access(uuid)
  to authenticated, service_role;

-- Every client-write policy for cloud health data delegates to the same
-- entitlement function so an expired plan cannot keep writing via RLS even if
-- an Edge webhook is delayed.
alter policy "premium owner inserts health sources"
  on public.health_data_sources
  with check (
    (select auth.uid()) = user_id
    and (select public.has_active_entitlement(
      (select auth.uid()), array['plus', 'pro', 'coach']::text[]
    ))
  );

alter policy "premium owner updates health sources"
  on public.health_data_sources
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and (select public.has_active_entitlement(
      (select auth.uid()), array['plus', 'pro', 'coach']::text[]
    ))
  );

alter policy "premium owner inserts health metrics"
  on public.health_metric_records
  with check (
    (select auth.uid()) = user_id
    and (select public.has_active_entitlement(
      (select auth.uid()), array['plus', 'pro', 'coach']::text[]
    ))
  );

alter policy "premium owner updates health metrics"
  on public.health_metric_records
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and (select public.has_active_entitlement(
      (select auth.uid()), array['plus', 'pro', 'coach']::text[]
    ))
  );

alter policy "premium owner inserts match health summaries"
  on public.match_health_summaries
  with check (
    (select auth.uid()) = user_id
    and (select public.has_active_entitlement(
      (select auth.uid()), array['plus', 'pro', 'coach']::text[]
    ))
  );

alter policy "premium owner updates match health summaries"
  on public.match_health_summaries
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and (select public.has_active_entitlement(
      (select auth.uid()), array['plus', 'pro', 'coach']::text[]
    ))
  );

-- A newly-created coach profile must also represent a currently active Coach
-- entitlement (or an explicit admin/test override).
alter policy "coach own write" on public.coach_profiles
  to authenticated
  with check (
    (select auth.uid()) = coach_id
    and (select public.has_active_entitlement(
      (select auth.uid()), array['coach']::text[]
    ))
  );

commit;
