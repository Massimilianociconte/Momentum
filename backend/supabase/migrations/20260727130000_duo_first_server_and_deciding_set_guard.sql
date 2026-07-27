-- Duo Mode: carry the serving rotation and fail closed on format schema v3.
--
-- 1. duo_sessions gains first_server. Serve, return, break and hold statistics
--    are derived from the serving rotation, so the two phones must replay the
--    shared journal with the same first server: without it the guest always
--    assumed TEAM_A and attributed every hold and break to the wrong pair.
--    duo_create_session takes it as an optional argument and duo_join_session
--    returns it, so a client that does not send it keeps the previous default.
--
-- 2. The Star Point Duo guard is extended to the deciding set played without
--    tie-break (MatchFormat.tieBreakInDecidingSet, format schema v3). A peer on
--    an older build ignores the field and would open a tie-break at 6-6, so the
--    session is refused server-side exactly like Star Point.
begin;

alter table public.duo_sessions
  add column if not exists first_server text not null default 'TEAM_A';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.duo_sessions'::regclass
      and conname = 'duo_sessions_first_server_check'
  ) then
    alter table public.duo_sessions
      add constraint duo_sessions_first_server_check
      check (first_server in ('TEAM_A', 'TEAM_B'));
  end if;
end;
$$;

comment on column public.duo_sessions.first_server is
  'Coppia al servizio nel primo game (FIP Regola 4). Entrambi i device devono '
  'rigiocare il journal condiviso con lo stesso valore.';

-- ------------------------------------------------------------------- guard

create or replace function public.reject_unnegotiated_star_point_duo()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Star Point: schema v2, un peer vecchio leggerebbe goldenPoint=false come
  -- ADVANTAGE.
  if upper(coalesce(new.format_json ->> 'gameScoringMode', '')) = 'STAR_POINT'
  then
    raise exception using
      errcode = 'P0001',
      message = 'client_update_required';
  end if;
  -- Set decisivo senza tie-break: schema v3, un peer vecchio ignora il campo e
  -- aprirebbe il tie-break sul 6-6.
  if coalesce((new.format_json ->> 'tieBreakAtGamesAll')::boolean, true)
     and not coalesce(
       (new.format_json ->> 'tieBreakInDecidingSet')::boolean,
       true
     )
  then
    raise exception using
      errcode = 'P0001',
      message = 'client_update_required';
  end if;
  return new;
end;
$$;

revoke all on function public.reject_unnegotiated_star_point_duo() from public;
revoke all on function public.reject_unnegotiated_star_point_duo() from anon;
revoke all on function public.reject_unnegotiated_star_point_duo()
  from authenticated;

-- ------------------------------------------------------- duo_create_session

-- The extra defaulted argument changes the signature: the 3-argument function
-- must go, otherwise a 3-argument call becomes ambiguous.
drop function if exists public.duo_create_session(text, jsonb, text);

create or replace function public.duo_create_session(
  p_match_id text,
  p_format jsonb,
  p_team text default 'TEAM_A',
  p_first_server text default 'TEAM_A'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_code text;
  v_sid uuid;
  v_existing public.duo_sessions;
  v_attempt int := 0;
  v_rate_id bigint;
  v_first_server text := coalesce(p_first_server, 'TEAM_A');
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if not public.has_duo_access(v_uid) then
    return jsonb_build_object('ok', false, 'error', 'premium_required');
  end if;
  if p_team not in ('TEAM_A', 'TEAM_B')
     or v_first_server not in ('TEAM_A', 'TEAM_B')
     or char_length(trim(coalesce(p_match_id, ''))) not between 8 and 128
     or jsonb_typeof(coalesce(p_format, '{}'::jsonb)) <> 'object'
     or octet_length(coalesce(p_format, '{}'::jsonb)::text) > 8192 then
    return jsonb_build_object('ok', false, 'error', 'invalid_session');
  end if;

  select * into v_existing from public.duo_sessions
  where match_id = trim(p_match_id) limit 1;
  if found then
    if v_existing.creator_id <> v_uid then
      return jsonb_build_object('ok', false, 'error', 'match_not_available');
    end if;
    return jsonb_build_object(
      'ok', true,
      'sessionId', v_existing.session_id,
      'matchId', v_existing.match_id,
      'joinCode', v_existing.join_code,
      'myTeam', v_existing.creator_team,
      'firstServer', v_existing.first_server,
      'status', v_existing.status
    );
  end if;

  if (
    select count(*) from public.security_rate_events e
    where e.actor_id = v_uid and e.action = 'DUO_CREATE'
      and e.created_at > now() - interval '1 hour'
  ) >= 10 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  insert into public.security_rate_events(actor_id, action)
  values (v_uid, 'DUO_CREATE') returning event_id into v_rate_id;

  loop
    v_attempt := v_attempt + 1;
    v_code := upper(substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 8));
    begin
      insert into public.duo_sessions(
        match_id, format_json, join_code, creator_id, creator_team, first_server
      ) values (
        trim(p_match_id), coalesce(p_format, '{}'::jsonb), v_code, v_uid,
        p_team, v_first_server
      ) returning session_id into v_sid;
      exit;
    exception when unique_violation then
      if v_attempt >= 5 then raise; end if;
    end;
  end loop;
  update public.security_rate_events set success = true where event_id = v_rate_id;
  return jsonb_build_object(
    'ok', true,
    'sessionId', v_sid,
    'matchId', trim(p_match_id),
    'joinCode', v_code,
    'myTeam', p_team,
    'firstServer', v_first_server,
    'status', 'PENDING'
  );
end;
$$;

revoke all on function public.duo_create_session(text, jsonb, text, text)
  from public;
revoke all on function public.duo_create_session(text, jsonb, text, text)
  from anon;
grant execute on function public.duo_create_session(text, jsonb, text, text)
  to authenticated;

-- --------------------------------------------------------- duo_join_session

create or replace function public.duo_join_session(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_session public.duo_sessions;
  v_my_team text;
  v_rate_id bigint;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if not public.has_duo_access(v_uid) then
    return jsonb_build_object('ok', false, 'error', 'premium_required');
  end if;
  if char_length(trim(coalesce(p_code, ''))) not between 6 and 16 then
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;
  if (
    select count(*) from public.security_rate_events e
    where e.actor_id = v_uid and e.action = 'DUO_JOIN'
      and e.created_at > now() - interval '10 minutes'
  ) >= 10 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  insert into public.security_rate_events(actor_id, action, target_hash)
  values (
    v_uid,
    'DUO_JOIN',
    encode(extensions.digest(upper(trim(p_code)), 'sha256'), 'hex')
  ) returning event_id into v_rate_id;

  select * into v_session from public.duo_sessions
  where join_code = upper(trim(p_code)) for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;
  if v_session.status not in ('PENDING', 'ACTIVE') then
    return jsonb_build_object('ok', false, 'error', 'session_closed');
  end if;
  if v_session.code_expires_at <= now() then
    return jsonb_build_object('ok', false, 'error', 'code_expired');
  end if;
  if v_session.creator_id = v_uid then
    update public.security_rate_events set success = true where event_id = v_rate_id;
    return jsonb_build_object(
      'ok', true,
      'sessionId', v_session.session_id,
      'matchId', v_session.match_id,
      'format', v_session.format_json,
      'myTeam', v_session.creator_team,
      'firstServer', v_session.first_server,
      'status', v_session.status
    );
  end if;
  if v_session.guest_id is not null and v_session.guest_id <> v_uid then
    return jsonb_build_object('ok', false, 'error', 'session_full');
  end if;

  v_my_team := case v_session.creator_team
    when 'TEAM_A' then 'TEAM_B' else 'TEAM_A' end;
  update public.duo_sessions
  set guest_id = v_uid,
      guest_team = v_my_team,
      status = 'ACTIVE',
      updated_at = now()
  where session_id = v_session.session_id;
  update public.security_rate_events set success = true where event_id = v_rate_id;
  return jsonb_build_object(
    'ok', true,
    'sessionId', v_session.session_id,
    'matchId', v_session.match_id,
    'format', v_session.format_json,
    'myTeam', v_my_team,
    'firstServer', v_session.first_server,
    'status', 'ACTIVE'
  );
end;
$$;

revoke all on function public.duo_join_session(text) from public;
revoke all on function public.duo_join_session(text) from anon;
grant execute on function public.duo_join_session(text) to authenticated;

commit;
