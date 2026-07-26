-- A device can reconnect a few milliseconds after the second completion ACK,
-- or an older client can acknowledge before flushing its local queue. Keep a
-- bounded recovery window for events that were actually created around the
-- match, then require both participants to acknowledge the new high-water mark.

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
    and status in ('FINALIZING', 'COMPLETED');
  return null;
end;
$$;

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
        and (
          s.status in ('PENDING', 'ACTIVE', 'FINALIZING')
          or (
            s.status = 'COMPLETED'
            and s.completed_at >= now() - interval '7 days'
            and to_timestamp(duo_events.created_locally_at / 1000.0)
              <= s.completed_at + interval '15 minutes'
          )
        )
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

comment on function private.duo_reopen_on_event() is
  'Reopens a finalizing or recently completed Duo session when a permitted late event is durably appended.';
