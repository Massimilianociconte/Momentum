-- RallyMate social/team hardening.
--
-- This migration deliberately keeps exact locations and hardware identifiers
-- out of the cloud. Public discovery goes through narrow RPCs so privileged
-- profile columns (plan, role, limits) never leak with a broad table select.

create extension if not exists pgcrypto with schema extensions;

-- ============================================================ public profile
alter table public.profiles
  add column if not exists bio text not null default '',
  add column if not exists preferred_side text not null default 'UNDEFINED'
    check (preferred_side in ('LEFT', 'RIGHT', 'FLEX', 'UNDEFINED')),
  add column if not exists club text not null default '',
  add column if not exists avatar_path text,
  add column if not exists show_online_status boolean not null default false,
  add column if not exists show_club boolean not null default false,
  add column if not exists show_activity boolean not null default false,
  add column if not exists public_stats_enabled boolean not null default false,
  add column if not exists public_match_count int not null default 0
    check (public_match_count between 0 and 1000000),
  add column if not exists public_win_rate int not null default 0
    check (public_win_rate between 0 and 100),
  add column if not exists public_badges text[] not null default '{}',
  add column if not exists preferred_time text not null default '',
  add column if not exists map_visibility text not null default 'HIDDEN'
    check (map_visibility in ('PUBLIC', 'FRIENDS', 'HIDDEN')),
  add column if not exists last_active_at timestamptz;

-- Created before the discovery RPC because PostgreSQL resolves referenced
-- relations when a SQL-language function is defined.
create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(user_id) on delete cascade,
  blocked_id uuid not null references public.profiles(user_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- Append-only counters used by SECURITY DEFINER RPCs. Keeping attempts in a
-- separate table prevents users from bypassing limits by repeatedly reusing
-- the same friendship row or guessing a Duo code. No client can read/write it.
create table if not exists public.security_rate_events (
  event_id bigint generated always as identity primary key,
  actor_id uuid not null references public.profiles(user_id) on delete cascade,
  action text not null check (char_length(action) between 1 and 40),
  target_hash text,
  success boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists security_rate_events_actor_window
  on public.security_rate_events(actor_id, action, created_at desc);
alter table public.security_rate_events enable row level security;

-- A row-level policy cannot hide privileged columns. Profiles are therefore
-- owner-only; social and coach surfaces use field-limited RPCs/views.
drop policy if exists "own profile read" on public.profiles;
create policy "own profile read" on public.profiles
  for select using (auth.uid() = user_id);

drop policy if exists "own profile insert" on public.profiles;
create policy "own profile insert" on public.profiles
  for insert with check (
    auth.uid() = user_id
    and plan = 'free'
    and premium_override = false
    and account_role = 'user'
    and assistant_enabled = true
    and assistant_daily_limit = 20
    and assistant_live_limit = 5
    and reliability_score = 80
  );

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
      select p.assistant_enabled from public.profiles p where p.user_id = auth.uid()
    )
    and assistant_daily_limit = (
      select p.assistant_daily_limit from public.profiles p where p.user_id = auth.uid()
    )
    and assistant_live_limit = (
      select p.assistant_live_limit from public.profiles p where p.user_id = auth.uid()
    )
    and reliability_score = (
      select p.reliability_score from public.profiles p where p.user_id = auth.uid()
    )
  );

create or replace function public.discover_social_players(p_limit int default 50)
returns table (
  user_id uuid,
  name text,
  nickname text,
  avatar_url text,
  level text,
  preferred_role text,
  preferred_side text,
  dominant_hand text,
  availability text,
  style_tags text[],
  skill_score int,
  reliability_score int,
  home_area text,
  club text,
  bio text,
  show_online_status boolean,
  show_activity boolean,
  last_active_at timestamptz,
  public_stats_enabled boolean,
  public_match_count int,
  public_win_rate int,
  public_badges text[],
  preferred_time text,
  mutual_friends_count int
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.user_id,
    p.name,
    p.nickname,
    p.avatar_url,
    p.level,
    p.preferred_role,
    p.preferred_side,
    p.dominant_hand,
    p.availability,
    p.style_tags,
    p.skill_score,
    p.reliability_score,
    p.home_area,
    case when p.show_club then p.club else '' end,
    p.bio,
    p.show_online_status,
    p.show_activity,
    case when p.show_activity or p.show_online_status
      then p.last_active_at else null end,
    p.public_stats_enabled,
    case when p.public_stats_enabled then p.public_match_count else 0 end,
    case when p.public_stats_enabled then p.public_win_rate else 0 end,
    case when p.public_stats_enabled then p.public_badges else '{}'::text[] end,
    p.preferred_time,
    (
      select count(*)::int
      from (
        select case when r1.requester_id = auth.uid()
          then r1.receiver_id else r1.requester_id end as friend_id
        from public.social_contact_requests r1
        where r1.status = 'ACCEPTED'
          and auth.uid() in (r1.requester_id, r1.receiver_id)
      ) mine
      join (
        select case when r2.requester_id = p.user_id
          then r2.receiver_id else r2.requester_id end as friend_id
        from public.social_contact_requests r2
        where r2.status = 'ACCEPTED'
          and p.user_id in (r2.requester_id, r2.receiver_id)
      ) theirs using (friend_id)
    )
  from public.profiles p
  where auth.uid() is not null
    and p.user_id <> auth.uid()
    and p.social_enabled
    and p.map_visibility = 'PUBLIC'
    and p.availability <> 'HIDDEN'
    and not exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.user_id)
         or (b.blocker_id = p.user_id and b.blocked_id = auth.uid())
    )
  order by p.reliability_score desc, p.skill_score desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

revoke all on function public.discover_social_players(int) from public;
grant execute on function public.discover_social_players(int) to authenticated;

create or replace function public.social_player_profile(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'ok', true,
    'user_id', p.user_id,
    'name', p.name,
    'nickname', p.nickname,
    'avatar_url', p.avatar_url,
    'level', p.level,
    'preferred_role', p.preferred_role,
    'preferred_side', p.preferred_side,
    'dominant_hand', p.dominant_hand,
    'availability', p.availability,
    'style_tags', p.style_tags,
    'skill_score', p.skill_score,
    'reliability_score', p.reliability_score,
    'home_area', p.home_area,
    'club', case when p.show_club then p.club else '' end,
    'bio', p.bio,
    'show_online_status', p.show_online_status,
    'show_activity', p.show_activity,
    'last_active_at', case when p.show_activity or p.show_online_status
      then p.last_active_at else null end,
    'public_stats_enabled', p.public_stats_enabled,
    'public_match_count', case when p.public_stats_enabled then p.public_match_count else 0 end,
    'public_win_rate', case when p.public_stats_enabled then p.public_win_rate else 0 end,
    'public_badges', case when p.public_stats_enabled then p.public_badges else '{}'::text[] end,
    'preferred_time', p.preferred_time,
    'mutual_friends_count', (
      select count(*)::int
      from (
        select case when r1.requester_id = auth.uid()
          then r1.receiver_id else r1.requester_id end as friend_id
        from public.social_contact_requests r1
        where r1.status = 'ACCEPTED'
          and auth.uid() in (r1.requester_id, r1.receiver_id)
      ) mine
      join (
        select case when r2.requester_id = p.user_id
          then r2.receiver_id else r2.requester_id end as friend_id
        from public.social_contact_requests r2
        where r2.status = 'ACCEPTED'
          and p.user_id in (r2.requester_id, r2.receiver_id)
      ) theirs using (friend_id)
    )
  )
  from public.profiles p
  where auth.uid() is not null
    and p.user_id = p_user_id
    and p.user_id <> auth.uid()
    and p.social_enabled
    and p.map_visibility = 'PUBLIC'
    and not exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.user_id)
         or (b.blocker_id = p.user_id and b.blocked_id = auth.uid())
    );
$$;

-- ============================================================ blocks/friends
alter table public.user_blocks enable row level security;
create policy "blocks owner read" on public.user_blocks
  for select using (auth.uid() = blocker_id);

alter table public.social_contact_requests
  add column if not exists accepted_at timestamptz;

alter table public.social_contact_requests
  drop constraint if exists social_contact_requests_status_check;
alter table public.social_contact_requests
  add constraint social_contact_requests_status_check
  check (status in ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED', 'BLOCKED'));

-- Collapse any old A->B / B->A duplicates before enforcing a symmetric pair.
with ranked as (
  select request_id,
         row_number() over (
           partition by least(requester_id, receiver_id),
                        greatest(requester_id, receiver_id)
           order by updated_at desc, created_at desc, request_id desc
         ) as rn
  from public.social_contact_requests
)
delete from public.social_contact_requests r
using ranked x
where r.request_id = x.request_id and x.rn > 1;

alter table public.social_contact_requests
  drop constraint if exists social_contact_requests_requester_id_receiver_id_key;
create unique index if not exists social_contact_requests_pair_unique
  on public.social_contact_requests (
    least(requester_id, receiver_id), greatest(requester_id, receiver_id)
  );
create index if not exists social_contacts_status_requester
  on public.social_contact_requests(status, requester_id);
create index if not exists social_contacts_status_receiver
  on public.social_contact_requests(status, receiver_id);

drop policy if exists "contact request create" on public.social_contact_requests;
drop policy if exists "contact request update receiver" on public.social_contact_requests;

create or replace function public.send_friend_request(
  p_receiver_id uuid,
  p_message text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_existing public.social_contact_requests;
  v_rate_id bigint;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'auth_required'); end if;
  if p_receiver_id is null or p_receiver_id = v_uid then
    return jsonb_build_object('ok', false, 'error', 'invalid_receiver');
  end if;
  if length(coalesce(p_message, '')) > 280 then
    return jsonb_build_object('ok', false, 'error', 'message_too_long');
  end if;
  if (
    select count(*) from public.security_rate_events e
    where e.actor_id = v_uid and e.action = 'FRIEND_REQUEST'
      and e.created_at > now() - interval '1 hour'
  ) >= 20 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  insert into public.security_rate_events(actor_id, action, target_hash)
  values (
    v_uid,
    'FRIEND_REQUEST',
    encode(extensions.digest(p_receiver_id::text, 'sha256'), 'hex')
  ) returning event_id into v_rate_id;
  if exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = v_uid and b.blocked_id = p_receiver_id)
       or (b.blocker_id = p_receiver_id and b.blocked_id = v_uid)
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_available');
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.user_id = p_receiver_id and p.social_enabled
      and p.map_visibility <> 'HIDDEN'
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_available');
  end if;
  select * into v_existing
  from public.social_contact_requests r
  where least(r.requester_id, r.receiver_id) = least(v_uid, p_receiver_id)
    and greatest(r.requester_id, r.receiver_id) = greatest(v_uid, p_receiver_id)
  for update;

  if found and v_existing.status = 'ACCEPTED' then
    update public.security_rate_events set success = true where event_id = v_rate_id;
    return jsonb_build_object('ok', true, 'status', 'ACCEPTED', 'requestId', v_existing.request_id);
  end if;
  if found and v_existing.status = 'PENDING'
     and v_existing.requester_id = p_receiver_id then
    update public.social_contact_requests
    set status = 'ACCEPTED', accepted_at = now(), updated_at = now()
    where request_id = v_existing.request_id;
    update public.security_rate_events set success = true where event_id = v_rate_id;
    return jsonb_build_object('ok', true, 'status', 'ACCEPTED', 'requestId', v_existing.request_id);
  end if;
  if found then
    update public.social_contact_requests
    set requester_id = v_uid,
        receiver_id = p_receiver_id,
        message = left(coalesce(p_message, ''), 280),
        status = 'PENDING',
        accepted_at = null,
        created_at = now(),
        updated_at = now()
    where request_id = v_existing.request_id;
    update public.security_rate_events set success = true where event_id = v_rate_id;
    return jsonb_build_object('ok', true, 'status', 'PENDING', 'requestId', v_existing.request_id);
  end if;

  insert into public.social_contact_requests(requester_id, receiver_id, message)
  values (v_uid, p_receiver_id, left(coalesce(p_message, ''), 280))
  returning * into v_existing;
  update public.security_rate_events set success = true where event_id = v_rate_id;
  return jsonb_build_object('ok', true, 'status', 'PENDING', 'requestId', v_existing.request_id);
end;
$$;

create or replace function public.respond_friend_request(
  p_request_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.social_contact_requests;
begin
  select * into v_row from public.social_contact_requests
  where request_id = p_request_id for update;
  if not found or v_uid is null or v_row.receiver_id <> v_uid
     or v_row.status <> 'PENDING' then
    return jsonb_build_object('ok', false, 'error', 'request_not_available');
  end if;
  update public.social_contact_requests
  set status = case when p_accept then 'ACCEPTED' else 'DECLINED' end,
      accepted_at = case when p_accept then now() else null end,
      updated_at = now()
  where request_id = p_request_id;
  return jsonb_build_object('ok', true,
    'status', case when p_accept then 'ACCEPTED' else 'DECLINED' end);
end;
$$;

create or replace function public.cancel_friend_request(p_request_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  update public.social_contact_requests
  set status = 'CANCELLED', updated_at = now()
  where request_id = p_request_id
    and requester_id = auth.uid() and status = 'PENDING'
  returning true;
$$;

create or replace function public.remove_friend(p_other_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  update public.social_contact_requests
  set status = 'CANCELLED', accepted_at = null, updated_at = now()
  where status = 'ACCEPTED'
    and auth.uid() in (requester_id, receiver_id)
    and p_other_id in (requester_id, receiver_id)
  returning true;
$$;

create or replace function public.block_user(p_other_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or p_other_id is null or p_other_id = auth.uid() then return false; end if;
  insert into public.user_blocks(blocker_id, blocked_id)
  values (auth.uid(), p_other_id) on conflict do nothing;
  update public.social_contact_requests
  set status = 'BLOCKED', accepted_at = null, updated_at = now()
  where least(requester_id, receiver_id) = least(auth.uid(), p_other_id)
    and greatest(requester_id, receiver_id) = greatest(auth.uid(), p_other_id);
  return true;
end;
$$;

create or replace function public.unblock_user(p_other_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  delete from public.user_blocks
  where blocker_id = auth.uid() and blocked_id = p_other_id
  returning true;
$$;

create or replace function public.social_relationships()
returns table (
  request_id uuid,
  other_user_id uuid,
  direction text,
  status text,
  created_at timestamptz,
  name text,
  nickname text,
  avatar_url text,
  level text,
  availability text,
  home_area text,
  club text,
  show_online_status boolean,
  show_activity boolean,
  last_active_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    r.request_id,
    case when r.requester_id = auth.uid() then r.receiver_id else r.requester_id end,
    case when r.requester_id = auth.uid() then 'OUTGOING' else 'INCOMING' end,
    r.status,
    r.created_at,
    p.name,
    p.nickname,
    p.avatar_url,
    p.level,
    p.availability,
    p.home_area,
    case when p.show_club then p.club else '' end,
    p.show_online_status,
    p.show_activity,
    case when p.show_activity or p.show_online_status
      then p.last_active_at else null end
  from public.social_contact_requests r
  join public.profiles p on p.user_id = case
    when r.requester_id = auth.uid() then r.receiver_id else r.requester_id end
  where auth.uid() in (r.requester_id, r.receiver_id)
    and not exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.user_id)
         or (b.blocker_id = p.user_id and b.blocked_id = auth.uid())
    )
  order by r.updated_at desc;
$$;

create or replace function public.social_inbox()
returns table (
  item_id uuid,
  kind text,
  from_user_id uuid,
  from_name text,
  message text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select r.request_id, 'contact'::text, r.requester_id,
         coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Giocatore'),
         r.message, r.created_at
  from public.social_contact_requests r
  join public.profiles p on p.user_id = r.requester_id
  where r.receiver_id = auth.uid() and r.status = 'PENDING'
    and not exists (
      select 1 from public.user_blocks b
      where b.blocker_id = auth.uid() and b.blocked_id = r.requester_id
    )
  union all
  select m.proposal_id, 'proposal'::text, m.creator_id,
         coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Giocatore'),
         m.message, m.created_at
  from public.match_proposals m
  join public.profiles p on p.user_id = m.creator_id
  where m.receiver_id = auth.uid() and m.status = 'OPEN'
    and not exists (
      select 1 from public.user_blocks b
      where b.blocker_id = auth.uid() and b.blocked_id = m.creator_id
    )
  union all
  select t.request_id, 'team'::text, t.requester_id,
         coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Giocatore'),
         t.message, t.created_at
  from public.team_join_requests t
  join public.profiles p on p.user_id = t.requester_id
  where t.team_owner_id = auth.uid() and t.status = 'PENDING'
  order by created_at desc;
$$;

create or replace function public.blocked_users()
returns table (
  user_id uuid,
  name text,
  nickname text,
  avatar_url text,
  blocked_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select p.user_id, p.name, p.nickname, p.avatar_url, b.created_at
  from public.user_blocks b
  join public.profiles p on p.user_id = b.blocked_id
  where b.blocker_id = auth.uid()
  order by b.created_at desc;
$$;

create table if not exists public.social_reports (
  report_id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(user_id) on delete cascade,
  reported_id uuid not null references public.profiles(user_id) on delete cascade,
  category text not null
    check (category in ('SPAM', 'HARASSMENT', 'IMPERSONATION', 'PRIVACY', 'OTHER')),
  details text not null default '' check (char_length(details) <= 1000),
  status text not null default 'OPEN'
    check (status in ('OPEN', 'REVIEWED', 'CLOSED')),
  created_at timestamptz not null default now(),
  check (reporter_id <> reported_id)
);

alter table public.social_reports enable row level security;
create policy "reporter read own reports" on public.social_reports
  for select using (reporter_id = auth.uid());

create or replace function public.report_social_user(
  p_user_id uuid,
  p_category text,
  p_details text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_id uuid;
begin
  if auth.uid() is null or p_user_id is null or p_user_id = auth.uid() then
    return jsonb_build_object('ok', false, 'error', 'invalid_user');
  end if;
  if p_category not in ('SPAM', 'HARASSMENT', 'IMPERSONATION', 'PRIVACY', 'OTHER')
     or char_length(coalesce(p_details, '')) > 1000 then
    return jsonb_build_object('ok', false, 'error', 'invalid_report');
  end if;
  if (select count(*) from public.social_reports r
      where r.reporter_id = auth.uid() and r.created_at > now() - interval '1 day') >= 5 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  insert into public.social_reports(reporter_id, reported_id, category, details)
  values (auth.uid(), p_user_id, p_category, left(coalesce(p_details, ''), 1000))
  returning report_id into v_id;
  return jsonb_build_object('ok', true, 'reportId', v_id);
end;
$$;

-- ============================================================ cloud teams
create table if not exists public.teams (
  team_id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(user_id) on delete cascade,
  local_id text not null,
  name text not null check (char_length(name) between 1 and 80),
  avatar_path text,
  image_version int not null default 0,
  scoring_style text not null default 'AUTO'
    check (scoring_style in ('AUTO', 'COLOR', 'IMAGE')),
  color_argb bigint not null default 4291359029,
  visibility text not null default 'PRIVATE'
    check (visibility in ('PUBLIC', 'FRIENDS', 'PRIVATE')),
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(owner_id, local_id)
);

create table if not exists public.team_memberships (
  team_id uuid not null references public.teams(team_id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  member_role text not null default 'MEMBER'
    check (member_role in ('OWNER', 'MEMBER')),
  padel_role text not null default 'UNDEFINED'
    check (padel_role in ('LEFT', 'RIGHT', 'FLEX', 'UNDEFINED')),
  status text not null default 'PENDING'
    check (status in ('PENDING', 'ACCEPTED', 'DECLINED', 'REMOVED')),
  joined_at timestamptz,
  created_at timestamptz not null default now(),
  primary key(team_id, user_id)
);

create table if not exists public.team_connections (
  team_low uuid not null references public.teams(team_id) on delete cascade,
  team_high uuid not null references public.teams(team_id) on delete cascade,
  connected_by uuid not null references public.profiles(user_id),
  created_at timestamptz not null default now(),
  primary key(team_low, team_high),
  check (team_low < team_high)
);

alter table public.teams enable row level security;
alter table public.team_memberships enable row level security;
alter table public.team_connections enable row level security;

create policy "team participant or public read" on public.teams
  for select using (
    visibility = 'PUBLIC'
    or owner_id = auth.uid()
    or exists (
      select 1 from public.team_memberships m
      where m.team_id = teams.team_id and m.user_id = auth.uid()
        and m.status = 'ACCEPTED'
    )
  );
create policy "team owner insert" on public.teams
  for insert with check (owner_id = auth.uid());
create policy "team owner update" on public.teams
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "team owner delete" on public.teams
  for delete using (owner_id = auth.uid());

create policy "membership participants read" on public.team_memberships
  for select using (
    user_id = auth.uid()
    or exists (select 1 from public.teams t where t.team_id = team_memberships.team_id and t.owner_id = auth.uid())
  );

create policy "team connections participant read" on public.team_connections
  for select using (
    exists (select 1 from public.teams t where t.team_id in (team_low, team_high) and t.owner_id = auth.uid())
  );

create or replace function public.has_cloud_media_access()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p where p.user_id = auth.uid()
      and (p.plan in ('plus', 'pro', 'coach') or p.premium_override
           or p.account_role in ('admin', 'super_admin'))
  );
$$;

create or replace function public.upsert_cloud_team(
  p_local_id text,
  p_name text,
  p_scoring_style text default 'AUTO',
  p_color_argb bigint default 4291359029,
  p_visibility text default 'PRIVATE'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_team_id uuid;
begin
  if auth.uid() is null then raise exception 'auth_required'; end if;
  if char_length(trim(coalesce(p_name, ''))) not between 1 and 80 then raise exception 'invalid_name'; end if;
  if p_scoring_style not in ('AUTO', 'COLOR', 'IMAGE') then raise exception 'invalid_scoring_style'; end if;
  if p_visibility not in ('PUBLIC', 'FRIENDS', 'PRIVATE') then raise exception 'invalid_visibility'; end if;
  insert into public.teams(owner_id, local_id, name, scoring_style, color_argb, visibility)
  values (auth.uid(), p_local_id, trim(p_name), p_scoring_style, p_color_argb, p_visibility)
  on conflict (owner_id, local_id) do update set
    name = excluded.name,
    scoring_style = excluded.scoring_style,
    color_argb = excluded.color_argb,
    visibility = excluded.visibility,
    updated_at = now()
  returning team_id into v_team_id;
  insert into public.team_memberships(team_id, user_id, member_role, status, joined_at)
  values (v_team_id, auth.uid(), 'OWNER', 'ACCEPTED', now())
  on conflict (team_id, user_id) do update set status = 'ACCEPTED', member_role = 'OWNER';
  return v_team_id;
end;
$$;

create or replace function public.set_team_avatar(p_team_id uuid, p_avatar_path text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if nullif(p_avatar_path, '') is not null then
    if not public.has_cloud_media_access() then
      raise exception 'premium_required';
    end if;
    if p_avatar_path <> auth.uid()::text || '/' || p_team_id::text || '/avatar.jpg' then
      raise exception 'invalid_avatar_path';
    end if;
  end if;
  update public.teams set avatar_path = nullif(p_avatar_path, ''),
    image_version = image_version + 1, updated_at = now()
  where team_id = p_team_id and owner_id = auth.uid();
  return found;
end;
$$;

create or replace function public.my_cloud_teams()
returns table (
  team_id uuid,
  name text,
  avatar_path text,
  image_version int,
  scoring_style text,
  color_argb bigint,
  cloud_role text,
  owner_name text,
  member_count int
)
language sql
stable
security definer
set search_path = public
as $$
  select
    t.team_id,
    t.name,
    t.avatar_path,
    t.image_version,
    t.scoring_style,
    t.color_argb,
    case when t.owner_id = auth.uid() then 'OWNER' else 'MEMBER' end,
    coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Giocatore'),
    (
      select count(*)::int from public.team_memberships members
      where members.team_id = t.team_id and members.status = 'ACCEPTED'
    )
  from public.teams t
  join public.profiles p on p.user_id = t.owner_id
  where auth.uid() is not null and not t.archived
    and (
      t.owner_id = auth.uid()
      or exists (
        select 1 from public.team_memberships mine
        where mine.team_id = t.team_id and mine.user_id = auth.uid()
          and mine.status = 'ACCEPTED'
      )
    )
  order by t.updated_at desc;
$$;

-- ============================================================ secure invites
alter table public.match_proposals
  add column if not exists linked_match_id text;
create unique index if not exists match_proposals_linked_pair_unique
  on public.match_proposals(creator_id, receiver_id, linked_match_id)
  where linked_match_id is not null;

-- Social actions are RPC-only: this keeps recipient validation, blocking and
-- anti-spam enforcement server-side instead of trusting a client insert.
with ranked as (
  select proposal_id,
         row_number() over (
           partition by least(creator_id, receiver_id),
                        greatest(creator_id, receiver_id)
           order by created_at desc, proposal_id desc
         ) as rn
  from public.match_proposals
  where status = 'OPEN' and linked_match_id is null and receiver_id is not null
)
update public.match_proposals p
set status = 'CANCELLED'
from ranked r
where p.proposal_id = r.proposal_id and r.rn > 1;

create unique index if not exists match_proposals_open_pair_unique
  on public.match_proposals(
    least(creator_id, receiver_id), greatest(creator_id, receiver_id)
  )
  where status = 'OPEN' and linked_match_id is null and receiver_id is not null;

drop policy if exists "proposal participants read" on public.match_proposals;
create policy "proposal participants read" on public.match_proposals
  for select using (auth.uid() in (creator_id, receiver_id));
drop policy if exists "proposal create" on public.match_proposals;
drop policy if exists "proposal owner update" on public.match_proposals;
drop policy if exists "team join create" on public.team_join_requests;
drop policy if exists "team join update" on public.team_join_requests;

create or replace function public.send_match_proposal(
  p_receiver_id uuid,
  p_message text default '',
  p_level_hint text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_rate_id bigint;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'auth_required'); end if;
  if p_receiver_id is null or p_receiver_id = v_uid then
    return jsonb_build_object('ok', false, 'error', 'invalid_receiver');
  end if;
  if char_length(coalesce(p_message, '')) > 500
     or char_length(coalesce(p_level_hint, '')) > 40 then
    return jsonb_build_object('ok', false, 'error', 'message_too_long');
  end if;
  if (
    select count(*) from public.security_rate_events e
    where e.actor_id = v_uid and e.action = 'MATCH_PROPOSAL'
      and e.created_at > now() - interval '1 hour'
  ) >= 20 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  insert into public.security_rate_events(actor_id, action, target_hash)
  values (
    v_uid, 'MATCH_PROPOSAL',
    encode(extensions.digest(p_receiver_id::text, 'sha256'), 'hex')
  ) returning event_id into v_rate_id;
  if exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = v_uid and b.blocked_id = p_receiver_id)
       or (b.blocker_id = p_receiver_id and b.blocked_id = v_uid)
  ) or not exists (
    select 1 from public.profiles p
    where p.user_id = p_receiver_id and p.social_enabled
      and p.map_visibility <> 'HIDDEN'
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_available');
  end if;

  update public.match_proposals
  set message = left(coalesce(p_message, ''), 500),
      level_hint = left(coalesce(p_level_hint, ''), 40)
  where status = 'OPEN' and linked_match_id is null
    and least(creator_id, receiver_id) = least(v_uid, p_receiver_id)
    and greatest(creator_id, receiver_id) = greatest(v_uid, p_receiver_id)
  returning proposal_id into v_id;
  if v_id is null then
    begin
      insert into public.match_proposals(
        creator_id, receiver_id, message, level_hint
      ) values (
        v_uid, p_receiver_id, left(coalesce(p_message, ''), 500),
        left(coalesce(p_level_hint, ''), 40)
      ) returning proposal_id into v_id;
    exception when unique_violation then
      select proposal_id into v_id from public.match_proposals
      where status = 'OPEN' and linked_match_id is null
        and least(creator_id, receiver_id) = least(v_uid, p_receiver_id)
        and greatest(creator_id, receiver_id) = greatest(v_uid, p_receiver_id)
      limit 1;
    end;
  end if;
  update public.security_rate_events set success = true where event_id = v_rate_id;
  return jsonb_build_object('ok', true, 'proposalId', v_id, 'status', 'OPEN');
end;
$$;

create or replace function public.send_team_join_request(
  p_owner_id uuid,
  p_message text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_rate_id bigint;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'auth_required'); end if;
  if p_owner_id is null or p_owner_id = v_uid then
    return jsonb_build_object('ok', false, 'error', 'invalid_receiver');
  end if;
  if char_length(coalesce(p_message, '')) > 500 then
    return jsonb_build_object('ok', false, 'error', 'message_too_long');
  end if;
  if (
    select count(*) from public.security_rate_events e
    where e.actor_id = v_uid and e.action = 'TEAM_REQUEST'
      and e.created_at > now() - interval '1 hour'
  ) >= 12 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  insert into public.security_rate_events(actor_id, action, target_hash)
  values (
    v_uid, 'TEAM_REQUEST',
    encode(extensions.digest(p_owner_id::text, 'sha256'), 'hex')
  ) returning event_id into v_rate_id;
  if exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = v_uid and b.blocked_id = p_owner_id)
       or (b.blocker_id = p_owner_id and b.blocked_id = v_uid)
  ) or not exists (
    select 1 from public.profiles p
    where p.user_id = p_owner_id and p.social_enabled
      and p.map_visibility <> 'HIDDEN'
  ) then
    return jsonb_build_object('ok', false, 'error', 'not_available');
  end if;
  insert into public.team_join_requests(
    team_owner_id, requester_id, message, status, created_at
  ) values (
    p_owner_id, v_uid, left(coalesce(p_message, ''), 500), 'PENDING', now()
  )
  on conflict (team_owner_id, requester_id) do update set
    message = excluded.message, status = 'PENDING', created_at = now()
  returning request_id into v_id;
  update public.security_rate_events set success = true where event_id = v_rate_id;
  return jsonb_build_object('ok', true, 'requestId', v_id, 'status', 'PENDING');
end;
$$;

create or replace function public.respond_social_item(
  p_kind text,
  p_item_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_status text := case when p_accept then 'ACCEPTED' else 'DECLINED' end;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'auth_required'); end if;
  if p_kind = 'proposal' then
    update public.match_proposals set status = v_status
    where proposal_id = p_item_id and receiver_id = auth.uid() and status = 'OPEN';
  elsif p_kind = 'team' then
    update public.team_join_requests set status = v_status
    where request_id = p_item_id and team_owner_id = auth.uid() and status = 'PENDING';
  else
    return jsonb_build_object('ok', false, 'error', 'invalid_kind');
  end if;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'request_not_available');
  end if;
  return jsonb_build_object('ok', true, 'status', v_status);
end;
$$;

create table if not exists public.invite_tokens (
  invite_id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('FRIEND', 'PROFILE', 'TEAM_JOIN', 'TEAM_LINK', 'MATCH', 'DUO')),
  inviter_id uuid not null references public.profiles(user_id) on delete cascade,
  target_user_id uuid references public.profiles(user_id) on delete cascade,
  team_id uuid references public.teams(team_id) on delete cascade,
  target_team_id uuid references public.teams(team_id) on delete cascade,
  match_id text,
  duo_session_id uuid references public.duo_sessions(session_id) on delete cascade,
  token_hash text not null unique,
  code_hash text not null unique,
  token_hint text not null,
  expires_at timestamptz not null,
  max_uses int not null default 1 check (max_uses between 1 and 20),
  use_count int not null default 0,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.invite_audit (
  audit_id bigint generated always as identity primary key,
  invite_id uuid references public.invite_tokens(invite_id) on delete set null,
  actor_id uuid references public.profiles(user_id) on delete set null,
  action text not null check (action in ('PREVIEW', 'REDEEM', 'REVOKE', 'FAILED')),
  success boolean not null,
  created_at timestamptz not null default now()
);

alter table public.invite_tokens enable row level security;
alter table public.invite_audit enable row level security;
create policy "invite owner read" on public.invite_tokens
  for select using (inviter_id = auth.uid());
create policy "invite audit actor read" on public.invite_audit
  for select using (actor_id = auth.uid());

create or replace function public.invite_hash(p_value text)
returns text
language sql
immutable
security definer
set search_path = public, extensions
as $$ select encode(extensions.digest(trim(p_value), 'sha256'), 'hex'); $$;

create or replace function public.create_invite(
  p_kind text,
  p_team_id uuid default null,
  p_target_team_id uuid default null,
  p_match_id text default null,
  p_duo_session_id uuid default null,
  p_ttl_minutes int default 120,
  p_target_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_token text;
  v_code text;
  v_id uuid;
  v_attempt int := 0;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'auth_required'); end if;
  if p_kind not in ('FRIEND', 'PROFILE', 'TEAM_JOIN', 'TEAM_LINK', 'MATCH', 'DUO') then
    return jsonb_build_object('ok', false, 'error', 'invalid_kind');
  end if;
  if (select count(*) from public.invite_tokens i
      where i.inviter_id = v_uid and i.created_at > now() - interval '1 hour') >= 20 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  if p_kind in ('TEAM_JOIN', 'TEAM_LINK') and not exists (
    select 1 from public.teams t where t.team_id = p_team_id and t.owner_id = v_uid
  ) then return jsonb_build_object('ok', false, 'error', 'team_not_owned'); end if;
  if p_kind = 'DUO' and not exists (
    select 1 from public.duo_sessions s where s.session_id = p_duo_session_id
      and v_uid in (s.creator_id, s.guest_id) and s.status in ('PENDING', 'ACTIVE')
  ) then return jsonb_build_object('ok', false, 'error', 'duo_not_available'); end if;
  if p_kind = 'PROFILE' and not exists (
    select 1 from public.profiles p where p.user_id = p_target_user_id
      and p.user_id <> v_uid and p.social_enabled
      and p.map_visibility = 'PUBLIC'
  ) then return jsonb_build_object('ok', false, 'error', 'profile_not_available'); end if;
  if p_kind = 'MATCH' and char_length(trim(coalesce(p_match_id, ''))) not between 8 and 128 then
    return jsonb_build_object('ok', false, 'error', 'invalid_match');
  end if;

  loop
    v_attempt := v_attempt + 1;
    v_token := encode(extensions.gen_random_bytes(24), 'hex');
    select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
      1 + floor(random() * 32)::int, 1), '') into v_code
    from generate_series(1, 8);
    begin
      insert into public.invite_tokens(
        kind, inviter_id, target_user_id, team_id, target_team_id, match_id, duo_session_id,
        token_hash, code_hash, token_hint, expires_at
      ) values (
        p_kind, v_uid, p_target_user_id, p_team_id, p_target_team_id, p_match_id, p_duo_session_id,
        public.invite_hash(v_token), public.invite_hash(v_code), right(v_token, 6),
        now() + make_interval(mins => least(greatest(p_ttl_minutes, 5), 10080))
      ) returning invite_id into v_id;
      exit;
    exception when unique_violation then
      if v_attempt >= 5 then raise; end if;
    end;
  end loop;
  return jsonb_build_object('ok', true, 'inviteId', v_id, 'token', v_token,
    'code', v_code, 'kind', p_kind,
    'expiresAt', now() + make_interval(mins => least(greatest(p_ttl_minutes, 5), 10080)));
end;
$$;

create or replace function public.preview_invite(p_secret text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv public.invite_tokens;
  v_name text;
  v_team text;
  v_profile_name text;
  v_profile_avatar text;
  v_profile_level text;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'auth_required'); end if;
  if (select count(*) from public.invite_audit a where a.actor_id = auth.uid()
      and a.created_at > now() - interval '10 minutes') >= 30 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  select * into v_inv from public.invite_tokens i
  where i.token_hash = public.invite_hash(p_secret)
     or i.code_hash = public.invite_hash(upper(trim(p_secret)))
  limit 1;
  if not found or v_inv.revoked_at is not null or v_inv.expires_at <= now()
     or v_inv.use_count >= v_inv.max_uses then
    insert into public.invite_audit(actor_id, action, success)
    values (auth.uid(), 'FAILED', false);
    return jsonb_build_object('ok', false, 'error', 'invite_not_available');
  end if;
  select coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Giocatore')
    into v_name from public.profiles p where p.user_id = v_inv.inviter_id;
  select t.name into v_team from public.teams t where t.team_id = v_inv.team_id;
  if v_inv.kind = 'PROFILE' then
    select coalesce(nullif(p.nickname, ''), nullif(p.name, ''), 'Giocatore'),
           p.avatar_url, p.level
      into v_profile_name, v_profile_avatar, v_profile_level
    from public.profiles p
    where p.user_id = v_inv.target_user_id and p.social_enabled
      and p.map_visibility = 'PUBLIC';
    if not found then
      return jsonb_build_object('ok', false, 'error', 'profile_not_available');
    end if;
  end if;
  insert into public.invite_audit(invite_id, actor_id, action, success)
  values (v_inv.invite_id, auth.uid(), 'PREVIEW', true);
  return jsonb_build_object('ok', true, 'inviteId', v_inv.invite_id,
    'kind', v_inv.kind, 'inviterId', v_inv.inviter_id, 'inviterName', v_name,
    'teamId', v_inv.team_id, 'teamName', coalesce(v_team, ''),
    'profileUserId', v_inv.target_user_id,
    'profileName', coalesce(v_profile_name, ''),
    'profileAvatarUrl', v_profile_avatar,
    'profileLevel', coalesce(v_profile_level, ''),
    'matchId', v_inv.match_id, 'duoSessionId', v_inv.duo_session_id,
    'expiresAt', v_inv.expires_at);
end;
$$;

create or replace function public.redeem_invite(p_secret text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv public.invite_tokens;
  v_uid uuid := auth.uid();
  v_duo public.duo_sessions;
  v_my_team text;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'auth_required'); end if;
  if (select count(*) from public.invite_audit a where a.actor_id = v_uid
      and a.action in ('REDEEM', 'FAILED') and a.created_at > now() - interval '10 minutes') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;
  select * into v_inv from public.invite_tokens i
  where i.token_hash = public.invite_hash(p_secret)
     or i.code_hash = public.invite_hash(upper(trim(p_secret)))
  for update;
  if not found or v_inv.revoked_at is not null or v_inv.expires_at <= now()
     or v_inv.use_count >= v_inv.max_uses or v_inv.inviter_id = v_uid then
    insert into public.invite_audit(actor_id, action, success)
    values (v_uid, 'FAILED', false);
    return jsonb_build_object('ok', false, 'error', 'invite_not_available');
  end if;

  if v_inv.kind = 'FRIEND' then
    insert into public.social_contact_requests(
      requester_id, receiver_id, message, status, accepted_at
    ) values (
      v_inv.inviter_id, v_uid, 'Invito RallyMate confermato', 'ACCEPTED', now()
    )
    on conflict do nothing;
    update public.social_contact_requests
    set status = 'ACCEPTED', accepted_at = now(), updated_at = now()
    where least(requester_id, receiver_id) = least(v_uid, v_inv.inviter_id)
      and greatest(requester_id, receiver_id) = greatest(v_uid, v_inv.inviter_id);
  elsif v_inv.kind = 'PROFILE' then
    if not exists (
      select 1 from public.profiles p where p.user_id = v_inv.target_user_id
        and p.social_enabled and p.map_visibility = 'PUBLIC'
    ) then
      return jsonb_build_object('ok', false, 'error', 'profile_not_available');
    end if;
  elsif v_inv.kind = 'MATCH' then
    insert into public.match_proposals(
      creator_id, receiver_id, message, status, linked_match_id
    ) values (
      v_inv.inviter_id, v_uid, 'Invito partita RallyMate confermato',
      'ACCEPTED', v_inv.match_id
    ) on conflict (creator_id, receiver_id, linked_match_id)
      where linked_match_id is not null
      do update set status = 'ACCEPTED';
  elsif v_inv.kind = 'TEAM_JOIN' then
    insert into public.team_memberships(team_id, user_id, member_role, status, joined_at)
    values (v_inv.team_id, v_uid, 'MEMBER', 'ACCEPTED', now())
    on conflict (team_id, user_id) do update set status = 'ACCEPTED', joined_at = now();
  elsif v_inv.kind = 'TEAM_LINK' then
    if not exists (select 1 from public.teams t where t.team_id = v_inv.target_team_id and t.owner_id = v_uid) then
      return jsonb_build_object('ok', false, 'error', 'target_team_not_owned');
    end if;
    insert into public.team_connections(team_low, team_high, connected_by)
    values (least(v_inv.team_id, v_inv.target_team_id), greatest(v_inv.team_id, v_inv.target_team_id), v_uid)
    on conflict do nothing;
  elsif v_inv.kind = 'DUO' then
    if not public.has_duo_access(v_uid) then
      return jsonb_build_object('ok', false, 'error', 'premium_required');
    end if;
    select * into v_duo from public.duo_sessions
    where session_id = v_inv.duo_session_id for update;
    if not found or v_duo.status not in ('PENDING', 'ACTIVE')
       or v_duo.code_expires_at <= now()
       or (v_duo.guest_id is not null and v_duo.guest_id <> v_uid) then
      return jsonb_build_object('ok', false, 'error', 'duo_not_available');
    end if;
    v_my_team := case v_duo.creator_team when 'TEAM_A' then 'TEAM_B' else 'TEAM_A' end;
    if v_duo.creator_id = v_uid then
      v_my_team := v_duo.creator_team;
    else
      update public.duo_sessions set guest_id = v_uid, guest_team = v_my_team,
        status = 'ACTIVE', updated_at = now()
      where session_id = v_duo.session_id;
    end if;
  end if;

  update public.invite_tokens set use_count = use_count + 1 where invite_id = v_inv.invite_id;
  insert into public.invite_audit(invite_id, actor_id, action, success)
  values (v_inv.invite_id, v_uid, 'REDEEM', true);
  return jsonb_build_object('ok', true, 'kind', v_inv.kind,
    'profileUserId', v_inv.target_user_id,
    'teamId', v_inv.team_id, 'matchId', v_inv.match_id,
    'duoSessionId', v_inv.duo_session_id,
    'format', case when v_inv.kind = 'DUO' then v_duo.format_json else null end,
    'myTeam', case when v_inv.kind = 'DUO' then v_my_team else null end);
end;
$$;

create or replace function public.revoke_invite(p_invite_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.invite_tokens set revoked_at = now()
  where invite_id = p_invite_id and inviter_id = auth.uid() and revoked_at is null;
  if found then
    insert into public.invite_audit(invite_id, actor_id, action, success)
    values (p_invite_id, auth.uid(), 'REVOKE', true);
    return true;
  end if;
  return false;
end;
$$;

-- ============================================================ Duo hardening
-- The original MVP functions predated explicit Data API grants. Re-declare
-- them here so Premium checks, rate limits and caller scoping are enforced on
-- both legacy short-code joins and the newer signed invite flow.
create or replace function public.has_duo_access(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (uid = auth.uid() or auth.role() = 'service_role')
    and exists (
      select 1 from public.profiles p
      where p.user_id = uid
        and (
          p.plan in ('plus', 'pro', 'coach')
          or p.premium_override
          or p.account_role in ('admin', 'super_admin')
        )
    ),
    false
  );
$$;

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
  where s.session_id = sid
    and (uid = auth.uid() or auth.role() = 'service_role');
$$;

create or replace function public.duo_create_session(
  p_match_id text,
  p_format jsonb,
  p_team text default 'TEAM_A'
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
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  if not public.has_duo_access(v_uid) then
    return jsonb_build_object('ok', false, 'error', 'premium_required');
  end if;
  if p_team not in ('TEAM_A', 'TEAM_B')
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
        match_id, format_json, join_code, creator_id, creator_team
      ) values (
        trim(p_match_id), coalesce(p_format, '{}'::jsonb), v_code, v_uid, p_team
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
    'status', 'PENDING'
  );
end;
$$;

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
    'status', 'ACTIVE'
  );
end;
$$;

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
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'auth_required');
  end if;
  select * into v_session from public.duo_sessions
  where session_id = p_session_id for update;
  if not found or v_uid not in (v_session.creator_id, v_session.guest_id) then
    return jsonb_build_object('ok', false, 'error', 'session_not_available');
  end if;
  if p_status = 'CANCELLED'
     and v_session.status = 'PENDING'
     and v_session.creator_id = v_uid
     and v_session.guest_id is null then
    update public.duo_sessions set status = 'CANCELLED', updated_at = now()
    where session_id = p_session_id;
  elsif p_status = 'COMPLETED' and v_session.status = 'ACTIVE' then
    update public.duo_sessions set status = 'COMPLETED', updated_at = now()
    where session_id = p_session_id;
  elsif p_status = v_session.status then
    null;
  else
    return jsonb_build_object('ok', false, 'error', 'invalid_transition');
  end if;
  return jsonb_build_object('ok', true, 'status', p_status);
end;
$$;

-- Every uploaded event is attributable to the authenticated participant and
-- their assigned team. SCORE_EDITED is deliberately excluded in Duo Mode:
-- unilateral full-score edits would let one watch rewrite the other team.
drop policy if exists "duo events insert own team" on public.duo_events;
create policy "duo events insert own team" on public.duo_events
  for insert with check (
    auth.uid() = source_user_id
    and source_team_id = public.duo_team_of(session_id, auth.uid())
    and exists (
      select 1 from public.duo_sessions s
      where s.session_id = duo_events.session_id
        and s.match_id = duo_events.match_id
        and auth.uid() in (s.creator_id, s.guest_id)
        and s.status in ('PENDING', 'ACTIVE')
    )
    and (
      (type = 'POINT_TEAM_A' and team_id = 'TEAM_A'
        and public.duo_team_of(session_id, auth.uid()) = 'TEAM_A')
      or (type = 'POINT_TEAM_B' and team_id = 'TEAM_B'
        and public.duo_team_of(session_id, auth.uid()) = 'TEAM_B')
      or (type = 'UNDO'
        and team_id = public.duo_team_of(session_id, auth.uid()))
      or type in (
        'MATCH_STARTED', 'MATCH_PAUSED', 'MATCH_RESUMED', 'MATCH_COMPLETED',
        'DEVICE_JOINED_MATCH', 'DEVICE_LEFT_MATCH', 'TEAM_CONFIRMED'
      )
    )
  );

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'duo_events_event_id_size'
  ) then
    alter table public.duo_events add constraint duo_events_event_id_size
      check (char_length(event_id) between 8 and 128) not valid;
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'duo_events_source_device_valid'
  ) then
    alter table public.duo_events add constraint duo_events_source_device_valid
      check (source_device in ('PHONE', 'APPLE_WATCH', 'WEAR_OS')) not valid;
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'duo_events_source_method_valid'
  ) then
    alter table public.duo_events add constraint duo_events_source_method_valid
      check (source_method in ('TAP', 'BLIND_TAP', 'VOICE', 'MANUAL_EDIT', 'AUTO')) not valid;
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'duo_events_payload_size'
  ) then
    alter table public.duo_events add constraint duo_events_payload_size
      check (octet_length(coalesce(payload, '{}'::jsonb)::text) <= 16384) not valid;
  end if;
end $$;

-- ============================================================ private media
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('team-avatars', 'team-avatars', false, 2097152,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = 2097152,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "team avatar readable by participants" on storage.objects
  for select to authenticated using (
    bucket_id = 'team-avatars' and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.teams t
        where t.team_id::text = (storage.foldername(name))[2]
          and (t.visibility = 'PUBLIC' or exists (
            select 1 from public.team_memberships m
            where m.team_id = t.team_id and m.user_id = auth.uid() and m.status = 'ACCEPTED'
          ))
      )
    )
  );
create policy "team avatar owner insert" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'team-avatars'
    and public.has_cloud_media_access()
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (select 1 from public.teams t
      where t.team_id::text = (storage.foldername(name))[2] and t.owner_id = auth.uid())
  );
create policy "team avatar owner update" on storage.objects
  for update to authenticated using (
    bucket_id = 'team-avatars' and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'team-avatars' and public.has_cloud_media_access()
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "team avatar owner delete" on storage.objects
  for delete to authenticated using (
    bucket_id = 'team-avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Explicit API grants are required for projects that no longer auto-expose
-- newly-created tables to the Data API (Supabase April 2026 change).
revoke all on public.user_blocks, public.teams, public.team_memberships,
  public.team_connections, public.invite_tokens, public.invite_audit,
  public.social_reports, public.security_rate_events from anon;
grant select on public.user_blocks, public.teams, public.team_memberships,
  public.team_connections, public.invite_tokens, public.invite_audit,
  public.social_reports to authenticated;

-- RLS does not apply to TRUNCATE and the API roles do not need schema-level
-- REFERENCES/TRIGGER rights. Strip inherited broad grants, then expose only
-- the operations used by the mobile clients.
revoke truncate, references, trigger on all tables in schema public
  from anon, authenticated;
revoke all on public.security_rate_events from authenticated;
revoke all on all sequences in schema public from anon, authenticated;

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.backups to authenticated;
grant select, insert, update, delete on public.wrapped_cards to authenticated;
grant select, insert, update on public.coach_profiles to authenticated;
grant select, insert, update, delete on public.coach_packages to authenticated;
grant select on public.coach_purchases to authenticated;
grant select, insert, update on public.coach_assignments to authenticated;
grant select on public.assistant_queries to authenticated;
grant select on public.rules_faq to anon, authenticated;
grant select on public.social_contact_requests to authenticated;
grant select on public.match_proposals to authenticated;
grant select on public.team_join_requests to authenticated;
grant select on public.duo_sessions to authenticated;
grant select, insert on public.duo_events to authenticated;
grant usage, select on sequence public.duo_events_seq_seq to authenticated;

-- PostgreSQL grants EXECUTE to PUBLIC by default. Start closed and explicitly
-- expose only authenticated client RPCs; service_role/owners retain access.
revoke execute on all functions in schema public from public;

do $$
declare f regprocedure;
begin
  foreach f in array array[
    'public.discover_social_players(int)'::regprocedure,
    'public.social_player_profile(uuid)'::regprocedure,
    'public.send_friend_request(uuid,text)'::regprocedure,
    'public.respond_friend_request(uuid,boolean)'::regprocedure,
    'public.cancel_friend_request(uuid)'::regprocedure,
    'public.remove_friend(uuid)'::regprocedure,
    'public.block_user(uuid)'::regprocedure,
    'public.unblock_user(uuid)'::regprocedure,
    'public.social_relationships()'::regprocedure,
    'public.social_inbox()'::regprocedure,
    'public.blocked_users()'::regprocedure,
    'public.report_social_user(uuid,text,text)'::regprocedure,
    'public.send_match_proposal(uuid,text,text)'::regprocedure,
    'public.send_team_join_request(uuid,text)'::regprocedure,
    'public.respond_social_item(text,uuid,boolean)'::regprocedure,
    'public.has_cloud_media_access()'::regprocedure,
    'public.upsert_cloud_team(text,text,text,bigint,text)'::regprocedure,
    'public.set_team_avatar(uuid,text)'::regprocedure,
    'public.my_cloud_teams()'::regprocedure,
    'public.create_invite(text,uuid,uuid,text,uuid,int,uuid)'::regprocedure,
    'public.preview_invite(text)'::regprocedure,
    'public.redeem_invite(text)'::regprocedure,
    'public.revoke_invite(uuid)'::regprocedure,
    'public.has_duo_access(uuid)'::regprocedure,
    'public.duo_team_of(uuid,uuid)'::regprocedure,
    'public.duo_create_session(text,jsonb,text)'::regprocedure,
    'public.duo_join_session(text)'::regprocedure,
    'public.duo_set_session_status(uuid,text)'::regprocedure
  ] loop
    execute format('revoke all on function %s from public', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

revoke all on function public.invite_hash(text) from public;

comment on table public.invite_tokens is
  'Only SHA-256 hashes are stored. Raw invite tokens/codes are returned once.';
comment on column public.profiles.home_area is
  'Approximate user-selected area only; never exact coordinates.';
