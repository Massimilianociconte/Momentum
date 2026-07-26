-- RallyMate social-light (PRD K).
--
-- Obiettivo: trovare giocatori e creare richieste senza trasformare il free
-- tier in un social costoso. Nessun feed, video o posizione precisa pubblica.

alter table public.profiles
  add column if not exists home_area text not null default '',
  add column if not exists play_frequency text not null default '',
  add column if not exists availability text not null default 'FLEX'
    check (availability in ('TODAY','EVENING','WEEKEND','FLEX','HIDDEN')),
  add column if not exists style_tags text[] not null default '{}',
  add column if not exists skill_score int not null default 60
    check (skill_score between 0 and 100),
  add column if not exists reliability_score int not null default 80
    check (reliability_score between 0 and 100),
  add column if not exists social_enabled boolean not null default false,
  add column if not exists last_basic_sync_at timestamptz;

create table if not exists public.social_contact_requests (
  request_id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles (user_id) on delete cascade,
  receiver_id uuid not null references public.profiles (user_id) on delete cascade,
  message text not null default '',
  status text not null default 'PENDING'
    check (status in ('PENDING','ACCEPTED','DECLINED','CANCELLED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (requester_id, receiver_id)
);

alter table public.social_contact_requests enable row level security;

create policy "contact request participants read"
  on public.social_contact_requests
  for select using (auth.uid() in (requester_id, receiver_id));

create policy "contact request create"
  on public.social_contact_requests
  for insert with check (
    auth.uid() = requester_id
    and requester_id <> receiver_id
    and exists (
      select 1 from public.profiles p
      where p.user_id = receiver_id
        and p.privacy in ('PUBLIC','FRIENDS')
        and p.social_enabled = true
    )
  );

create policy "contact request update receiver"
  on public.social_contact_requests
  for update using (auth.uid() in (requester_id, receiver_id))
  with check (auth.uid() in (requester_id, receiver_id));

create table if not exists public.match_proposals (
  proposal_id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles (user_id) on delete cascade,
  receiver_id uuid references public.profiles (user_id) on delete set null,
  area_label text not null default '',
  proposed_at timestamptz,
  level_hint text not null default '',
  message text not null default '',
  status text not null default 'OPEN'
    check (status in ('OPEN','ACCEPTED','DECLINED','CANCELLED','EXPIRED')),
  created_at timestamptz not null default now()
);

alter table public.match_proposals enable row level security;

create policy "proposal participants read"
  on public.match_proposals
  for select using (
    auth.uid() = creator_id
    or auth.uid() = receiver_id
    or (receiver_id is null and status = 'OPEN')
  );

create policy "proposal create"
  on public.match_proposals
  for insert with check (auth.uid() = creator_id);

create policy "proposal owner update"
  on public.match_proposals
  for update using (auth.uid() in (creator_id, receiver_id))
  with check (auth.uid() in (creator_id, receiver_id));

create table if not exists public.team_join_requests (
  request_id uuid primary key default gen_random_uuid(),
  team_owner_id uuid not null references public.profiles (user_id) on delete cascade,
  requester_id uuid not null references public.profiles (user_id) on delete cascade,
  message text not null default '',
  status text not null default 'PENDING'
    check (status in ('PENDING','ACCEPTED','DECLINED','CANCELLED')),
  created_at timestamptz not null default now(),
  unique (team_owner_id, requester_id)
);

alter table public.team_join_requests enable row level security;

create policy "team join participants read"
  on public.team_join_requests
  for select using (auth.uid() in (team_owner_id, requester_id));

create policy "team join create"
  on public.team_join_requests
  for insert with check (
    auth.uid() = requester_id
    and requester_id <> team_owner_id
  );

create policy "team join update"
  on public.team_join_requests
  for update using (auth.uid() in (team_owner_id, requester_id))
  with check (auth.uid() in (team_owner_id, requester_id));
