-- RallyMate — schema cloud minimo (PRD 9.3/9.4).
--
-- Filosofia costi: il free tier vive sul telefono. Il cloud contiene SOLO
-- ciò che serve a: account, backup premium, link pubblici recap, coach
-- marketplace, assistant premium. Niente eventi-partita per utenti free.

-- ============================================================ profiles
create table public.profiles (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  name         text not null default '',
  nickname     text not null default '',
  avatar_url   text,
  dominant_hand text not null default 'RIGHT',
  preferred_role text not null default 'UNDEFINED'
    check (preferred_role in ('LEFT','RIGHT','FLEX','UNDEFINED')),
  level        text not null default 'INTERMEDIATE',
  privacy      text not null default 'PRIVATE'
    check (privacy in ('PUBLIC','FRIENDS','PRIVATE')),
  plan         text not null default 'free'
    check (plan in ('free','plus','pro','coach')),
  -- Scritto SOLO dal webhook RevenueCat (service role), mai dal client.
  plan_expires_at timestamptz,
  created_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "own profile read" on public.profiles
  for select using (auth.uid() = user_id or privacy = 'PUBLIC');
create policy "own profile write" on public.profiles
  for update using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    -- il piano non è modificabile dal client
    and plan = (select p.plan from public.profiles p where p.user_id = auth.uid())
  );
create policy "own profile insert" on public.profiles
  for insert with check (auth.uid() = user_id);

-- ============================================================ backup (Plus+)
-- Snapshot compressi del DB locale: 1 riga per device, upsert.
-- Molto più economico di una replica riga-per-riga degli eventi.
create table public.backups (
  user_id     uuid not null references public.profiles (user_id) on delete cascade,
  device_id   text not null,
  payload     jsonb not null,           -- export compresso del DB locale
  schema_ver  int  not null default 1,
  updated_at  timestamptz not null default now(),
  primary key (user_id, device_id)
);

alter table public.backups enable row level security;

create policy "own backup" on public.backups
  for all using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid() and p.plan in ('plus','pro','coach')
    )
  );

-- ============================================================ recap pubblici
-- Link condivisibili "Rally Wrapped" (PRD G5): pagina web leggera per card.
create table public.wrapped_cards (
  card_id     uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (user_id) on delete cascade,
  slug        text not null unique,     -- breve, per URL /r/{slug}
  type        text not null default 'MATCH'
    check (type in ('MATCH','WEEKLY','MONTHLY','TEAM','SEASON','TOURNAMENT')),
  payload     jsonb not null,           -- dati card (risultato, frasi, stats)
  image_url   text,                     -- opzionale: PNG su R2/storage
  privacy     text not null default 'PUBLIC'
    check (privacy in ('PUBLIC','UNLISTED','PRIVATE')),
  view_count  int not null default 0,
  created_at  timestamptz not null default now()
);

alter table public.wrapped_cards enable row level security;

create policy "own cards" on public.wrapped_cards
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- La lettura pubblica passa SOLO dalla edge function `recap` (service role),
-- che rispetta privacy + incrementa view_count: nessuna select anonima diretta.

-- ============================================================ coach (PRD I)
create table public.coach_profiles (
  coach_id    uuid primary key references public.profiles (user_id) on delete cascade,
  bio         text not null default '',
  club        text not null default '',
  certifications text[] not null default '{}',
  specializations text[] not null default '{}',
  verified    boolean not null default false,   -- badge, assegnato da admin
  rating_avg  numeric(3,2) not null default 0,
  rating_count int not null default 0,
  visible     boolean not null default true,
  created_at  timestamptz not null default now()
);

alter table public.coach_profiles enable row level security;

create policy "coach public read" on public.coach_profiles
  for select using (visible = true or auth.uid() = coach_id);
create policy "coach own write" on public.coach_profiles
  for insert with check (
    auth.uid() = coach_id
    and exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid() and p.plan = 'coach'
    )
  );
create policy "coach own update" on public.coach_profiles
  for update using (auth.uid() = coach_id) with check (auth.uid() = coach_id);

create table public.coach_packages (
  package_id  uuid primary key default gen_random_uuid(),
  coach_id    uuid not null references public.coach_profiles (coach_id) on delete cascade,
  title       text not null,
  description text not null default '',
  type        text not null
    check (type in ('DIGITAL_PROGRAM','WEEKLY_PLAN','MONTHLY_PLAN',
                    'PROGRESS_REVIEW','PAIR_COACHING','TOURNAMENT_PREP',
                    'LIVE_1TO1','GROUP_LESSON','ACADEMY')),
  price_cents int not null check (price_cents >= 0),
  currency    text not null default 'EUR',
  -- Commissione per tipo (PRD I3): 15% digitale, 10% 1:1, 5-8% academy.
  commission_rate numeric(4,3) not null default 0.150,
  includes_digital_content boolean not null default true,
  includes_live_session    boolean not null default false,
  status      text not null default 'ACTIVE'
    check (status in ('DRAFT','ACTIVE','ARCHIVED')),
  created_at  timestamptz not null default now()
);

alter table public.coach_packages enable row level security;

create policy "packages public read" on public.coach_packages
  for select using (status = 'ACTIVE' or auth.uid() = coach_id);
create policy "packages coach write" on public.coach_packages
  for all using (auth.uid() = coach_id) with check (auth.uid() = coach_id);

-- Acquisti: scritti SOLO dalla edge function coach-checkout dopo la
-- validazione IAP (service role). Il client legge i propri.
create table public.coach_purchases (
  purchase_id uuid primary key default gen_random_uuid(),
  package_id  uuid not null references public.coach_packages (package_id),
  coach_id    uuid not null references public.coach_profiles (coach_id),
  player_id   uuid not null references public.profiles (user_id),
  price_cents int not null,
  commission_cents int not null,        -- trattenuta piattaforma
  coach_net_cents  int not null,        -- accredito coach
  store        text not null check (store in ('APP_STORE','PLAY_STORE','EXTERNAL')),
  store_tx_id  text,                    -- id transazione store (anti-replay)
  status       text not null default 'PAID'
    check (status in ('PAID','REFUNDED','DISPUTED')),
  created_at   timestamptz not null default now(),
  unique (store, store_tx_id)
);

alter table public.coach_purchases enable row level security;

create policy "purchases read own" on public.coach_purchases
  for select using (auth.uid() = player_id or auth.uid() = coach_id);

-- Assegnazioni schede (funzionalità anti-bypass, PRD I4: valore solo in-app)
create table public.coach_assignments (
  assignment_id uuid primary key default gen_random_uuid(),
  purchase_id  uuid not null references public.coach_purchases (purchase_id),
  coach_id     uuid not null references public.coach_profiles (coach_id),
  player_id    uuid not null references public.profiles (user_id),
  training_plan jsonb not null default '{}',
  status       text not null default 'ASSIGNED'
    check (status in ('ASSIGNED','IN_PROGRESS','COMPLETED','EXPIRED')),
  progress     jsonb not null default '{}',
  feedback     text not null default '',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.coach_assignments enable row level security;

create policy "assignments coach" on public.coach_assignments
  for all using (auth.uid() = coach_id) with check (auth.uid() = coach_id);
create policy "assignments player read" on public.coach_assignments
  for select using (auth.uid() = player_id);
create policy "assignments player progress" on public.coach_assignments
  for update using (auth.uid() = player_id)
  with check (auth.uid() = player_id);

-- ============================================================ assistant (Pro)
-- Log query LLM: serve per limiti giornalieri, cache e controllo costi
-- (PRD E4 "Controllo costi" + Rischio 2).
create table public.assistant_queries (
  query_id    uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (user_id) on delete cascade,
  match_id    text,
  mode        text not null default 'RULES'
    check (mode in ('RULES','LIVE_MATCH','POST_MATCH','TRAINING')),
  question    text not null,
  question_hash text not null,          -- sha256 normalizzato per cache
  answer      text,
  sources     jsonb not null default '[]',
  model       text,
  cached      boolean not null default false,
  cost_estimate_microusd bigint not null default 0,
  created_at  timestamptz not null default now()
);

create index assistant_queries_user_day
  on public.assistant_queries (user_id, created_at);
create index assistant_queries_cache
  on public.assistant_queries (question_hash, created_at);

alter table public.assistant_queries enable row level security;

create policy "assistant read own" on public.assistant_queries
  for select using (auth.uid() = user_id);
-- Insert SOLO via edge function (service role): il client non scrive qui.

-- ============================================================ regolamento
-- FAQ aggiornabile da remoto senza LLM (PRD E2): il client la scarica e la
-- fonde con il dataset locale.
create table public.rules_faq (
  id        text primary key,
  question  text not null,
  answer    text not null,
  keywords  text[] not null default '{}',
  source    text not null,
  example   text,
  lang      text not null default 'it',
  updated_at timestamptz not null default now()
);

alter table public.rules_faq enable row level security;
create policy "rules public read" on public.rules_faq for select using (true);
