-- RallyMate Duo Mode (premium): due team connessi segnano la stessa partita
-- da due smartwatch, uno per team.
--
-- Filosofia costi: niente realtime obbligatorio. Il telefono di ogni team
-- fa push degli eventi del proprio team e pull (polling leggero) di quelli
-- dell'altro. La timeline ufficiale è l'ordine di arrivo sul server (seq).
-- Tutto il resto (scoring, offline, undo) resta locale e event-sourced.

-- ==================================================== premium override
-- Sblocco premium per tester/admin SENZA acquisto reale (Duo Mode §11).
-- Scritto solo da service role / SQL admin, mai dal client.
alter table public.profiles
  add column if not exists premium_override boolean not null default false;

comment on column public.profiles.premium_override is
  'Test user: sblocca le feature premium senza abbonamento reale. '
  'Solo service role. I client lo mostrano come override, non come piano.';

-- Il client non può auto-assegnarsi piano né override: ricrea la policy di
-- update del profilo pinnando TUTTI i campi privilegiati al valore corrente
-- (inclusi quelli già protetti dalla 0005: account_role e limiti assistant —
-- il drop/create qui sostituisce quella policy, quindi vanno ripetuti).
drop policy if exists "own profile write" on public.profiles;
create policy "own profile write" on public.profiles
  for update using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and plan = (select p.plan from public.profiles p where p.user_id = auth.uid())
    and premium_override = (
      select p.premium_override from public.profiles p where p.user_id = auth.uid()
    )
    and account_role = (
      select p.account_role from public.profiles p where p.user_id = auth.uid()
    )
    and assistant_enabled = (
      select p.assistant_enabled from public.profiles p
      where p.user_id = auth.uid()
    )
    and assistant_daily_limit = (
      select p.assistant_daily_limit from public.profiles p
      where p.user_id = auth.uid()
    )
    and assistant_live_limit = (
      select p.assistant_live_limit from public.profiles p
      where p.user_id = auth.uid()
    )
  );

-- Accesso Duo: piano premium attivo, override test o ruolo admin.
create or replace function public.has_duo_access(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.user_id = uid
      and (
        p.plan in ('plus', 'pro', 'coach')
        or p.premium_override
        or p.account_role in ('admin', 'super_admin')
      )
  );
$$;

-- ==================================================== duo_sessions
-- Una sessione = una partita condivisa tra due team. Il collegamento
-- avviene con un codice partita temporaneo (MVP: niente grafo amicizie).
create table public.duo_sessions (
  session_id   uuid primary key default gen_random_uuid(),
  match_id     text not null unique,
  format_json  jsonb not null default '{}',
  join_code    text not null unique,
  status       text not null default 'PENDING'
    check (status in ('PENDING', 'ACTIVE', 'COMPLETED', 'CANCELLED')),
  creator_id   uuid not null references public.profiles (user_id) on delete cascade,
  creator_team text not null default 'TEAM_A'
    check (creator_team in ('TEAM_A', 'TEAM_B')),
  guest_id     uuid references public.profiles (user_id) on delete set null,
  guest_team   text
    check (guest_team in ('TEAM_A', 'TEAM_B')),
  -- Etichette dispositivi collegati ("Apple Watch", "Wear OS", ...): audit UI.
  creator_device text not null default '',
  guest_device   text not null default '',
  -- Il codice invito scade (Duo Mode §10: inviti temporanei).
  code_expires_at timestamptz not null default now() + interval '2 hours',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index duo_sessions_creator on public.duo_sessions (creator_id);
create index duo_sessions_guest on public.duo_sessions (guest_id);

alter table public.duo_sessions enable row level security;

create policy "duo session participants read" on public.duo_sessions
  for select using (auth.uid() in (creator_id, guest_id));

-- Solo un utente con accesso Duo (premium/override/admin) può creare.
create policy "duo session create" on public.duo_sessions
  for insert with check (
    auth.uid() = creator_id
    and public.has_duo_access(auth.uid())
  );

-- I partecipanti aggiornano stato/dispositivi. Slot team e identità sono
-- protetti dal trigger sotto (un device non può cambiare team a partita
-- avviata, Duo Mode §10).
create policy "duo session participants update" on public.duo_sessions
  for update using (auth.uid() in (creator_id, guest_id))
  with check (auth.uid() in (creator_id, guest_id));

create or replace function public.duo_sessions_guard()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  -- Identità e team sono immutabili via UPDATE diretto (il join passa dalla
  -- RPC duo_join_session, security definer).
  if new.creator_id <> old.creator_id
     or new.creator_team <> old.creator_team
     or new.join_code <> old.join_code
     or new.match_id <> old.match_id
     or (old.guest_id is not null and new.guest_id is distinct from old.guest_id)
     or (old.guest_team is not null and new.guest_team is distinct from old.guest_team)
  then
    raise exception 'duo session slots are immutable';
  end if;
  return new;
end;
$$;

create trigger duo_sessions_guard
  before update on public.duo_sessions
  for each row execute function public.duo_sessions_guard();

-- ---------------------------------------------------- join via codice
-- Security definer: chi entra col codice non è ancora partecipante, quindi
-- la RLS non gli farebbe vedere la riga. Valida codice + scadenza + slot.
create or replace function public.duo_join_session(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.duo_sessions;
  my_team text;
begin
  if auth.uid() is null then
    raise exception 'auth_required';
  end if;

  select * into s
  from public.duo_sessions
  where join_code = upper(trim(p_code))
  for update;

  if not found then
    raise exception 'invalid_code';
  end if;
  if s.status not in ('PENDING', 'ACTIVE') then
    raise exception 'session_closed';
  end if;
  if s.code_expires_at < now() then
    raise exception 'code_expired';
  end if;
  if s.creator_id = auth.uid() then
    -- Il creatore che "rientra" riottiene la propria vista della sessione.
    return jsonb_build_object(
      'sessionId', s.session_id,
      'matchId', s.match_id,
      'format', s.format_json,
      'myTeam', s.creator_team,
      'status', s.status
    );
  end if;
  if s.guest_id is not null and s.guest_id <> auth.uid() then
    raise exception 'session_full';
  end if;

  my_team := case s.creator_team when 'TEAM_A' then 'TEAM_B' else 'TEAM_A' end;

  update public.duo_sessions
  set guest_id = auth.uid(),
      guest_team = my_team,
      status = 'ACTIVE',
      updated_at = now()
  where session_id = s.session_id;

  return jsonb_build_object(
    'sessionId', s.session_id,
    'matchId', s.match_id,
    'format', s.format_json,
    'myTeam', my_team,
    'status', 'ACTIVE'
  );
end;
$$;

grant execute on function public.duo_join_session(text) to authenticated;

-- ---------------------------------------------------- creazione con codice
-- Genera il codice lato server (6 caratteri non ambigui) con retry sulle
-- collisioni. Security invoker: la RLS di insert (has_duo_access) resta
-- il vero gate premium.
create or replace function public.duo_create_session(
  p_match_id text,
  p_format jsonb,
  p_team text default 'TEAM_A'
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  code text;
  sid uuid;
  attempt int := 0;
begin
  if p_team not in ('TEAM_A', 'TEAM_B') then
    raise exception 'invalid_team';
  end if;
  loop
    attempt := attempt + 1;
    -- Alfabeto senza 0/O/1/I: leggibile a bordo campo.
    select string_agg(
             substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                    1 + floor(random() * 32)::int, 1), '')
      into code
      from generate_series(1, 6);
    begin
      insert into public.duo_sessions (match_id, format_json, join_code,
                                       creator_id, creator_team)
      values (p_match_id, coalesce(p_format, '{}'::jsonb), code,
              auth.uid(), p_team)
      returning session_id into sid;
      exit;
    exception when unique_violation then
      if attempt >= 5 then
        raise;
      end if;
    end;
  end loop;
  return jsonb_build_object(
    'sessionId', sid,
    'matchId', p_match_id,
    'joinCode', code,
    'myTeam', p_team,
    'status', 'PENDING'
  );
end;
$$;

grant execute on function public.duo_create_session(text, jsonb, text)
  to authenticated;

-- Team assegnato a un utente in una sessione (per le policy eventi).
create or replace function public.duo_team_of(sid uuid, uid uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when s.creator_id = uid then s.creator_team
    when s.guest_id = uid then s.guest_team
    else null
  end
  from public.duo_sessions s
  where s.session_id = sid;
$$;

-- ==================================================== duo_events
-- Timeline ufficiale della partita Duo. Idempotente per event_id (UUID
-- client); l'ordine autorevole è seq (identity = ordine di arrivo server).
create table public.duo_events (
  event_id     text primary key,
  session_id   uuid not null references public.duo_sessions (session_id)
    on delete cascade,
  match_id     text not null,
  seq          bigint generated always as identity,
  ts_ms        bigint not null,
  type         text not null,
  team_id      text check (team_id in ('TEAM_A', 'TEAM_B')),
  score_before text,
  score_after  text,
  source_device text not null default 'PHONE',
  source_method text not null default 'TAP',
  source_user_id uuid not null,
  source_team_id text check (source_team_id in ('TEAM_A', 'TEAM_B')),
  payload      jsonb,
  created_locally_at bigint,
  server_received_at timestamptz not null default now()
);

create index duo_events_match_seq on public.duo_events (match_id, seq);

alter table public.duo_events enable row level security;

create policy "duo events participants read" on public.duo_events
  for select using (
    exists (
      select 1 from public.duo_sessions s
      where s.session_id = duo_events.session_id
        and auth.uid() in (s.creator_id, s.guest_id)
    )
  );

-- Anti-abuso (Duo Mode §10): ogni device inserisce solo eventi propri;
-- i punti/undo solo del team assegnato. Gli eventi di controllo restano
-- consentiti a entrambi i partecipanti.
create policy "duo events insert own team" on public.duo_events
  for insert with check (
    auth.uid() = source_user_id
    and exists (
      select 1 from public.duo_sessions s
      where s.session_id = duo_events.session_id
        and s.match_id = duo_events.match_id
        and auth.uid() in (s.creator_id, s.guest_id)
        and s.status in ('PENDING', 'ACTIVE')
    )
    and (
      (type = 'POINT_TEAM_A'
        and public.duo_team_of(session_id, auth.uid()) = 'TEAM_A')
      or (type = 'POINT_TEAM_B'
        and public.duo_team_of(session_id, auth.uid()) = 'TEAM_B')
      or (type = 'UNDO'
        and team_id = public.duo_team_of(session_id, auth.uid()))
      or type in ('MATCH_STARTED', 'MATCH_PAUSED', 'MATCH_RESUMED',
                  'MATCH_COMPLETED', 'SCORE_EDITED',
                  'DEVICE_JOINED_MATCH', 'DEVICE_LEFT_MATCH',
                  'TEAM_CONFIRMED')
    )
  );

-- Nessun update/delete dal client: la timeline è append-only (audit §10);
-- le correzioni passano da eventi SCORE_EDITED/UNDO.
