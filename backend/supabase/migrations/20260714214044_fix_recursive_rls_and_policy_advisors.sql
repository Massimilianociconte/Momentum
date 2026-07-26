-- Remove recursive RLS reads and collapse overlapping permissive policies.
-- The helper functions expose only booleans scoped to auth.uid(); callers can
-- neither inspect another profile nor enumerate group membership.

create or replace function public._profile_privileged_fields_unchanged(
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

revoke all on function public._profile_privileged_fields_unchanged(
  uuid, text, timestamptz, boolean, text, boolean, integer, integer, integer
) from public, anon;
grant execute on function public._profile_privileged_fields_unchanged(
  uuid, text, timestamptz, boolean, text, boolean, integer, integer, integer
) to authenticated;

alter policy "own profile read" on public.profiles
  to authenticated
  using ((select auth.uid()) = user_id);

alter policy "own profile insert" on public.profiles
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and plan = 'free'
    and premium_override = false
    and account_role = 'user'
    and assistant_enabled = true
    and assistant_daily_limit = 20
    and assistant_live_limit = 5
    and reliability_score = 80
  );

alter policy "own profile write" on public.profiles
  to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and (select public._profile_privileged_fields_unchanged(
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

create or replace function public._is_friend_group_member(p_group_id uuid)
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

revoke all on function public._is_friend_group_member(uuid) from public, anon;
grant execute on function public._is_friend_group_member(uuid) to authenticated;

alter policy "groups member read" on public.friend_groups
  to authenticated
  using ((select public._is_friend_group_member(group_id)));

alter policy "group members member read" on public.friend_group_members
  to authenticated
  using ((select public._is_friend_group_member(group_id)));

drop policy if exists "assignments coach read" on public.coach_assignments;
drop policy if exists "assignments player read" on public.coach_assignments;
drop policy if exists "assignments coach update" on public.coach_assignments;
drop policy if exists "assignments player progress" on public.coach_assignments;

create policy "assignments participants read" on public.coach_assignments
  for select to authenticated
  using ((select auth.uid()) in (coach_id, player_id));

-- The existing guard trigger still restricts a player to progress, feedback,
-- and status fields, while a coach retains full update access.
create policy "assignments participants update" on public.coach_assignments
  for update to authenticated
  using ((select auth.uid()) in (coach_id, player_id))
  with check ((select auth.uid()) in (coach_id, player_id));

alter policy "assignments coach insert" on public.coach_assignments
  to authenticated;
alter policy "assignments coach delete" on public.coach_assignments
  to authenticated;

drop policy if exists "packages coach write" on public.coach_packages;

alter policy "packages public read" on public.coach_packages
  to authenticated
  using (status = 'ACTIVE' or (select auth.uid()) = coach_id);

create policy "packages coach insert" on public.coach_packages
  for insert to authenticated
  with check ((select auth.uid()) = coach_id);
create policy "packages coach update" on public.coach_packages
  for update to authenticated
  using ((select auth.uid()) = coach_id)
  with check ((select auth.uid()) = coach_id);
create policy "packages coach delete" on public.coach_packages
  for delete to authenticated
  using ((select auth.uid()) = coach_id);
