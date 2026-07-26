-- RallyMate — Gruppi amici + classifiche private (PRD 8 Pro) e gestione
-- atleti coach con assegnazione schede e progress tracking (PRD I1/I4).
--
-- Filosofia invariata: cloud minimo. I gruppi condividono SOLO aggregati
-- (partite, vittorie, streak) pubblicati volontariamente dal client; nessun
-- evento-partita. Il modulo coach riusa coach_assignments (0001) rendendo
-- l'assegnazione possibile anche senza acquisto in-app: il valore anti-bypass
-- (PRD I4) resta nel software, il piano Coach è già pagato via IAP.

begin;

-- ==================================================== helper piano Pro
create or replace function public.has_pro_access(uid uuid)
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
        p.plan in ('pro', 'coach')
        or p.premium_override
        or p.account_role in ('admin', 'super_admin')
      )
  );
$$;

revoke all on function public.has_pro_access(uuid) from public, anon, authenticated;
grant execute on function public.has_pro_access(uuid) to authenticated;

-- ==================================================== stats aggregate profilo
-- Pubblicate dal client (best-effort) per le classifiche di gruppo. Non sono
-- leggibili da terzi via select diretta: escono solo dalla RPC leaderboard,
-- che verifica l'appartenenza allo stesso gruppo.
alter table public.profiles
  add column if not exists stat_matches int not null default 0
    check (stat_matches >= 0),
  add column if not exists stat_wins int not null default 0
    check (stat_wins >= 0),
  add column if not exists stat_streak int not null default 0,
  add column if not exists stats_updated_at timestamptz;

-- ==================================================== friend_groups (Pro)
create table if not exists public.friend_groups (
  group_id    uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references public.profiles (user_id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 40),
  invite_code text not null unique,
  created_at  timestamptz not null default now()
);

create table if not exists public.friend_group_members (
  group_id   uuid not null references public.friend_groups (group_id) on delete cascade,
  user_id    uuid not null references public.profiles (user_id) on delete cascade,
  joined_at  timestamptz not null default now(),
  primary key (group_id, user_id)
);

create index if not exists friend_group_members_user
  on public.friend_group_members (user_id);

alter table public.friend_groups enable row level security;
alter table public.friend_group_members enable row level security;

-- Lettura: solo i membri vedono il gruppo (incluso invite_code, che serve
-- per invitare altri amici). Scritture SOLO via RPC security definer.
create policy "groups member read" on public.friend_groups
  for select using (
    exists (
      select 1 from public.friend_group_members m
      where m.group_id = friend_groups.group_id and m.user_id = auth.uid()
    )
  );

create policy "group members member read" on public.friend_group_members
  for select using (
    exists (
      select 1 from public.friend_group_members m
      where m.group_id = friend_group_members.group_id
        and m.user_id = auth.uid()
    )
  );

-- Generatore codice invito senza caratteri ambigui (stile duo join_code).
create or replace function public._gen_group_code()
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code text := '';
  i int;
begin
  for i in 1..8 loop
    v_code := v_code
      || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
  end loop;
  return v_code;
end;
$$;

revoke all on function public._gen_group_code() from public, anon, authenticated;

create or replace function public.create_friend_group(p_name text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_name text := left(btrim(coalesce(p_name, '')), 40);
  v_group public.friend_groups;
  v_attempt int := 0;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  -- Creazione gruppi: piano Pro/Coach (PRD 8 "classifiche private; gruppi amici").
  if not public.has_pro_access(v_uid) then
    return jsonb_build_object('ok', false, 'error', 'pro_required');
  end if;
  if char_length(v_name) < 1 then
    return jsonb_build_object('ok', false, 'error', 'invalid_name');
  end if;
  if (
    select count(*) from public.friend_groups g where g.owner_id = v_uid
  ) >= 10 then
    return jsonb_build_object('ok', false, 'error', 'too_many_groups');
  end if;

  loop
    v_attempt := v_attempt + 1;
    begin
      insert into public.friend_groups (owner_id, name, invite_code)
      values (v_uid, v_name, public._gen_group_code())
      returning * into v_group;
      exit;
    exception when unique_violation then
      if v_attempt >= 5 then
        return jsonb_build_object('ok', false, 'error', 'retry');
      end if;
    end;
  end loop;

  insert into public.friend_group_members (group_id, user_id)
  values (v_group.group_id, v_uid);

  return jsonb_build_object(
    'ok', true,
    'groupId', v_group.group_id,
    'inviteCode', v_group.invite_code
  );
end;
$$;

create or replace function public.join_friend_group(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_group public.friend_groups;
  v_members int;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if char_length(v_code) <> 8 then
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;
  if (
    select count(*) from public.security_rate_events e
    where e.actor_id = v_uid and e.action = 'GROUP_JOIN'
      and e.created_at > now() - interval '1 hour'
  ) >= 10 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  insert into public.security_rate_events (actor_id, action, target_hash)
  values (
    v_uid, 'GROUP_JOIN',
    encode(extensions.digest(v_code, 'sha256'), 'hex')
  );

  select * into v_group from public.friend_groups g
  where g.invite_code = v_code;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  -- Blocchi reciproci owner<->joiner: il codice non deve aggirarli.
  if exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = v_uid and b.blocked_id = v_group.owner_id)
       or (b.blocker_id = v_group.owner_id and b.blocked_id = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_available');
  end if;
  select count(*) into v_members
  from public.friend_group_members m where m.group_id = v_group.group_id;
  if v_members >= 32 then
    return jsonb_build_object('ok', false, 'error', 'group_full');
  end if;

  insert into public.friend_group_members (group_id, user_id)
  values (v_group.group_id, v_uid)
  on conflict do nothing;

  return jsonb_build_object(
    'ok', true,
    'groupId', v_group.group_id,
    'name', v_group.name
  );
end;
$$;

create or replace function public.leave_friend_group(p_group_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select owner_id into v_owner
  from public.friend_groups where group_id = p_group_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_owner = v_uid then
    -- L'owner che esce scioglie il gruppo (classifica privata di sua proprietà).
    delete from public.friend_groups where group_id = p_group_id;
    return jsonb_build_object('ok', true, 'deleted', true);
  end if;
  delete from public.friend_group_members
  where group_id = p_group_id and user_id = v_uid;
  return jsonb_build_object('ok', true, 'deleted', false);
end;
$$;

create or replace function public.remove_group_member(
  p_group_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if not exists (
    select 1 from public.friend_groups g
    where g.group_id = p_group_id and g.owner_id = v_uid
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_owner');
  end if;
  if p_user_id = v_uid then
    return jsonb_build_object('ok', false, 'error', 'use_leave');
  end if;
  delete from public.friend_group_members
  where group_id = p_group_id and user_id = p_user_id;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.my_friend_groups()
returns table (
  group_id uuid,
  name text,
  invite_code text,
  owner_id uuid,
  is_owner boolean,
  member_count bigint,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    g.group_id,
    g.name,
    g.invite_code,
    g.owner_id,
    g.owner_id = auth.uid() as is_owner,
    (select count(*) from public.friend_group_members m
      where m.group_id = g.group_id) as member_count,
    g.created_at
  from public.friend_groups g
  where exists (
    select 1 from public.friend_group_members m
    where m.group_id = g.group_id and m.user_id = auth.uid()
  )
  order by g.created_at;
$$;

-- Classifica privata del gruppo (PRD 8 Pro "classifiche private").
create or replace function public.friend_group_leaderboard(p_group_id uuid)
returns table (
  user_id uuid,
  nickname text,
  name text,
  avatar_url text,
  level text,
  skill_score int,
  stat_matches int,
  stat_wins int,
  stat_streak int,
  stats_updated_at timestamptz,
  is_owner boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.user_id,
    p.nickname,
    p.name,
    p.avatar_url,
    p.level,
    p.skill_score,
    p.stat_matches,
    p.stat_wins,
    p.stat_streak,
    p.stats_updated_at,
    g.owner_id = p.user_id as is_owner
  from public.friend_group_members m
  join public.friend_groups g on g.group_id = m.group_id
  join public.profiles p on p.user_id = m.user_id
  where m.group_id = p_group_id
    and exists (
      select 1 from public.friend_group_members me
      where me.group_id = p_group_id and me.user_id = auth.uid()
    )
  order by
    p.stat_wins desc,
    (p.stat_wins::numeric / nullif(p.stat_matches, 0)) desc nulls last,
    p.skill_score desc,
    p.nickname;
$$;

-- ==================================================== coach: link atleti
-- Codice personale del coach: l'atleta lo inserisce per collegarsi
-- (stile duo join_code, niente grafo amicizie richiesto).
alter table public.coach_profiles
  add column if not exists athlete_link_code text unique;

create table if not exists public.coach_athletes (
  coach_id   uuid not null references public.coach_profiles (coach_id) on delete cascade,
  athlete_id uuid not null references public.profiles (user_id) on delete cascade,
  status     text not null default 'ACTIVE'
    check (status in ('ACTIVE', 'ENDED')),
  linked_at  timestamptz not null default now(),
  ended_at   timestamptz,
  primary key (coach_id, athlete_id)
);

create index if not exists coach_athletes_athlete
  on public.coach_athletes (athlete_id);

alter table public.coach_athletes enable row level security;

create policy "coach athletes participants read" on public.coach_athletes
  for select using (auth.uid() in (coach_id, athlete_id));

create or replace function public.my_coach_link_code()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_code text;
  v_attempt int := 0;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.user_id = v_uid
      and (p.plan = 'coach' or p.premium_override
           or p.account_role in ('admin', 'super_admin'))
  ) then
    return jsonb_build_object('ok', false, 'error', 'coach_required');
  end if;
  -- Il profilo coach deve esistere (upsert idempotente, RLS-safe qui).
  insert into public.coach_profiles (coach_id)
  values (v_uid)
  on conflict (coach_id) do nothing;

  select athlete_link_code into v_code
  from public.coach_profiles where coach_id = v_uid;
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

create or replace function public.join_coach(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
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
    select count(*) from public.security_rate_events e
    where e.actor_id = v_uid and e.action = 'COACH_JOIN'
      and e.created_at > now() - interval '1 hour'
  ) >= 10 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  insert into public.security_rate_events (actor_id, action, target_hash)
  values (
    v_uid, 'COACH_JOIN',
    encode(extensions.digest(v_code, 'sha256'), 'hex')
  );

  select coach_id into v_coach
  from public.coach_profiles where athlete_link_code = v_code;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  if v_coach = v_uid then
    return jsonb_build_object('ok', false, 'error', 'self_link');
  end if;
  if exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = v_uid and b.blocked_id = v_coach)
       or (b.blocker_id = v_coach and b.blocked_id = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_available');
  end if;

  insert into public.coach_athletes (coach_id, athlete_id)
  values (v_coach, v_uid)
  on conflict (coach_id, athlete_id)
    do update set status = 'ACTIVE', ended_at = null, linked_at = now();

  return jsonb_build_object('ok', true, 'coachId', v_coach);
end;
$$;

create or replace function public.end_coach_link(
  p_coach_id uuid,
  p_athlete_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if v_uid not in (p_coach_id, p_athlete_id) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  update public.coach_athletes
  set status = 'ENDED', ended_at = now()
  where coach_id = p_coach_id and athlete_id = p_athlete_id
    and status = 'ACTIVE';
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- Roster con dati profilo + avanzamento schede: una chiamata per la tab Atleti.
create or replace function public.my_coach_athletes()
returns table (
  athlete_id uuid,
  nickname text,
  name text,
  avatar_url text,
  level text,
  preferred_role text,
  linked_at timestamptz,
  assignments_total bigint,
  assignments_completed bigint,
  last_progress_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    ca.athlete_id,
    p.nickname,
    p.name,
    p.avatar_url,
    p.level,
    p.preferred_role,
    ca.linked_at,
    (select count(*) from public.coach_assignments a
      where a.coach_id = ca.coach_id and a.player_id = ca.athlete_id),
    (select count(*) from public.coach_assignments a
      where a.coach_id = ca.coach_id and a.player_id = ca.athlete_id
        and a.status = 'COMPLETED'),
    (select max(a.updated_at) from public.coach_assignments a
      where a.coach_id = ca.coach_id and a.player_id = ca.athlete_id)
  from public.coach_athletes ca
  join public.profiles p on p.user_id = ca.athlete_id
  where ca.coach_id = auth.uid() and ca.status = 'ACTIVE'
  order by ca.linked_at;
$$;

create or replace function public.my_coaches()
returns table (
  coach_id uuid,
  nickname text,
  name text,
  avatar_url text,
  club text,
  verified boolean,
  linked_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    ca.coach_id,
    p.nickname,
    p.name,
    p.avatar_url,
    cp.club,
    cp.verified,
    ca.linked_at
  from public.coach_athletes ca
  join public.coach_profiles cp on cp.coach_id = ca.coach_id
  join public.profiles p on p.user_id = ca.coach_id
  where ca.athlete_id = auth.uid() and ca.status = 'ACTIVE'
  order by ca.linked_at;
$$;

-- ==================================================== coach: assegnazioni
-- 0001 legava ogni scheda a un acquisto. Il coach ora assegna schede anche
-- agli atleti collegati direttamente (allievi dal vivo): il purchase resta
-- per i pacchetti venduti in-app.
alter table public.coach_assignments
  alter column purchase_id drop not null;

drop policy if exists "assignments coach" on public.coach_assignments;

create policy "assignments coach read" on public.coach_assignments
  for select using (auth.uid() = coach_id);
create policy "assignments coach insert" on public.coach_assignments
  for insert with check (
    auth.uid() = coach_id
    and (
      purchase_id is not null
      or exists (
        select 1 from public.coach_athletes ca
        where ca.coach_id = coach_assignments.coach_id
          and ca.athlete_id = coach_assignments.player_id
          and ca.status = 'ACTIVE'
      )
    )
  );
create policy "assignments coach update" on public.coach_assignments
  for update using (auth.uid() = coach_id) with check (auth.uid() = coach_id);
create policy "assignments coach delete" on public.coach_assignments
  for delete using (auth.uid() = coach_id);

-- Il player aggiorna SOLO progress/feedback/status (trigger guard: la RLS
-- non distingue le colonne).
create or replace function public._guard_assignment_player_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.player_id and auth.uid() <> old.coach_id then
    if new.training_plan is distinct from old.training_plan
       or new.coach_id is distinct from old.coach_id
       or new.player_id is distinct from old.player_id
       or new.purchase_id is distinct from old.purchase_id then
      raise exception 'players may only update progress, feedback and status';
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists coach_assignments_player_guard on public.coach_assignments;
create trigger coach_assignments_player_guard
  before update on public.coach_assignments
  for each row execute function public._guard_assignment_player_update();

-- ==================================================== profilo coach pubblico
-- I1: profilo pubblico con bio, club, certificazioni, specializzazioni,
-- badge verified, rating e pacchetti attivi. Il nome/avatar esce da qui
-- anche se profiles.privacy = PRIVATE: pubblicare il profilo coach è una
-- scelta esplicita (visible = true).
create or replace function public.coach_public_profile(p_coach_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_coach public.coach_profiles;
  v_profile public.profiles;
  v_packages jsonb;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select * into v_coach from public.coach_profiles c
  where c.coach_id = p_coach_id
    and (c.visible = true or c.coach_id = auth.uid());
  if not found then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;
  select * into v_profile from public.profiles p where p.user_id = p_coach_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'packageId', k.package_id,
    'title', k.title,
    'description', k.description,
    'type', k.type,
    'priceCents', k.price_cents
  ) order by k.created_at desc), '[]'::jsonb)
  into v_packages
  from public.coach_packages k
  where k.coach_id = p_coach_id and k.status = 'ACTIVE';

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

-- ==================================================== grants
do $$
declare
  f regprocedure;
begin
  foreach f in array array[
    'public.create_friend_group(text)'::regprocedure,
    'public.join_friend_group(text)'::regprocedure,
    'public.leave_friend_group(uuid)'::regprocedure,
    'public.remove_group_member(uuid,uuid)'::regprocedure,
    'public.my_friend_groups()'::regprocedure,
    'public.friend_group_leaderboard(uuid)'::regprocedure,
    'public.my_coach_link_code()'::regprocedure,
    'public.join_coach(text)'::regprocedure,
    'public.end_coach_link(uuid,uuid)'::regprocedure,
    'public.my_coach_athletes()'::regprocedure,
    'public.my_coaches()'::regprocedure,
    'public.coach_public_profile(uuid)'::regprocedure
  ] loop
    execute format(
      'revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;

commit;
