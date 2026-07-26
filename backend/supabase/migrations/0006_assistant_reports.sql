-- In-app reporting for generated assistant answers.
-- Google Play AI policy expects a native way to flag problematic AI content.

create table if not exists public.assistant_reports (
  report_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (user_id) on delete cascade,
  mode text not null default 'RULES'
    check (mode in ('RULES', 'LIVE_MATCH', 'POST_MATCH', 'TRAINING', 'APP_HELP')),
  question text not null default '',
  answer text not null,
  reason text not null default 'other'
    check (reason in (
      'offensive_or_unsafe',
      'dangerous_advice',
      'wrong_rule',
      'privacy_issue',
      'other'
    )),
  details text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists assistant_reports_user_created_idx
  on public.assistant_reports (user_id, created_at desc);

create index if not exists assistant_reports_reason_created_idx
  on public.assistant_reports (reason, created_at desc);

alter table public.assistant_reports enable row level security;

drop policy if exists "assistant reports read own" on public.assistant_reports;
create policy "assistant reports read own"
  on public.assistant_reports
  for select using (auth.uid() = user_id);

comment on table public.assistant_reports is
  'User reports for AI assistant answers. Inserts happen through the assistant edge function.';
