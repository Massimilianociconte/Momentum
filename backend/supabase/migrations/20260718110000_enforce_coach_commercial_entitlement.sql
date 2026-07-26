begin;

-- Policy-safe cross-account check used only to decide whether a coach can be
-- surfaced in the marketplace.  It lives outside exposed API schemas; callers
-- still need an authenticated policy evaluation to reach commercial rows.
create or replace function private.coach_marketplace_entitled(p_coach_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles profile
    where profile.user_id = p_coach_id
      and (
        profile.premium_override
        or profile.account_role in ('admin', 'super_admin')
        or (
          profile.plan = 'coach'
          and profile.plan_expires_at > now()
        )
      )
  );
$$;

revoke all on function private.coach_marketplace_entitled(uuid)
  from public, anon;
grant execute on function private.coach_marketplace_entitled(uuid)
  to authenticated, service_role;

-- Expired coaches keep read/delete access to their own data and may unpublish
-- to DRAFT/ARCHIVED. Creating, publishing, or changing an ACTIVE commercial
-- offer requires a current Coach entitlement.
alter policy "packages public read" on public.coach_packages
  to authenticated
  using (
    (select auth.uid()) = coach_id
    or (
      status = 'ACTIVE'
      and (select private.coach_marketplace_entitled(coach_id))
    )
  );

alter policy "packages coach insert" on public.coach_packages
  to authenticated
  with check (
    (select auth.uid()) = coach_id
    and (select public.has_active_entitlement(
      (select auth.uid()), array['coach']::text[]
    ))
  );

alter policy "packages coach update" on public.coach_packages
  to authenticated
  using ((select auth.uid()) = coach_id)
  with check (
    (select auth.uid()) = coach_id
    and (
      status in ('DRAFT', 'ARCHIVED')
      or (select public.has_active_entitlement(
        (select auth.uid()), array['coach']::text[]
      ))
    )
  );

alter policy "packages coach delete" on public.coach_packages
  to authenticated
  using ((select auth.uid()) = coach_id);

-- A persisted bearer code must stop working with the subscription. Blocking
-- only code generation left old codes able to create or reactivate links.
create or replace function public.join_coach(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_coach uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if char_length(v_code) <> 8 then
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;
  if (
    select count(*)
    from public.security_rate_events event
    where event.actor_id = v_uid
      and event.action = 'COACH_JOIN'
      and event.created_at > now() - interval '1 hour'
  ) >= 10 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;

  insert into public.security_rate_events(actor_id, action, target_hash)
  values (
    v_uid,
    'COACH_JOIN',
    encode(extensions.digest(v_code, 'sha256'), 'hex')
  );

  select profile.coach_id into v_coach
  from public.coach_profiles profile
  where profile.athlete_link_code = v_code;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if not private.coach_marketplace_entitled(v_coach) then
    return jsonb_build_object('ok', false, 'error', 'not_available');
  end if;
  if v_coach = v_uid then
    return jsonb_build_object('ok', false, 'error', 'self_link');
  end if;
  if exists (
    select 1
    from public.user_blocks block
    where (block.blocker_id = v_uid and block.blocked_id = v_coach)
       or (block.blocker_id = v_coach and block.blocked_id = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_available');
  end if;

  insert into public.coach_athletes(coach_id, athlete_id)
  values (v_coach, v_uid)
  on conflict (coach_id, athlete_id) do update
    set status = 'ACTIVE', ended_at = null, linked_at = now();

  return jsonb_build_object('ok', true, 'coachId', v_coach);
end;
$$;

create or replace function public.coach_public_profile(p_coach_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_coach public.coach_profiles;
  v_profile public.profiles;
  v_packages jsonb;
begin
  if (select auth.uid()) is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select coach.* into v_coach
  from public.coach_profiles coach
  where coach.coach_id = p_coach_id
    and (coach.visible = true or coach.coach_id = (select auth.uid()));
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  select profile.* into v_profile
  from public.profiles profile
  where profile.user_id = p_coach_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'packageId', package.package_id,
    'title', package.title,
    'description', package.description,
    'type', package.type,
    'priceCents', package.price_cents
  ) order by package.created_at desc), '[]'::jsonb)
  into v_packages
  from public.coach_packages package
  where package.coach_id = p_coach_id
    and package.status = 'ACTIVE'
    and private.coach_marketplace_entitled(p_coach_id);

  return jsonb_build_object(
    'ok', true,
    'coachId', v_coach.coach_id,
    'nickname', coalesce(nullif(v_profile.nickname, ''), v_profile.name),
    'name', v_profile.name,
    'avatarUrl', v_profile.avatar_url,
    'bio', v_coach.bio,
    'club', v_coach.club,
    'certifications', to_jsonb(v_coach.certifications),
    'specializations', to_jsonb(v_coach.specializations),
    'verified', v_coach.verified,
    'ratingAvg', v_coach.rating_avg,
    'ratingCount', v_coach.rating_count,
    'packages', v_packages
  );
end;
$$;

revoke all on function public.join_coach(text) from public, anon;
revoke all on function public.coach_public_profile(uuid) from public, anon;
grant execute on function public.join_coach(text) to authenticated;
grant execute on function public.coach_public_profile(uuid) to authenticated;

commit;
