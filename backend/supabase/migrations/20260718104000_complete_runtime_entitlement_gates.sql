begin;

-- Keep every runtime gate on the same fail-closed expiry rule.  These two
-- SECURITY DEFINER functions predated has_active_entitlement and otherwise
-- continued accepting stale paid-plan labels after RevenueCat expiry.
create or replace function public.my_coach_link_code()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_code text;
  v_attempt int := 0;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if not public.has_active_entitlement(
    v_uid, array['coach']::text[]
  ) then
    return jsonb_build_object('ok', false, 'error', 'coach_required');
  end if;

  insert into public.coach_profiles(coach_id)
  values (v_uid)
  on conflict (coach_id) do nothing;

  select profile.athlete_link_code into v_code
  from public.coach_profiles profile
  where profile.coach_id = v_uid;
  if v_code is not null then
    return jsonb_build_object('ok', true, 'code', v_code);
  end if;

  loop
    v_attempt := v_attempt + 1;
    begin
      update public.coach_profiles
      set athlete_link_code = public._gen_group_code()
      where coach_id = v_uid
      returning athlete_link_code into v_code;
      exit;
    exception when unique_violation then
      if v_attempt >= 5 then
        return jsonb_build_object('ok', false, 'error', 'retry');
      end if;
    end;
  end loop;
  return jsonb_build_object('ok', true, 'code', v_code);
end;
$$;

create or replace function public.claim_wearable_pairing(
  p_code_hash text,
  p_provider text,
  p_token_hash text,
  p_display_name text,
  p_capabilities text[],
  p_expires_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_challenge public.wearable_pairing_challenges%rowtype;
begin
  if p_provider not in ('FITBIT_OS', 'GARMIN_CONNECT_IQ') then
    raise exception 'invalid_provider';
  end if;
  if char_length(coalesce(p_display_name, '')) > 80
     or cardinality(coalesce(p_capabilities, '{}')) > 16
     or p_expires_at > now() + interval '90 days' then
    raise exception 'invalid_pairing_payload';
  end if;

  select challenge.* into v_challenge
  from public.wearable_pairing_challenges challenge
  where challenge.code_hash = p_code_hash
    and challenge.provider = p_provider
  for update;

  if v_challenge.challenge_id is null
     or v_challenge.consumed_at is not null
     or v_challenge.expires_at <= now()
     or v_challenge.attempts >= 10 then
    raise exception 'invalid_pairing';
  end if;

  if not public.has_active_entitlement(
    v_challenge.user_id, array['plus', 'pro', 'coach']::text[]
  ) then
    raise exception 'plan_required';
  end if;

  update public.wearable_pairing_challenges
  set attempts = attempts + 1,
      consumed_at = now()
  where challenge_id = v_challenge.challenge_id;

  insert into public.wearable_device_tokens(
    user_id, provider, token_hash, display_name, capabilities, expires_at,
    last_seen_at
  ) values (
    v_challenge.user_id,
    p_provider,
    p_token_hash,
    left(trim(coalesce(p_display_name, '')), 80),
    coalesce(p_capabilities, '{}'),
    p_expires_at,
    now()
  );

  insert into public.wearable_provider_connections(
    user_id, provider, status, consented_at, updated_at
  ) values (
    v_challenge.user_id, p_provider, 'CONNECTED', now(), now()
  )
  on conflict (user_id, provider) do update set
    status = 'CONNECTED',
    consented_at = coalesce(
      public.wearable_provider_connections.consented_at,
      excluded.consented_at
    ),
    revoked_at = null,
    last_error_code = null,
    updated_at = now();

  return v_challenge.user_id;
end;
$$;

revoke all on function public.my_coach_link_code() from public, anon;
grant execute on function public.my_coach_link_code() to authenticated;

revoke all on function public.claim_wearable_pairing(
  text, text, text, text, text[], timestamptz
) from public, anon, authenticated;
grant execute on function public.claim_wearable_pairing(
  text, text, text, text, text[], timestamptz
) to service_role;

commit;
