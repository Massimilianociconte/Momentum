-- On re-pair, revoke prior device tokens for the same user+provider so lost
-- watches cannot keep ingesting and START_MATCH targets a single active token.
begin;

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

  -- Single active token policy: re-pair invalidates previous devices.
  update public.wearable_device_tokens
  set revoked_at = now()
  where user_id = v_challenge.user_id
    and provider = p_provider
    and revoked_at is null
    and token_hash is distinct from p_token_hash;

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

revoke all on function public.claim_wearable_pairing(
  text, text, text, text, text[], timestamptz
) from public, anon, authenticated;
grant execute on function public.claim_wearable_pairing(
  text, text, text, text, text[], timestamptz
) to service_role;

commit;
