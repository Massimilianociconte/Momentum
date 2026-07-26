-- Restore the authenticated grant required by the Duo event RLS policy and
-- make acknowledgement inputs null-safe.
--
-- duo_team_of() is not a free-form privileged lookup: its body only returns a
-- team when uid = auth.uid() (or for service_role). PostgreSQL evaluates the
-- duo_events policy as the calling authenticated role, so that role needs
-- EXECUTE even though mobile clients do not call the helper directly.

begin;

revoke all on function public.duo_team_of(uuid, uuid) from public, anon;
grant execute on function public.duo_team_of(uuid, uuid) to authenticated;

comment on function public.duo_team_of(uuid, uuid) is
  'Authenticated RLS helper. EXECUTE is required by duo_events policies; the '
  'body only resolves auth.uid()''s own team (service_role may resolve any).';

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
  if p_seen_seq is null
     or p_seen_seq < 0
     or p_seen_seq > v_max_seq then
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
        creator_finished =
          coalesce(p_completed, false) and p_seen_seq = v_max_seq
    where session_id = p_session_id;
  else
    update public.duo_sessions
    set guest_ack_seq = greatest(guest_ack_seq, p_seen_seq),
        guest_finished =
          coalesce(p_completed, false) and p_seen_seq = v_max_seq
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

commit;
