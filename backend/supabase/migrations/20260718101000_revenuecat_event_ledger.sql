begin;

create table private.revenuecat_webhook_events (
  event_id text primary key,
  event_type text not null,
  event_timestamp_ms bigint not null,
  outcome text not null,
  user_ids uuid[] not null default '{}'::uuid[],
  received_at timestamptz not null default now(),
  processed_at timestamptz not null default now(),
  check (char_length(event_id) between 1 and 128),
  check (char_length(event_type) between 1 and 64),
  check (event_timestamp_ms > 0),
  check (char_length(outcome) between 1 and 64)
);

create table private.revenuecat_subscription_state (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  last_event_id text not null,
  last_event_timestamp_ms bigint not null,
  last_event_priority smallint not null,
  updated_at timestamptz not null default now(),
  check (last_event_timestamp_ms >= 0),
  check (last_event_priority between 0 and 100)
);

revoke all on table
  private.revenuecat_webhook_events,
  private.revenuecat_subscription_state
from public, anon, authenticated;

create or replace function private.revenuecat_event_priority(p_event_type text)
returns smallint
language sql
immutable
set search_path = ''
as $$
  select case upper(coalesce(p_event_type, ''))
    when 'EXPIRATION' then 100
    when 'TRANSFER' then 90
    when 'CANCELLATION' then 70
    when 'BILLING_ISSUE' then 70
    when 'SUBSCRIPTION_PAUSED' then 70
    else 50
  end::smallint;
$$;

revoke all on function private.revenuecat_event_priority(text)
  from public, anon, authenticated;

create or replace function public.apply_revenuecat_plan_event(
  p_event_id text,
  p_event_type text,
  p_event_timestamp_ms bigint,
  p_user_id uuid,
  p_plan text,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_priority smallint;
  v_last_timestamp bigint;
  v_last_priority smallint;
begin
  if (select auth.role()) <> 'service_role' then
    raise sqlstate '42501' using message = 'service role required';
  end if;
  if p_user_id is null
     or char_length(coalesce(p_event_id, '')) not between 1 and 128
     or char_length(coalesce(p_event_type, '')) not between 1 and 64
     or coalesce(p_event_timestamp_ms, 0) <= 0
     or p_plan not in ('free', 'plus', 'pro', 'coach') then
    raise sqlstate '22023' using message = 'invalid RevenueCat event';
  end if;

  v_priority := private.revenuecat_event_priority(p_event_type);
  insert into private.revenuecat_webhook_events(
    event_id, event_type, event_timestamp_ms, outcome, user_ids
  ) values (
    p_event_id, upper(p_event_type), p_event_timestamp_ms, 'RECEIVED',
    array[p_user_id]
  ) on conflict (event_id) do nothing;
  if not found then
    return jsonb_build_object('applied', false, 'reason', 'duplicate_event');
  end if;

  if not exists (
    select 1 from public.profiles where user_id = p_user_id
  ) then
    raise sqlstate 'P0002' using message = 'RevenueCat profile not found';
  end if;

  insert into private.revenuecat_subscription_state(
    user_id, last_event_id, last_event_timestamp_ms, last_event_priority
  ) values (p_user_id, '', 0, 0)
  on conflict (user_id) do nothing;

  select state.last_event_timestamp_ms, state.last_event_priority
    into v_last_timestamp, v_last_priority
  from private.revenuecat_subscription_state state
  where state.user_id = p_user_id
  for update;

  if p_event_timestamp_ms < v_last_timestamp
     or (
       p_event_timestamp_ms = v_last_timestamp
       and v_priority <= v_last_priority
     ) then
    update private.revenuecat_webhook_events
       set outcome = 'IGNORED_STALE', processed_at = now()
     where event_id = p_event_id;
    return jsonb_build_object('applied', false, 'reason', 'stale_event');
  end if;

  update public.profiles
     set plan = p_plan,
         plan_expires_at = p_expires_at
   where user_id = p_user_id;

  update private.revenuecat_subscription_state
     set last_event_id = p_event_id,
         last_event_timestamp_ms = p_event_timestamp_ms,
         last_event_priority = v_priority,
         updated_at = now()
   where user_id = p_user_id;

  update private.revenuecat_webhook_events
     set outcome = 'APPLIED', processed_at = now()
   where event_id = p_event_id;

  return jsonb_build_object('applied', true, 'plan', p_plan);
end;
$$;

create or replace function public.apply_revenuecat_transfer_event(
  p_event_id text,
  p_event_timestamp_ms bigint,
  p_from_user_ids uuid[],
  p_target_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_priority constant smallint := 90;
  v_last_timestamp bigint;
  v_last_priority smallint;
  v_plan text;
  v_expires_at timestamptz;
  v_from_ids uuid[];
begin
  if (select auth.role()) <> 'service_role' then
    raise sqlstate '42501' using message = 'service role required';
  end if;
  if p_target_user_id is null
     or char_length(coalesce(p_event_id, '')) not between 1 and 128
     or coalesce(p_event_timestamp_ms, 0) <= 0 then
    raise sqlstate '22023' using message = 'invalid RevenueCat transfer';
  end if;

  select coalesce(array_agg(distinct source_id), '{}'::uuid[])
    into v_from_ids
  from unnest(coalesce(p_from_user_ids, '{}'::uuid[])) source_id
  where source_id is not null and source_id <> p_target_user_id;

  if cardinality(v_from_ids) = 0 then
    raise sqlstate '22023' using message = 'RevenueCat transfer source missing';
  end if;

  insert into private.revenuecat_webhook_events(
    event_id, event_type, event_timestamp_ms, outcome, user_ids
  ) values (
    p_event_id, 'TRANSFER', p_event_timestamp_ms, 'RECEIVED',
    v_from_ids || p_target_user_id
  ) on conflict (event_id) do nothing;
  if not found then
    return jsonb_build_object('applied', false, 'reason', 'duplicate_event');
  end if;

  if not exists (
    select 1 from public.profiles where user_id = p_target_user_id
  ) then
    raise sqlstate 'P0002' using message = 'RevenueCat target profile not found';
  end if;
  if not exists (
    select 1 from public.profiles where user_id = any(v_from_ids)
  ) then
    raise sqlstate 'P0002' using message = 'RevenueCat source profile not found';
  end if;

  insert into private.revenuecat_subscription_state(
    user_id, last_event_id, last_event_timestamp_ms, last_event_priority
  ) values (p_target_user_id, '', 0, 0)
  on conflict (user_id) do nothing;

  select state.last_event_timestamp_ms, state.last_event_priority
    into v_last_timestamp, v_last_priority
  from private.revenuecat_subscription_state state
  where state.user_id = p_target_user_id
  for update;

  if p_event_timestamp_ms < v_last_timestamp
     or (
       p_event_timestamp_ms = v_last_timestamp
       and v_priority <= v_last_priority
     ) then
    update private.revenuecat_webhook_events
       set outcome = 'IGNORED_STALE', processed_at = now()
     where event_id = p_event_id;
    return jsonb_build_object('applied', false, 'reason', 'stale_event');
  end if;

  -- If a source account already received a logically newer lifecycle event,
  -- applying this older transfer would copy access to the target while the
  -- newer source state correctly prevents revocation. Ignore the whole event
  -- instead of briefly or permanently granting both accounts.
  if exists (
    select 1
    from private.revenuecat_subscription_state source_state
    where source_state.user_id = any(v_from_ids)
      and (
        source_state.last_event_timestamp_ms > p_event_timestamp_ms
        or (
          source_state.last_event_timestamp_ms = p_event_timestamp_ms
          and source_state.last_event_priority > v_priority
        )
      )
  ) then
    update private.revenuecat_webhook_events
       set outcome = 'IGNORED_STALE_SOURCE', processed_at = now()
     where event_id = p_event_id;
    return jsonb_build_object(
      'applied', false, 'reason', 'stale_source_event'
    );
  end if;

  -- Preserve the strongest currently active entitlement across both customer
  -- records. The subscription-only catalog deliberately ignores NULL/past
  -- expiries. The transfer then revokes every known source UUID atomically.
  select candidate.plan, candidate.plan_expires_at
    into v_plan, v_expires_at
  from public.profiles candidate
  where candidate.user_id = any(v_from_ids || p_target_user_id)
    and candidate.plan in ('plus', 'pro', 'coach')
    and candidate.plan_expires_at > now()
  order by
    case candidate.plan when 'coach' then 3 when 'pro' then 2 else 1 end desc,
    candidate.plan_expires_at desc
  limit 1
  for update;

  if v_plan is null then
    v_plan := 'free';
    v_expires_at := null;
  end if;

  update public.profiles source
     set plan = 'free', plan_expires_at = null
   where source.user_id = any(v_from_ids)
     and not exists (
       select 1
       from private.revenuecat_subscription_state newer
       where newer.user_id = source.user_id
         and (
           newer.last_event_timestamp_ms > p_event_timestamp_ms
           or (
             newer.last_event_timestamp_ms = p_event_timestamp_ms
             and newer.last_event_priority > v_priority
           )
         )
     );

  update public.profiles
     set plan = v_plan, plan_expires_at = v_expires_at
   where user_id = p_target_user_id;

  insert into private.revenuecat_subscription_state(
    user_id, last_event_id, last_event_timestamp_ms, last_event_priority, updated_at
  )
  select source_id, p_event_id, p_event_timestamp_ms, v_priority, now()
  from unnest(v_from_ids || p_target_user_id) source_id
  on conflict (user_id) do update
    set last_event_id = excluded.last_event_id,
        last_event_timestamp_ms = excluded.last_event_timestamp_ms,
        last_event_priority = excluded.last_event_priority,
        updated_at = excluded.updated_at
  where private.revenuecat_subscription_state.last_event_timestamp_ms
          < excluded.last_event_timestamp_ms
     or (
       private.revenuecat_subscription_state.last_event_timestamp_ms
         = excluded.last_event_timestamp_ms
       and private.revenuecat_subscription_state.last_event_priority
         <= excluded.last_event_priority
     );

  update private.revenuecat_webhook_events
     set outcome = 'APPLIED_TRANSFER', processed_at = now()
   where event_id = p_event_id;

  return jsonb_build_object(
    'applied', true,
    'plan', v_plan,
    'targetUserId', p_target_user_id,
    'revokedSources', cardinality(v_from_ids)
  );
end;
$$;

revoke all on function public.apply_revenuecat_plan_event(
  text, text, bigint, uuid, text, timestamptz
) from public, anon, authenticated;
revoke all on function public.apply_revenuecat_transfer_event(
  text, bigint, uuid[], uuid
) from public, anon, authenticated;
grant execute on function public.apply_revenuecat_plan_event(
  text, text, bigint, uuid, text, timestamptz
) to service_role;
grant execute on function public.apply_revenuecat_transfer_event(
  text, bigint, uuid[], uuid
) to service_role;

commit;
