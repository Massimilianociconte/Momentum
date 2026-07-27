-- Rebrand knowledge base and FAQ seed copy still saying RallyMate.
--
-- The first version of this migration targeted a `body` column that does not
-- exist on public.knowledge_topics (SQLSTATE 42703), so it had never been
-- applicable. It now rewrites the real text columns of the knowledge schema
-- created in 0007_padel_knowledge_base.sql, plus the JSON payloads, and keeps
-- `search_text` consistent with the visible copy.
begin;

update public.knowledge_topics
set title = replace(replace(title, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'),
    summary_short = replace(
      replace(summary_short, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'
    ),
    summary_extended = replace(
      replace(summary_extended, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'
    ),
    watch_summary = replace(
      replace(watch_summary, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'
    ),
    -- answer_blocks is a JSON array: rebrand its textual representation and
    -- cast back, so nested block copy is covered too.
    answer_blocks = replace(
      replace(answer_blocks::text, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'
    )::jsonb,
    search_text = replace(
      replace(search_text, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'
    ),
    updated_at = now()
where title ilike '%RallyMate%'
   or summary_short ilike '%RallyMate%'
   or summary_extended ilike '%RallyMate%'
   or watch_summary ilike '%RallyMate%'
   or answer_blocks::text ilike '%RallyMate%'
   or search_text ilike '%RallyMate%'
   or title ilike '%Rally Pro%'
   or summary_short ilike '%Rally Pro%'
   or summary_extended ilike '%Rally Pro%'
   or watch_summary ilike '%Rally Pro%'
   or answer_blocks::text ilike '%Rally Pro%'
   or search_text ilike '%Rally Pro%';

update public.knowledge_clusters
set title = replace(replace(title, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'),
    description = replace(
      replace(description, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'
    )
where title ilike '%RallyMate%'
   or description ilike '%RallyMate%'
   or title ilike '%Rally Pro%'
   or description ilike '%Rally Pro%';

-- Optional tables: present only in some environments.
do $$
begin
  if to_regclass('public.padel_rules') is not null then
    update public.padel_rules
    set user_question = replace(
          replace(user_question, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'
        ),
        short_answer = replace(
          replace(short_answer, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'
        ),
        detailed_answer = replace(
          replace(detailed_answer, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'
        )
    where user_question ilike '%RallyMate%'
       or short_answer ilike '%RallyMate%'
       or detailed_answer ilike '%RallyMate%'
       or user_question ilike '%Rally Pro%'
       or short_answer ilike '%Rally Pro%'
       or detailed_answer ilike '%Rally Pro%';
  end if;

  if to_regclass('public.rule_faqs_v2') is not null then
    update public.rule_faqs_v2
    set question = replace(
          replace(question, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'
        ),
        answer_short = replace(
          replace(answer_short, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'
        ),
        answer_long = replace(
          replace(answer_long, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'
        ),
        watch_answer = replace(
          replace(watch_answer, 'RallyMate', 'Momentum'), 'Rally Pro', 'Pallino'
        )
    where question ilike '%RallyMate%'
       or answer_short ilike '%RallyMate%'
       or answer_long ilike '%RallyMate%'
       or watch_answer ilike '%RallyMate%'
       or question ilike '%Rally Pro%'
       or answer_short ilike '%Rally Pro%'
       or answer_long ilike '%Rally Pro%'
       or watch_answer ilike '%Rally Pro%';
  end if;
exception when others then
  raise notice 'kb rebrand partial: %', sqlerrm;
end $$;

commit;
