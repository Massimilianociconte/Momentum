-- Duo completion must not close the append-only timeline while the other
-- participant still has offline events. Both clients acknowledge the same
-- server high-water mark before the session becomes immutable.

alter table public.duo_sessions
  drop constraint if exists duo_sessions_status_check;
alter table public.duo_sessions
  add constraint duo_sessions_status_check
  check (status in ('PENDING', 'ACTIVE', 'FINALIZING', 'COMPLETED', 'CANCELLED'));

alter table public.duo_sessions
  add column if not exists creator_ack_seq bigint not null default 0,
  add column if not exists guest_ack_seq bigint not null default 0,
  add column if not exists creator_finished boolean not null default false,
  add column if not exists guest_finished boolean not null default false,
  add column if not exists finalization_started_at timestamptz,
  add column if not exists completed_at timestamptz;

comment on column public.duo_sessions.creator_ack_seq is
  'Highest authoritative Duo event sequence replayed by the creator.';
comment on column public.duo_sessions.guest_ack_seq is
  'Highest authoritative Duo event sequence replayed by the guest.';

create or replace function private.duo_prepare_event()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_created_at timestamptz;
  v_event_at timestamptz;
begin
  if new.created_locally_at is null then
    new.created_locally_at := new.ts_ms;
  end if;
  v_event_at := to_timestamp(new.created_locally_at / 1000.0);
  select created_at into v_created_at
  from public.duo_sessions
  where session_id = new.session_id;
  if v_created_at is null
     or v_event_at < v_created_at - interval '15 minutes'
     or v_event_at > now() + interval '15 minutes' then
    raise exception 'event_time_out_of_bounds' using errcode = '22023';
  end if;
  return new;
end;
$$;

drop trigger if exists duo_prepare_event_trigger on public.duo_events;
create trigger duo_prepare_event_trigger
  before insert on public.duo_events
  for each row execute function private.duo_prepare_event();

update public.duo_events
set created_locally_at = ts_ms
where created_locally_at is null;
alter table public.duo_events
  alter column created_locally_at set not null;

create index if not exists duo_events_match_logical_order
  on public.duo_events(match_id, created_locally_at, seq);

create or replace function private.duo_reopen_on_event()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  update public.duo_sessions
  set status = case when guest_id is null then 'PENDING' else 'ACTIVE' end,
      creator_finished = false,
      guest_finished = false,
      finalization_started_at = null,
      completed_at = null,
      updated_at = now()
  where session_id = new.session_id
    and status = 'FINALIZING';
  return null;
end;
$$;

drop trigger if exists duo_reopen_on_event_trigger on public.duo_events;
create trigger duo_reopen_on_event_trigger
  after insert on public.duo_events
  for each row execute function private.duo_reopen_on_event();

create or replace function public.duo_ack_state(
  p_session_id uuid,
  p_seen_seq bigint,
  p_completed boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_session public.duo_sessions;
  v_max_seq bigint;
  v_ready boolean;
  v_status text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;

  select * into v_session
  from public.duo_sessions
  where session_id = p_session_id
  for update;
  if not found or (
    v_uid <> v_session.creator_id
    and v_uid is distinct from v_session.guest_id
  ) then
    return jsonb_build_object('ok', false, 'error', 'session_not_available');
  end if;
  if v_session.status = 'CANCELLED' then
    return jsonb_build_object('ok', false, 'error', 'session_closed');
  end if;

  select coalesce(max(seq), 0) into v_max_seq
  from public.duo_events
  where session_id = p_session_id;
  if p_seen_seq < 0 or p_seen_seq > v_max_seq then
    return jsonb_build_object(
      'ok', false,
      'error', 'invalid_cursor',
      'maxSeq', v_max_seq
    );
  end if;

  if v_session.status = 'COMPLETED' then
    return jsonb_build_object(
      'ok', true,
      'status', 'COMPLETED',
      'maxSeq', v_max_seq
    );
  end if;

  if v_uid = v_session.creator_id then
    update public.duo_sessions
    set creator_ack_seq = greatest(creator_ack_seq, p_seen_seq),
        creator_finished = p_completed and p_seen_seq = v_max_seq
    where session_id = p_session_id;
  else
    update public.duo_sessions
    set guest_ack_seq = greatest(guest_ack_seq, p_seen_seq),
        guest_finished = p_completed and p_seen_seq = v_max_seq
    where session_id = p_session_id;
  end if;

  select * into v_session
  from public.duo_sessions
  where session_id = p_session_id;
  v_ready := v_session.creator_finished
    and v_session.creator_ack_seq >= v_max_seq
    and (
      v_session.guest_id is null
      or (
        v_session.guest_finished
        and v_session.guest_ack_seq >= v_max_seq
      )
    );
  v_status := case
    when v_ready then 'COMPLETED'
    when v_session.creator_finished or v_session.guest_finished
      then 'FINALIZING'
    when v_session.guest_id is null then 'PENDING'
    else 'ACTIVE'
  end;

  update public.duo_sessions
  set status = v_status,
      finalization_started_at = case
        when v_status = 'FINALIZING'
          then coalesce(finalization_started_at, now())
        else null
      end,
      completed_at = case when v_status = 'COMPLETED' then now() else null end,
      updated_at = now()
  where session_id = p_session_id;

  return jsonb_build_object(
    'ok', true,
    'status', v_status,
    'maxSeq', v_max_seq,
    'allEventsSeen', p_seen_seq = v_max_seq
  );
end;
$$;

revoke all on function public.duo_ack_state(uuid, bigint, boolean)
  from public, anon;
grant execute on function public.duo_ack_state(uuid, bigint, boolean)
  to authenticated;

-- Backward-compatible endpoint for older clients. A completion request is an
-- acknowledgement, not unilateral permission to close a two-party timeline.
create or replace function public.duo_set_session_status(
  p_session_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_session public.duo_sessions;
  v_max_seq bigint;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select * into v_session from public.duo_sessions
  where session_id = p_session_id for update;
  if not found or (
    v_uid <> v_session.creator_id
    and v_uid is distinct from v_session.guest_id
  ) then
    return jsonb_build_object('ok', false, 'error', 'session_not_available');
  end if;
  if p_status = 'CANCELLED'
     and v_session.status = 'PENDING'
     and v_session.creator_id = v_uid
     and v_session.guest_id is null then
    update public.duo_sessions
    set status = 'CANCELLED', updated_at = now()
    where session_id = p_session_id;
    return jsonb_build_object('ok', true, 'status', 'CANCELLED');
  end if;
  if p_status = 'COMPLETED' then
    select coalesce(max(seq), 0) into v_max_seq
    from public.duo_events where session_id = p_session_id;
    return public.duo_ack_state(p_session_id, v_max_seq, true);
  end if;
  if p_status = v_session.status then
    return jsonb_build_object('ok', true, 'status', p_status);
  end if;
  return jsonb_build_object('ok', false, 'error', 'invalid_transition');
end;
$$;

revoke all on function public.duo_set_session_status(uuid, text)
  from public, anon;
grant execute on function public.duo_set_session_status(uuid, text)
  to authenticated;

drop policy if exists "duo events insert own team" on public.duo_events;
create policy "duo events insert own team" on public.duo_events
  for insert to authenticated with check (
    (select auth.uid()) = source_user_id
    and source_team_id = public.duo_team_of(session_id, (select auth.uid()))
    and exists (
      select 1 from public.duo_sessions s
      where s.session_id = duo_events.session_id
        and s.match_id = duo_events.match_id
        and (select auth.uid()) in (s.creator_id, s.guest_id)
        and s.status in ('PENDING', 'ACTIVE', 'FINALIZING')
    )
    and (
      (type = 'POINT_TEAM_A' and team_id = 'TEAM_A'
        and public.duo_team_of(session_id, (select auth.uid())) = 'TEAM_A')
      or (type = 'POINT_TEAM_B' and team_id = 'TEAM_B'
        and public.duo_team_of(session_id, (select auth.uid())) = 'TEAM_B')
      or (type = 'UNDO'
        and team_id = public.duo_team_of(session_id, (select auth.uid())))
      or type in (
        'MATCH_STARTED', 'MATCH_PAUSED', 'MATCH_RESUMED', 'MATCH_COMPLETED',
        'DEVICE_JOINED_MATCH', 'DEVICE_LEFT_MATCH', 'TEAM_CONFIRMED'
      )
    )
  );

comment on function public.duo_ack_state(uuid, bigint, boolean) is
  'Two-phase Duo acknowledgement. COMPLETED is reached only after every participant replays the same server high-water mark.';
