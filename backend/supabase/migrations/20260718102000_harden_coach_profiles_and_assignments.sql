begin;

-- The athlete link code is a bearer secret, not a public coach-profile field.
-- Keep public profile reads field-limited at the SQL privilege layer so a
-- future broad SELECT cannot accidentally expose it again.
revoke all on table public.coach_profiles from public, anon, authenticated;
grant select (
  coach_id, bio, club, certifications, specializations,
  verified, rating_avg, rating_count, visible, created_at
) on public.coach_profiles to authenticated;
grant insert (
  coach_id, bio, club, certifications, specializations, visible
) on public.coach_profiles to authenticated;
grant update (
  coach_id, bio, club, certifications, specializations, visible
) on public.coach_profiles to authenticated;

alter policy "coach public read" on public.coach_profiles
  to authenticated
  using (visible = true or (select auth.uid()) = coach_id);

alter policy "coach own update" on public.coach_profiles
  to authenticated
  using ((select auth.uid()) = coach_id)
  with check ((select auth.uid()) = coach_id);

alter policy "coach own write" on public.coach_profiles
  to authenticated
  with check (
    (select auth.uid()) = coach_id
    and verified = false
    and rating_avg = 0
    and rating_count = 0
    and athlete_link_code is null
    and (select public.has_active_entitlement(
      (select auth.uid()), array['coach']::text[]
    ))
  );

-- Manual coach assignments must pass through one server-side transaction. The
-- previous RLS subquery referenced coach_athletes after all client privileges
-- on that table had been revoked, which made every direct app INSERT fail. Its
-- purchase branch also accepted an unrelated purchase UUID.
drop policy if exists "assignments coach insert" on public.coach_assignments;
revoke insert on public.coach_assignments from public, anon, authenticated;

create or replace function public.assign_coach_training(
  p_player_id uuid,
  p_training_plan jsonb,
  p_purchase_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_coach_id uuid := (select auth.uid());
  v_assignment_id uuid;
begin
  if v_coach_id is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if not public.has_active_entitlement(
    v_coach_id, array['coach']::text[]
  ) then
    return jsonb_build_object('ok', false, 'error', 'coach_required');
  end if;
  if p_player_id is null or p_player_id = v_coach_id
     or not exists (
       select 1 from public.profiles where user_id = p_player_id
     ) then
    return jsonb_build_object('ok', false, 'error', 'athlete_not_available');
  end if;
  if p_training_plan is null
     or jsonb_typeof(p_training_plan) <> 'object'
     or pg_column_size(p_training_plan) > 65536 then
    return jsonb_build_object('ok', false, 'error', 'invalid_training_plan');
  end if;

  if p_purchase_id is not null then
    if not exists (
      select 1
      from public.coach_purchases purchase
      where purchase.purchase_id = p_purchase_id
        and purchase.coach_id = v_coach_id
        and purchase.player_id = p_player_id
        and purchase.status = 'PAID'
    ) then
      return jsonb_build_object('ok', false, 'error', 'purchase_not_valid');
    end if;
  elsif not exists (
    select 1
    from public.coach_athletes link
    where link.coach_id = v_coach_id
      and link.athlete_id = p_player_id
      and link.status = 'ACTIVE'
  ) then
    return jsonb_build_object('ok', false, 'error', 'athlete_not_linked');
  end if;

  insert into public.coach_profiles(coach_id)
  values (v_coach_id)
  on conflict (coach_id) do nothing;

  insert into public.coach_assignments(
    purchase_id, coach_id, player_id, training_plan, status
  ) values (
    p_purchase_id, v_coach_id, p_player_id, p_training_plan, 'ASSIGNED'
  ) returning assignment_id into v_assignment_id;

  return jsonb_build_object(
    'ok', true,
    'assignmentId', v_assignment_id
  );
end;
$$;

revoke all on function public.assign_coach_training(uuid, jsonb, uuid)
  from public, anon;
grant execute on function public.assign_coach_training(uuid, jsonb, uuid)
  to authenticated;

commit;
