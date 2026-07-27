-- Rebrand user-facing copy from Padelandia to Momentum (domain playmomentum.app).
-- Deep link scheme rallymate:// and technical identifiers intentionally unchanged.
--
-- Two layers, mirroring the RallyMate -> Padelandia rebrand chain (20260721*):
--   1. Functions: any public/private function whose body still mentions the old
--      brand is re-created from pg_get_functiondef with the copy replaced, so
--      push/invite text generated server-side switches to Momentum.
--   2. Data: knowledge base, FAQ, queued push rows and cached assistant answers
--      are rewritten in place; search_text stays consistent with visible copy.

begin;

-- ---------------------------------------------------------------------------
-- 1. Functions still emitting the old brand
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
      and p.prosrc ilike '%padelandia%'
  loop
    v_def := pg_get_functiondef(r.oid);
    v_def := replace(v_def, 'padelandia.app', 'playmomentum.app');
    v_def := replace(v_def, 'PADELANDIA', 'MOMENTUM');
    v_def := replace(v_def, 'Padelandia', 'Momentum');
    v_def := replace(v_def, 'padelandia', 'momentum');
    execute v_def;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Stored copy (knowledge base, FAQ, queued push, cached assistant answers)
-- ---------------------------------------------------------------------------
create or replace function pg_temp.rebrand(p_text text)
returns text
language sql
immutable
as $$
  select replace(
    replace(
      replace(
        replace(p_text, 'padelandia.app', 'playmomentum.app'),
        'PADELANDIA', 'MOMENTUM'
      ),
      'Padelandia', 'Momentum'
    ),
    'padelandia', 'momentum'
  );
$$;

update public.knowledge_topics
set title = pg_temp.rebrand(title),
    summary_short = pg_temp.rebrand(summary_short),
    summary_extended = pg_temp.rebrand(summary_extended),
    watch_summary = pg_temp.rebrand(watch_summary),
    answer_blocks = pg_temp.rebrand(answer_blocks::text)::jsonb,
    search_text = pg_temp.rebrand(search_text),
    updated_at = now()
where title ilike '%padelandia%'
   or summary_short ilike '%padelandia%'
   or summary_extended ilike '%padelandia%'
   or watch_summary ilike '%padelandia%'
   or answer_blocks::text ilike '%padelandia%'
   or search_text ilike '%padelandia%';

update public.knowledge_clusters
set title = pg_temp.rebrand(title),
    description = pg_temp.rebrand(description)
where title ilike '%padelandia%'
   or description ilike '%padelandia%';

-- Optional tables: present only in some environments.
do $$
begin
  if to_regclass('public.padel_rules') is not null then
    update public.padel_rules
    set user_question = pg_temp.rebrand(user_question),
        short_answer = pg_temp.rebrand(short_answer),
        detailed_answer = pg_temp.rebrand(detailed_answer)
    where user_question ilike '%padelandia%'
       or short_answer ilike '%padelandia%'
       or detailed_answer ilike '%padelandia%';
  end if;

  if to_regclass('public.rule_faqs_v2') is not null then
    update public.rule_faqs_v2
    set question = pg_temp.rebrand(question),
        answer_short = pg_temp.rebrand(answer_short),
        answer_long = pg_temp.rebrand(answer_long),
        watch_answer = pg_temp.rebrand(watch_answer)
    where question ilike '%padelandia%'
       or answer_short ilike '%padelandia%'
       or answer_long ilike '%padelandia%'
       or watch_answer ilike '%padelandia%';
  end if;
exception when others then
  raise notice 'momentum rebrand partial: %', sqlerrm;
end $$;

-- Still-queued push rows keep the old name otherwise.
update public.push_outbox
set title = pg_temp.rebrand(title),
    body = pg_temp.rebrand(body)
where title ilike '%padelandia%' or body ilike '%padelandia%';

-- Cached assistant answers are replayed verbatim on cache hits: rebrand both
-- the answer text and the source labels.
update public.assistant_queries
set answer = pg_temp.rebrand(answer),
    sources = pg_temp.rebrand(sources::text)::jsonb
where answer ilike '%padelandia%' or sources::text ilike '%padelandia%';

drop function pg_temp.rebrand(text);

commit;
