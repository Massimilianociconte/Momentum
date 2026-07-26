-- Reconcile grants that may survive on long-lived projects and keep policy
-- helpers outside schemas exposed through PostgREST/GraphQL.

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated, service_role;

create or replace function private.profile_privileged_fields_unchanged(
  p_user_id uuid,
  p_plan text,
  p_plan_expires_at timestamptz,
  p_premium_override boolean,
  p_account_role text,
  p_assistant_enabled boolean,
  p_assistant_daily_limit integer,
  p_assistant_live_limit integer,
  p_reliability_score integer
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles current_profile
    where current_profile.user_id = (select auth.uid())
      and current_profile.user_id = p_user_id
      and current_profile.plan is not distinct from p_plan
      and current_profile.plan_expires_at is not distinct from p_plan_expires_at
      and current_profile.premium_override is not distinct from p_premium_override
      and current_profile.account_role is not distinct from p_account_role
      and current_profile.assistant_enabled is not distinct from p_assistant_enabled
      and current_profile.assistant_daily_limit is not distinct from p_assistant_daily_limit
      and current_profile.assistant_live_limit is not distinct from p_assistant_live_limit
      and current_profile.reliability_score is not distinct from p_reliability_score
  );
$$;

revoke all on function private.profile_privileged_fields_unchanged(
  uuid, text, timestamptz, boolean, text, boolean, integer, integer, integer
) from public, anon;
grant execute on function private.profile_privileged_fields_unchanged(
  uuid, text, timestamptz, boolean, text, boolean, integer, integer, integer
) to authenticated;

create or replace function private.is_friend_group_member(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null and exists (
    select 1
    from public.friend_group_members member
    where member.group_id = p_group_id
      and member.user_id = (select auth.uid())
  );
$$;

revoke all on function private.is_friend_group_member(uuid) from public, anon;
grant execute on function private.is_friend_group_member(uuid) to authenticated;

alter policy "own profile write" on public.profiles
  to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and (select private.profile_privileged_fields_unchanged(
      user_id,
      plan,
      plan_expires_at,
      premium_override,
      account_role,
      assistant_enabled,
      assistant_daily_limit,
      assistant_live_limit,
      reliability_score
    ))
  );

alter policy "groups member read" on public.friend_groups
  to authenticated
  using ((select private.is_friend_group_member(group_id)));

alter policy "group members member read" on public.friend_group_members
  to authenticated
  using ((select private.is_friend_group_member(group_id)));

drop function public._profile_privileged_fields_unchanged(
  uuid, text, timestamptz, boolean, text, boolean, integer, integer, integer
);
drop function public._is_friend_group_member(uuid);

-- These functions were introduced after the general grant reconciliation.
-- Revoke role-specific grants as well as PUBLIC so upgraded projects converge
-- with clean installs.
revoke all on function public.consume_health_oauth_state(text, text)
  from public, anon, authenticated;
grant execute on function public.consume_health_oauth_state(text, text)
  to service_role;

revoke all on function public.delete_my_health_provider_data(text)
  from public, anon, authenticated;
grant execute on function public.delete_my_health_provider_data(text)
  to authenticated, service_role;
