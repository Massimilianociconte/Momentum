-- Public domain switch: playmomentum.app -> playmomentum.it.
-- Same two-layer approach as 20260726233000_rebrand_momentum_copy.sql: the
-- previous migration already ran on the remote and may have written the old
-- domain into live function bodies and stored copy.

begin;

-- ---------------------------------------------------------------------------
-- 1. Functions still emitting the old domain
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
  v_def text;
begin
  for r in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
      and p.prokind = 'f'
      and p.prosrc ilike '%playmomentum.app%'
  loop
    v_def := pg_get_functiondef(r.oid);
    v_def := replace(v_def, 'playmomentum.app', 'playmomentum.it');
    execute v_def;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Stored copy that may embed the old domain
-- ---------------------------------------------------------------------------
create or replace function pg_temp.redomain(p_text text)
returns text
language sql
immutable
as $$
  select replace(p_text, 'playmomentum.app', 'playmomentum.it');
$$;

update public.knowledge_topics
set title = pg_temp.redomain(title),
    summary_short = pg_temp.redomain(summary_short),
    summary_extended = pg_temp.redomain(summary_extended),
    watch_summary = pg_temp.redomain(watch_summary),
    answer_blocks = pg_temp.redomain(answer_blocks::text)::jsonb,
    search_text = pg_temp.redomain(search_text),
    updated_at = now()
where title ilike '%playmomentum.app%'
   or summary_short ilike '%playmomentum.app%'
   or summary_extended ilike '%playmomentum.app%'
   or watch_summary ilike '%playmomentum.app%'
   or answer_blocks::text ilike '%playmomentum.app%'
   or search_text ilike '%playmomentum.app%';

update public.knowledge_clusters
set title = pg_temp.redomain(title),
    description = pg_temp.redomain(description)
where title ilike '%playmomentum.app%'
   or description ilike '%playmomentum.app%';

-- Optional tables: present only in some environments.
do $$
begin
  if to_regclass('public.padel_rules') is not null then
    update public.padel_rules
    set user_question = pg_temp.redomain(user_question),
        short_answer = pg_temp.redomain(short_answer),
        detailed_answer = pg_temp.redomain(detailed_answer)
    where user_question ilike '%playmomentum.app%'
       or short_answer ilike '%playmomentum.app%'
       or detailed_answer ilike '%playmomentum.app%';
  end if;

  if to_regclass('public.rule_faqs_v2') is not null then
    update public.rule_faqs_v2
    set question = pg_temp.redomain(question),
        answer_short = pg_temp.redomain(answer_short),
        answer_long = pg_temp.redomain(answer_long),
        watch_answer = pg_temp.redomain(watch_answer)
    where question ilike '%playmomentum.app%'
       or answer_short ilike '%playmomentum.app%'
       or answer_long ilike '%playmomentum.app%'
       or watch_answer ilike '%playmomentum.app%';
  end if;
exception when others then
  raise notice 'domain switch partial: %', sqlerrm;
end $$;

update public.push_outbox
set title = pg_temp.redomain(title),
    body = pg_temp.redomain(body)
where title ilike '%playmomentum.app%' or body ilike '%playmomentum.app%';

-- Cached assistant answers are replayed verbatim on cache hits.
update public.assistant_queries
set answer = pg_temp.redomain(answer),
    sources = pg_temp.redomain(sources::text)::jsonb
where answer ilike '%playmomentum.app%' or sources::text ilike '%playmomentum.app%';

drop function pg_temp.redomain(text);

commit;
