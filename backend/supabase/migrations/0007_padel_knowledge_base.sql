-- RallyMate padel knowledge base.
-- Source-backed, versioned content for static Free assistant answers and Premium RAG retrieval.

create table if not exists public.knowledge_sources (
  source_id text primary key,
  title text not null,
  url text not null,
  source_type text not null check (
    source_type in ('official', 'federal', 'manufacturer', 'editorial', 'coach', 'shop', 'community')
  ),
  reliability smallint not null check (reliability between 1 and 5),
  authority_level text not null,
  accessed_at date not null default current_date,
  published_at date,
  last_reviewed_at date not null default current_date,
  update_cadence text not null default 'quarterly',
  certainty_note text not null,
  citation jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.knowledge_versions (
  version_id text primary key,
  label text not null,
  description text not null,
  effective_date date not null default current_date,
  source_scope text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.knowledge_clusters (
  cluster_id text primary key,
  parent_cluster_id text references public.knowledge_clusters(cluster_id) on delete set null,
  title text not null,
  description text not null,
  subcategories text[] not null default '{}',
  priority_mvp smallint not null default 3 check (priority_mvp between 1 and 5),
  free_available boolean not null default true,
  premium_available boolean not null default true,
  official_source_required boolean not null default false,
  watch_supported boolean not null default true,
  mobile_extended_supported boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.knowledge_tags (
  tag text primary key,
  cluster_id text references public.knowledge_clusters(cluster_id) on delete set null,
  description text not null default ''
);

create table if not exists public.knowledge_topics (
  topic_id text primary key,
  cluster_id text not null references public.knowledge_clusters(cluster_id) on delete restrict,
  version_id text references public.knowledge_versions(version_id) on delete set null,
  title text not null,
  slug text not null unique,
  summary_short text not null,
  summary_extended text not null,
  watch_summary text not null,
  difficulty text not null default 'all' check (difficulty in ('beginner', 'intermediate', 'advanced', 'all')),
  audience_level text[] not null default array['beginner', 'intermediate', 'advanced'],
  free_tier boolean not null default true,
  premium_tier boolean not null default true,
  answer_blocks jsonb not null default '[]'::jsonb check (jsonb_typeof(answer_blocks) = 'array'),
  source_policy text not null default 'source_backed',
  certainty text not null default 'high' check (certainty in ('official', 'high', 'medium', 'indicative', 'conflicting')),
  publish_state text not null default 'published' check (publish_state in ('draft', 'published', 'needs_review', 'archived')),
  search_text text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.knowledge_topic_tags (
  topic_id text not null references public.knowledge_topics(topic_id) on delete cascade,
  tag text not null references public.knowledge_tags(tag) on delete cascade,
  primary key (topic_id, tag)
);

create table if not exists public.knowledge_topic_sources (
  topic_id text not null references public.knowledge_topics(topic_id) on delete cascade,
  source_id text not null references public.knowledge_sources(source_id) on delete restrict,
  evidence_note text not null,
  source_page text,
  confidence text not null default 'high' check (confidence in ('high', 'medium', 'low', 'conflicting')),
  primary key (topic_id, source_id, evidence_note)
);

create table if not exists public.padel_rules (
  topic_id text primary key references public.knowledge_topics(topic_id) on delete cascade,
  rule_number text,
  category text not null,
  user_question text not null,
  short_answer text not null,
  detailed_answer text not null,
  examples jsonb not null default '[]'::jsonb check (jsonb_typeof(examples) = 'array'),
  edge_cases jsonb not null default '[]'::jsonb check (jsonb_typeof(edge_cases) = 'array'),
  official_source_id text not null references public.knowledge_sources(source_id) on delete restrict
);

create table if not exists public.rule_faqs_v2 (
  faq_id text primary key,
  rule_topic_id text references public.knowledge_topics(topic_id) on delete set null,
  question text not null,
  answer_short text not null,
  answer_long text not null,
  watch_answer text not null,
  tags text[] not null default '{}',
  free_available boolean not null default true,
  premium_available boolean not null default true,
  source_id text not null references public.knowledge_sources(source_id) on delete restrict,
  certainty text not null default 'official' check (certainty in ('official', 'high', 'medium', 'indicative'))
);

create table if not exists public.court_features (
  topic_id text primary key references public.knowledge_topics(topic_id) on delete cascade,
  feature_type text not null,
  technical_description text not null,
  impact_on_play text not null,
  pros jsonb not null default '[]'::jsonb check (jsonb_typeof(pros) = 'array'),
  cons jsonb not null default '[]'::jsonb check (jsonb_typeof(cons) = 'array'),
  adaptation_tips jsonb not null default '[]'::jsonb check (jsonb_typeof(adaptation_tips) = 'array'),
  official_reference text,
  source_id text not null references public.knowledge_sources(source_id) on delete restrict
);

create table if not exists public.equipment_categories (
  category_id text primary key,
  title text not null,
  description text not null,
  free_available boolean not null default true,
  premium_available boolean not null default true
);

create table if not exists public.racket_types (
  type_id text primary key,
  topic_id text references public.knowledge_topics(topic_id) on delete set null,
  title text not null,
  shape text,
  balance text,
  core text,
  frame_material text,
  face_material text,
  surface text,
  recommended_level text not null default 'all',
  recommended_style text not null,
  impact_scores jsonb not null default '{}'::jsonb,
  pros jsonb not null default '[]'::jsonb check (jsonb_typeof(pros) = 'array'),
  cons jsonb not null default '[]'::jsonb check (jsonb_typeof(cons) = 'array'),
  faqs jsonb not null default '[]'::jsonb check (jsonb_typeof(faqs) = 'array'),
  source_id text not null references public.knowledge_sources(source_id) on delete restrict,
  certainty text not null default 'high' check (certainty in ('high', 'medium', 'indicative'))
);

create table if not exists public.racket_models (
  model_id text primary key,
  brand text not null,
  model text not null,
  model_year text,
  shape text,
  weight_declared text,
  balance_declared text,
  frame_material text,
  face_material text,
  core_material text,
  surface text,
  thickness_mm numeric,
  level_recommended text,
  style_recommended text,
  price_amount numeric,
  price_currency text,
  technical_specs jsonb not null default '{}'::jsonb,
  reliability_notes text not null,
  manufacturer_source_id text not null references public.knowledge_sources(source_id) on delete restrict,
  secondary_source_ids text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.racket_comparisons (
  comparison_id text primary key,
  title text not null,
  model_a_id text references public.racket_models(model_id) on delete set null,
  model_b_id text references public.racket_models(model_id) on delete set null,
  type_a_id text references public.racket_types(type_id) on delete set null,
  type_b_id text references public.racket_types(type_id) on delete set null,
  criteria_weights jsonb not null default '{}'::jsonb,
  result jsonb not null default '{}'::jsonb,
  deterministic_rule text not null,
  source_policy text not null default 'structured_fields_only',
  premium_available boolean not null default true
);

create table if not exists public.ball_types (
  ball_type_id text primary key,
  topic_id text references public.knowledge_topics(topic_id) on delete set null,
  title text not null,
  pressure_type text,
  diameter_cm_range text,
  weight_g_range text,
  rebound_cm_range text,
  pressure_spec text,
  behavior_notes text not null,
  official_standard boolean not null default false,
  source_id text not null references public.knowledge_sources(source_id) on delete restrict,
  certainty text not null default 'official' check (certainty in ('official', 'high', 'medium', 'indicative'))
);

create table if not exists public.technique_topics (
  topic_id text primary key references public.knowledge_topics(topic_id) on delete cascade,
  shot_type text not null,
  role text not null default 'any',
  user_level text not null default 'all',
  game_context text not null,
  common_errors jsonb not null default '[]'::jsonb check (jsonb_typeof(common_errors) = 'array'),
  linked_drills jsonb not null default '[]'::jsonb check (jsonb_typeof(linked_drills) = 'array'),
  rallymate_metrics text[] not null default '{}',
  source_id text not null references public.knowledge_sources(source_id) on delete restrict
);

create table if not exists public.tactical_topics (
  topic_id text primary key references public.knowledge_topics(topic_id) on delete cascade,
  tactic_type text not null,
  role text not null default 'pair',
  situation text not null,
  principles jsonb not null default '[]'::jsonb check (jsonb_typeof(principles) = 'array'),
  common_mistakes jsonb not null default '[]'::jsonb check (jsonb_typeof(common_mistakes) = 'array'),
  rallymate_metrics text[] not null default '{}',
  source_id text not null references public.knowledge_sources(source_id) on delete restrict
);

create table if not exists public.training_knowledge (
  training_id text primary key,
  topic_id text references public.knowledge_topics(topic_id) on delete set null,
  objective text not null,
  duration_minutes integer not null check (duration_minutes between 1 and 240),
  level text not null check (level in ('beginner', 'intermediate', 'advanced', 'all')),
  role text not null default 'any',
  materials text[] not null default '{}',
  description text not null,
  steps jsonb not null default '[]'::jsonb check (jsonb_typeof(steps) = 'array'),
  mistakes_to_avoid jsonb not null default '[]'::jsonb check (jsonb_typeof(mistakes_to_avoid) = 'array'),
  metric_to_watch text not null,
  analytics_links text[] not null default '{}',
  source_id text not null references public.knowledge_sources(source_id) on delete restrict,
  free_available boolean not null default true,
  premium_available boolean not null default true
);

create table if not exists public.assistant_citations (
  citation_id uuid primary key default gen_random_uuid(),
  topic_id text references public.knowledge_topics(topic_id) on delete cascade,
  source_id text not null references public.knowledge_sources(source_id) on delete restrict,
  quote_snippet text,
  paraphrase text not null,
  url text not null,
  accessed_at date not null default current_date,
  created_at timestamptz not null default now()
);

create table if not exists public.knowledge_embeddings (
  topic_id text primary key references public.knowledge_topics(topic_id) on delete cascade,
  embedding_model text not null,
  embedding_dimensions integer not null,
  embedding_values double precision[],
  content_hash text not null,
  generated_at timestamptz not null default now()
);

create index if not exists knowledge_topics_cluster_idx on public.knowledge_topics(cluster_id);
create index if not exists knowledge_topics_publish_idx on public.knowledge_topics(publish_state, free_tier, premium_tier);
create index if not exists knowledge_topics_search_idx on public.knowledge_topics using gin (to_tsvector('italian', search_text));
create index if not exists knowledge_topic_tags_tag_idx on public.knowledge_topic_tags(tag);
create index if not exists knowledge_topic_sources_source_idx on public.knowledge_topic_sources(source_id);
create index if not exists rule_faqs_v2_search_idx on public.rule_faqs_v2 using gin (to_tsvector('italian', question || ' ' || answer_short || ' ' || answer_long));
create index if not exists racket_models_brand_idx on public.racket_models(brand, model_year);
create index if not exists training_knowledge_level_idx on public.training_knowledge(level, role);
create unique index if not exists assistant_citations_topic_source_url_idx
  on public.assistant_citations(topic_id, source_id, url, paraphrase);

alter table public.knowledge_sources enable row level security;
alter table public.knowledge_versions enable row level security;
alter table public.knowledge_clusters enable row level security;
alter table public.knowledge_tags enable row level security;
alter table public.knowledge_topics enable row level security;
alter table public.knowledge_topic_tags enable row level security;
alter table public.knowledge_topic_sources enable row level security;
alter table public.padel_rules enable row level security;
alter table public.rule_faqs_v2 enable row level security;
alter table public.court_features enable row level security;
alter table public.equipment_categories enable row level security;
alter table public.racket_types enable row level security;
alter table public.racket_models enable row level security;
alter table public.racket_comparisons enable row level security;
alter table public.ball_types enable row level security;
alter table public.technique_topics enable row level security;
alter table public.tactical_topics enable row level security;
alter table public.training_knowledge enable row level security;
alter table public.assistant_citations enable row level security;
alter table public.knowledge_embeddings enable row level security;

grant usage on schema public to anon, authenticated;
grant select on
  public.knowledge_sources,
  public.knowledge_versions,
  public.knowledge_clusters,
  public.knowledge_tags,
  public.knowledge_topics,
  public.knowledge_topic_tags,
  public.knowledge_topic_sources,
  public.padel_rules,
  public.rule_faqs_v2,
  public.court_features,
  public.equipment_categories,
  public.racket_types,
  public.racket_models,
  public.racket_comparisons,
  public.ball_types,
  public.technique_topics,
  public.tactical_topics,
  public.training_knowledge,
  public.assistant_citations
to anon, authenticated;

create policy "knowledge_sources_read"
  on public.knowledge_sources for select to anon, authenticated using (true);

create policy "knowledge_versions_read"
  on public.knowledge_versions for select to anon, authenticated using (true);

create policy "knowledge_clusters_read"
  on public.knowledge_clusters for select to anon, authenticated using (true);

create policy "knowledge_tags_read"
  on public.knowledge_tags for select to anon, authenticated using (true);

create policy "knowledge_topics_published_read"
  on public.knowledge_topics for select to anon, authenticated using (publish_state = 'published');

create policy "knowledge_topic_tags_published_read"
  on public.knowledge_topic_tags for select to anon, authenticated using (
    exists (
      select 1 from public.knowledge_topics kt
      where kt.topic_id = knowledge_topic_tags.topic_id
        and kt.publish_state = 'published'
    )
  );

create policy "knowledge_topic_sources_published_read"
  on public.knowledge_topic_sources for select to anon, authenticated using (
    exists (
      select 1 from public.knowledge_topics kt
      where kt.topic_id = knowledge_topic_sources.topic_id
        and kt.publish_state = 'published'
    )
  );

create policy "padel_rules_published_read"
  on public.padel_rules for select to anon, authenticated using (
    exists (
      select 1 from public.knowledge_topics kt
      where kt.topic_id = padel_rules.topic_id
        and kt.publish_state = 'published'
    )
  );

create policy "rule_faqs_v2_read"
  on public.rule_faqs_v2 for select to anon, authenticated using (true);

create policy "court_features_published_read"
  on public.court_features for select to anon, authenticated using (
    exists (
      select 1 from public.knowledge_topics kt
      where kt.topic_id = court_features.topic_id
        and kt.publish_state = 'published'
    )
  );

create policy "equipment_categories_read"
  on public.equipment_categories for select to anon, authenticated using (true);

create policy "racket_types_read"
  on public.racket_types for select to anon, authenticated using (true);

create policy "racket_models_read"
  on public.racket_models for select to anon, authenticated using (true);

create policy "racket_comparisons_read"
  on public.racket_comparisons for select to anon, authenticated using (true);

create policy "ball_types_read"
  on public.ball_types for select to anon, authenticated using (true);

create policy "technique_topics_published_read"
  on public.technique_topics for select to anon, authenticated using (
    exists (
      select 1 from public.knowledge_topics kt
      where kt.topic_id = technique_topics.topic_id
        and kt.publish_state = 'published'
    )
  );

create policy "tactical_topics_published_read"
  on public.tactical_topics for select to anon, authenticated using (
    exists (
      select 1 from public.knowledge_topics kt
      where kt.topic_id = tactical_topics.topic_id
        and kt.publish_state = 'published'
    )
  );

create policy "training_knowledge_read"
  on public.training_knowledge for select to anon, authenticated using (true);

create policy "assistant_citations_published_read"
  on public.assistant_citations for select to anon, authenticated using (
    topic_id is null or exists (
      select 1 from public.knowledge_topics kt
      where kt.topic_id = assistant_citations.topic_id
        and kt.publish_state = 'published'
    )
  );

insert into public.knowledge_versions (version_id, label, description, effective_date, source_scope)
values (
  'padel_kb_2026_07',
  'RallyMate Padel Knowledge Base - July 2026',
  'Initial source-backed padel knowledge base for rules, court, balls, rackets, technique, tactics, training and assistant citations.',
  date '2026-07-06',
  'FIP official rules and ball certification, LTA federation guidance, selected manufacturer and coach technical sources.'
)
on conflict (version_id) do update set
  label = excluded.label,
  description = excluded.description,
  effective_date = excluded.effective_date,
  source_scope = excluded.source_scope;

insert into public.knowledge_sources (
  source_id,
  title,
  url,
  source_type,
  reliability,
  authority_level,
  accessed_at,
  published_at,
  update_cadence,
  certainty_note,
  citation
)
values
  (
    'fip_rules_2026',
    'FIP Rules of Padel',
    'https://www.padelfip.com/wp-content/uploads/2025/12/FIP_Rules-of-Padel.pdf',
    'official',
    5,
    'Official international rules authority',
    date '2026-07-06',
    date '2025-12-01',
    'annual',
    'Primary source for official padel rules, court, ball, racket and match situations.',
    '{"publisher":"International Padel Federation","language":"en","document_type":"rules_pdf"}'::jsonb
  ),
  (
    'fip_documents',
    'FIP Documents',
    'https://www.padelfip.com/documents/',
    'official',
    5,
    'Official international federation document index',
    date '2026-07-06',
    null,
    'quarterly',
    'Use to verify the latest official rule and technical documents before major releases.',
    '{"publisher":"International Padel Federation","document_type":"official_index"}'::jsonb
  ),
  (
    'fip_balls_2024',
    'FIP Balls',
    'https://www.padelfip.com/wp-content/uploads/2024/04/Balls.pdf',
    'official',
    5,
    'Official FIP ball specification and approved ball list',
    date '2026-07-06',
    date '2024-04-01',
    'quarterly',
    'Primary source for official padel ball specifications and certified balls.',
    '{"publisher":"International Padel Federation","document_type":"technical_pdf"}'::jsonb
  ),
  (
    'fip_ball_certification_2024',
    'FIP Game Ball Certification Process',
    'https://www.padelfip.com/wp-content/uploads/2024/04/Game-Ball-Certification-Process.pdf',
    'official',
    5,
    'Official FIP ball certification process',
    date '2026-07-06',
    date '2024-04-01',
    'annual',
    'Use for official tournament ball certification context.',
    '{"publisher":"International Padel Federation","document_type":"technical_pdf"}'::jsonb
  ),
  (
    'lta_padel_rules',
    'LTA Padel Rules',
    'https://www.ltapadel.org.uk/play/how-to-get-started-playing-padel/rules/',
    'federal',
    4,
    'National federation practical rules guide',
    date '2026-07-06',
    null,
    'quarterly',
    'Useful federation-level explanation for practical examples; FIP remains primary for official rules.',
    '{"publisher":"LTA Padel","document_type":"web_guide"}'::jsonb
  ),
  (
    'lta_padel_faq',
    'LTA Padel FAQs',
    'https://www.ltapadel.org.uk/play/padel-faqs/',
    'federal',
    4,
    'National federation FAQ',
    date '2026-07-06',
    null,
    'quarterly',
    'Useful for beginner explanations and tennis-vs-padel comparisons; not a replacement for FIP rules.',
    '{"publisher":"LTA Padel","document_type":"web_faq"}'::jsonb
  ),
  (
    'lta_court_guidance_2025',
    'LTA Padel Court Construction Guidance Note 2025',
    'https://www.lta.org.uk/siteassets/padel/lta-padel-court-construction-guidance-note-2025.pdf',
    'federal',
    4,
    'National federation court construction guidance',
    date '2026-07-06',
    date '2025-01-01',
    'annual',
    'Useful for court construction and surface guidance; local national requirements may vary.',
    '{"publisher":"LTA","document_type":"technical_pdf"}'::jsonb
  ),
  (
    'lta_beginner_skills',
    'LTA Padel Skills for Beginners',
    'https://www.ltapadel.org.uk/play/how-to-get-started-playing-padel/skills-for-beginners/',
    'federal',
    4,
    'National federation beginner coaching content',
    date '2026-07-06',
    null,
    'quarterly',
    'Good beginner guidance; coaching advice is practical, not official regulation.',
    '{"publisher":"LTA Padel","document_type":"web_guide"}'::jsonb
  ),
  (
    'head_shots_guide',
    'HEAD Beginner Guide to Padel Shots',
    'https://www.head.com/en_US/rs/stories/beginners-guide-to-padel-shots',
    'manufacturer',
    3,
    'Manufacturer educational guide',
    date '2026-07-06',
    null,
    'annual',
    'Useful technical glossary and shot descriptions; manufacturer/editorial source, not official rules.',
    '{"publisher":"HEAD","document_type":"brand_guide"}'::jsonb
  ),
  (
    'wilson_racket_guide',
    'Wilson How to Choose a Padel Racket',
    'https://www.wilson.com/en-us/blog/padel/how-tos/how-choose-padel-racket',
    'manufacturer',
    3,
    'Manufacturer equipment guide',
    date '2026-07-06',
    null,
    'annual',
    'Useful for general racket shape, sweet spot and balance explanations; manufacturer source.',
    '{"publisher":"Wilson","document_type":"brand_guide"}'::jsonb
  ),
  (
    'decathlon_racket_guide',
    'Decathlon How to Choose Your Padel Racket',
    'https://www.decathlon.co.uk/c/htc/how-to-choose-your-padel-racket_823ecba4-86a5-4b8f-a961-4ceaeea2cfd0',
    'shop',
    3,
    'Retailer equipment guide',
    date '2026-07-06',
    null,
    'annual',
    'Useful for beginner-friendly racket shape and skill fit explanations; treat as indicative.',
    '{"publisher":"Decathlon","document_type":"retail_guide"}'::jsonb
  ),
  (
    'babolat_air_viper_26',
    'Babolat Air Viper 2.6',
    'https://www.babolat.com/us/air-viper-2.6/150176.html',
    'manufacturer',
    4,
    'Manufacturer product specification',
    date '2026-07-06',
    null,
    'seasonal',
    'Primary source for this racket model technical specifications.',
    '{"publisher":"Babolat","document_type":"product_page"}'::jsonb
  ),
  (
    'nox_at10_18k_2025',
    'NOX AT10 Genius 18K Alum 2025',
    'https://noxsport.com/en/products/racket-at10-genius-18k-alum-by-agustin-tapia',
    'manufacturer',
    4,
    'Manufacturer product specification',
    date '2026-07-06',
    null,
    'seasonal',
    'Primary source for this racket model technical specifications.',
    '{"publisher":"NOX","document_type":"product_page"}'::jsonb
  ),
  (
    'head_speed_pro_2025',
    'HEAD Speed Pro 2025',
    'https://www.head.com/en_HR/product/speed-pro-2025-221065',
    'manufacturer',
    4,
    'Manufacturer product specification',
    date '2026-07-06',
    null,
    'seasonal',
    'Primary source for this racket model technical specifications.',
    '{"publisher":"HEAD","document_type":"product_page"}'::jsonb
  ),
  (
    'wilson_defy_v1',
    'Wilson Defy v1 Padel Racket',
    'https://www.wilson.com/en-us/blog/padel/wilson-labs/introducing-new-wilson-defy-v1-padel-racket',
    'manufacturer',
    4,
    'Manufacturer product announcement/specification',
    date '2026-07-06',
    null,
    'seasonal',
    'Primary source for Wilson Defy family positioning and specifications in the announcement.',
    '{"publisher":"Wilson","document_type":"brand_product_guide"}'::jsonb
  ),
  (
    'padel_school_vibora',
    'The Padel School Vibora Technique',
    'https://thepadelschool.com/padel-tips/the-vibora-technique',
    'coach',
    3,
    'Coach technical article',
    date '2026-07-06',
    null,
    'annual',
    'Useful coaching interpretation; not an official rule source.',
    '{"publisher":"The Padel School","document_type":"coach_article"}'::jsonb
  ),
  (
    'padel_school_left_side',
    'The Padel School Left Side Player',
    'https://thepadelschool.com/padel-tips/left-side-player',
    'coach',
    3,
    'Coach tactical article',
    date '2026-07-06',
    null,
    'annual',
    'Useful role/tactical interpretation; not an official rule source.',
    '{"publisher":"The Padel School","document_type":"coach_article"}'::jsonb
  ),
  (
    'padel_school_right_side',
    'The Padel School Right Side Player',
    'https://thepadelschool.com/padel-tips/right-side-player',
    'coach',
    3,
    'Coach tactical article',
    date '2026-07-06',
    null,
    'annual',
    'Useful role/tactical interpretation; not an official rule source.',
    '{"publisher":"The Padel School","document_type":"coach_article"}'::jsonb
  )
on conflict (source_id) do update set
  title = excluded.title,
  url = excluded.url,
  source_type = excluded.source_type,
  reliability = excluded.reliability,
  authority_level = excluded.authority_level,
  accessed_at = excluded.accessed_at,
  published_at = excluded.published_at,
  update_cadence = excluded.update_cadence,
  certainty_note = excluded.certainty_note,
  citation = excluded.citation,
  last_reviewed_at = current_date,
  updated_at = now();

insert into public.knowledge_clusters (
  cluster_id,
  title,
  description,
  subcategories,
  priority_mvp,
  free_available,
  premium_available,
  official_source_required,
  watch_supported,
  mobile_extended_supported
)
values
  ('official_rules', 'Regole ufficiali', 'Regole di gioco e situazioni arbitrarie fondate su fonti ufficiali.', array['servizio','risposta','falli','palla in gioco','punti vinti o persi'], 1, true, true, true, true, true),
  ('scoring_formats', 'Punteggio e formati', 'Game, set, tie-break, super tie-break, golden point e formati di match.', array['game','set','tie-break','golden point'], 1, true, true, true, true, true),
  ('ambiguous_situations', 'Situazioni dubbie', 'Casi limite comuni durante una partita e risposte rapide con fonti.', array['let','invasione','rete','uscita dal campo','griglie'], 1, true, true, true, true, true),
  ('court_surfaces', 'Campo e superfici', 'Dimensioni, rete, pareti, accessi, superfici e condizioni di gioco.', array['dimensioni','rete','vetri','griglie','superficie','indoor','outdoor'], 2, true, true, true, true, true),
  ('balls', 'Palline', 'Specifiche ufficiali, differenze da tennis, durata e comportamento in gioco.', array['pressione','diametro','peso','rimbalzo','conservazione'], 2, true, true, true, true, true),
  ('rackets', 'Racchette', 'Tipologie di racchette, forme, bilanciamento, materiali e fit per livello.', array['forma','bilanciamento','sweet spot','materiali','comfort'], 2, true, true, false, true, true),
  ('racket_materials', 'Materiali racchette', 'Carbonio, fibra di vetro, EVA, foam e superfici.', array['carbonio','fibra di vetro','EVA','foam','superficie ruvida'], 3, false, true, false, false, true),
  ('equipment_comparisons', 'Confronti attrezzatura', 'Confronti deterministici tra tipologie e modelli di racchetta.', array['potenza','controllo','comfort','maneggevolezza'], 3, false, true, false, false, true),
  ('technique', 'Tecnica', 'Colpi, progressioni tecniche, errori comuni ed esercizi collegabili.', array['volee','lob','bandeja','vibora','smash','uscita di parete'], 2, true, true, false, true, true),
  ('tactics', 'Tattica', 'Gestione del punto, centro, transizione, comunicazione e momenti decisivi.', array['difesa','attacco','transizione','centro','tie-break'], 2, true, true, false, true, true),
  ('roles', 'Ruoli', 'Giocatore di destra, sinistra e flex con indicazioni pratiche.', array['destra','sinistra','flex','coppia'], 2, true, true, false, true, true),
  ('training', 'Allenamenti', 'Routine e drill strutturati collegati a metriche e analytics RallyMate.', array['routine','drill','obiettivi','progressi'], 2, true, true, false, true, true),
  ('beginner_advice', 'Consigli principianti', 'Risposte semplici per iniziare, con focus su controllo e sicurezza.', array['primi passi','errori comuni','setup'], 1, true, true, false, true, true),
  ('advanced_advice', 'Consigli avanzati', 'Approfondimenti per utenti competitivi, premium e coach.', array['momenti decisivi','lettura avversari','scelta attrezzatura'], 4, false, true, false, false, true),
  ('smartwatch_faq', 'FAQ smartwatch', 'Risposte brevissime leggibili durante match o allenamento.', array['risposte rapide','match','training'], 1, true, true, true, true, false),
  ('match_quick_faq', 'FAQ rapide durante il match', 'FAQ Free e Premium pensate per consultazione immediata in campo.', array['let','servizio','punteggio','falli'], 1, true, true, true, true, true)
on conflict (cluster_id) do update set
  title = excluded.title,
  description = excluded.description,
  subcategories = excluded.subcategories,
  priority_mvp = excluded.priority_mvp,
  free_available = excluded.free_available,
  premium_available = excluded.premium_available,
  official_source_required = excluded.official_source_required,
  watch_supported = excluded.watch_supported,
  mobile_extended_supported = excluded.mobile_extended_supported;

insert into public.knowledge_tags (tag, cluster_id, description)
values
  ('regole', 'official_rules', 'Regole ufficiali e federali.'),
  ('servizio', 'official_rules', 'Servizio e primo colpo.'),
  ('let', 'ambiguous_situations', 'Ripetizione del punto o del servizio.'),
  ('fallo', 'official_rules', 'Situazioni che fanno perdere il punto.'),
  ('pareti', 'court_surfaces', 'Uso di vetri e pareti.'),
  ('griglie', 'court_surfaces', 'Uso di griglie o mesh.'),
  ('punteggio', 'scoring_formats', 'Game, set, tie-break, golden point.'),
  ('golden-point', 'scoring_formats', 'Punto decisivo sul quaranta pari.'),
  ('campo', 'court_surfaces', 'Dimensioni e caratteristiche campo.'),
  ('palline', 'balls', 'Specifiche e gestione palline.'),
  ('racchette', 'rackets', 'Tipologie e modelli di racchetta.'),
  ('controllo', 'rackets', 'Controllo, precisione e sweet spot.'),
  ('potenza', 'rackets', 'Potenza, leva e uscita palla.'),
  ('comfort', 'racket_materials', 'Comfort generale non medico.'),
  ('volee', 'technique', 'Volee e gioco a rete.'),
  ('lob', 'technique', 'Lob difensivo e offensivo.'),
  ('bandeja', 'technique', 'Bandeja e overhead di controllo.'),
  ('vibora', 'technique', 'Vibora e overhead aggressivo controllato.'),
  ('smash', 'technique', 'Smash e chiusura punto.'),
  ('destra', 'roles', 'Giocatore di destra.'),
  ('sinistra', 'roles', 'Giocatore di sinistra.'),
  ('comunicazione', 'tactics', 'Comunicazione di coppia.'),
  ('training', 'training', 'Allenamenti e drill.'),
  ('principiante', 'beginner_advice', 'Contenuti per chi inizia.'),
  ('premium', 'advanced_advice', 'Contenuti premium o avanzati.'),
  ('watch', 'smartwatch_faq', 'Risposta compatta per smartwatch.')
on conflict (tag) do update set
  cluster_id = excluded.cluster_id,
  description = excluded.description;

insert into public.knowledge_topics (
  topic_id,
  cluster_id,
  version_id,
  title,
  slug,
  summary_short,
  summary_extended,
  watch_summary,
  difficulty,
  audience_level,
  free_tier,
  premium_tier,
  answer_blocks,
  source_policy,
  certainty,
  publish_state,
  search_text
)
values
  (
    'rule_scoring_base',
    'scoring_formats',
    'padel_kb_2026_07',
    'Punteggio base nel padel',
    'punteggio-base-padel',
    'Il padel usa la sequenza 0, 15, 30, 40 e game, con regole specifiche per parita e formati come golden point o vantaggi.',
    'Il punteggio standard segue la struttura del tennis: 0, 15, 30, 40 e game. A seconda del formato di competizione, sul 40 pari si puo giocare con vantaggi oppure con golden point. Il match puo essere al meglio dei set, con tie-break o super tie-break secondo formato stabilito prima della partita.',
    'Punteggio: 0-15-30-40-game. Sul 40 pari verifica se state giocando vantaggi o golden point.',
    'beginner',
    array['beginner','intermediate'],
    true,
    true,
    '[{"type":"title","text":"Punteggio base"},{"type":"short_answer","text":"0, 15, 30, 40 e game; il 40 pari dipende dal formato."},{"type":"source","text":"FIP Rules of Padel"}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'punteggio padel game set 15 30 40 parita vantaggi golden point tie break super tie break'
  ),
  (
    'rule_golden_point',
    'scoring_formats',
    'padel_kb_2026_07',
    'Golden point',
    'golden-point-padel',
    'Nel golden point, sul quaranta pari si gioca un punto decisivo; la coppia in risposta sceglie il lato di risposta.',
    'Il golden point, quando previsto dal formato di gioco, elimina i vantaggi: sul 40 pari si disputa un punto decisivo. La coppia che risponde decide da quale lato ricevere. Chi vince quel punto vince il game.',
    'Sul 40 pari: punto secco. Chi risponde sceglie il lato.',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"title","text":"Golden point"},{"type":"short_answer","text":"Sul 40 pari si gioca un punto decisivo."},{"type":"attention","text":"Usalo solo se il formato della partita lo prevede."}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'golden point punto decisivo quaranta pari scelta lato risposta game'
  ),
  (
    'rule_service',
    'official_rules',
    'padel_kb_2026_07',
    'Servizio regolare',
    'servizio-regolare-padel',
    'Il servizio e sotto mano dopo rimbalzo, colpendo la palla sotto la cintura e mandandola nel box diagonalmente opposto.',
    'Il servizio inizia dietro la linea di servizio. Il giocatore fa rimbalzare la palla e la colpisce sotto il livello della cintura, verso il box di battuta diagonalmente opposto. Il server non deve calpestare la linea o entrare nel campo prima del colpo. Se la palla tocca la rete e poi entra correttamente, il servizio e let e si ripete.',
    'Servi sotto mano dopo rimbalzo, sotto la cintura, nel box diagonale.',
    'beginner',
    array['beginner','intermediate'],
    true,
    true,
    '[{"type":"title","text":"Servizio"},{"type":"step","items":["Resta dietro la linea","Fai rimbalzare la palla","Colpisci sotto la cintura","Cerca il box diagonale"]},{"type":"attention","text":"Rete piu box corretto: let, non punto perso."}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'servizio battuta sotto mano rimbalzo cintura box diagonale fallo linea let rete'
  ),
  (
    'rule_service_let_faults',
    'ambiguous_situations',
    'padel_kb_2026_07',
    'Let e falli sul servizio',
    'let-falli-servizio-padel',
    'Il servizio che tocca la rete e poi entra correttamente si ripete; se dopo il rimbalzo tocca griglia o esce dai limiti e fallo.',
    'Durante il servizio, un tocco della rete non basta a rendere il servizio sbagliato: se la palla cade nel box corretto e il seguito e regolare, si ripete. Se invece la palla non entra nel box corretto, colpisce direttamente pareti o griglie prima del rimbalzo valido, o dopo il rimbalzo si comporta in modo non consentito dal regolamento, e fallo.',
    'Rete + box corretto = let. Box sbagliato o traiettoria non valida = fallo.',
    'intermediate',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"short_answer","text":"Il let sul servizio si ripete."},{"type":"example","text":"Tocca il nastro, cade nel box corretto e resta valida: si ripete."},{"type":"attention","text":"Per dubbi da torneo, prevale il regolamento FIP aggiornato."}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'servizio let rete nastro fallo griglia vetro box corretto box sbagliato'
  ),
  (
    'rule_ball_in_play_walls',
    'official_rules',
    'padel_kb_2026_07',
    'Palla in gioco e uso delle pareti',
    'palla-in-gioco-pareti-padel',
    'Dopo un rimbalzo valido nel campo avversario, la palla puo toccare pareti o recinzioni secondo le regole di gioco.',
    'Il padel include il gioco con pareti e recinzioni. Una palla e giocabile se rimbalza prima nel campo avversario e poi tocca una parete o altra parte consentita della struttura. Se colpisce direttamente parete, griglia o altri elementi non validi prima del rimbalzo nel campo avversario, il colpo non e valido.',
    'Prima rimbalzo nel campo, poi parete: giocabile. Parete diretta: di solito fallo.',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"short_answer","text":"La palla deve prima rimbalzare nel campo avversario."},{"type":"example","text":"Rimbalzo nel campo, poi vetro: il punto continua."}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'palla in gioco parete vetro griglia rimbalzo campo avversario colpo valido non valido'
  ),
  (
    'rule_point_lost',
    'official_rules',
    'padel_kb_2026_07',
    'Quando si perde il punto',
    'quando-si-perde-il-punto-padel',
    'Si perde il punto per doppio rimbalzo, colpo fuori, tocco rete, invasione non consentita o palla che colpisce direttamente elementi non validi.',
    'Le cause principali di punto perso includono: lasciare rimbalzare due volte la palla nel proprio campo, mandare la palla fuori dai limiti senza rimbalzo valido, toccare la rete durante il punto, colpire la palla prima che abbia superato la rete quando non consentito, o colpire direttamente pareti/recinzioni avversarie senza rimbalzo valido.',
    'Doppio rimbalzo, rete toccata o palla fuori: punto perso.',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"short_answer","text":"Doppio rimbalzo e tocco rete sono cause tipiche di punto perso."},{"type":"attention","text":"Alcuni casi di recupero fuori campo hanno condizioni specifiche."}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'punto perso fallo doppio rimbalzo rete invasione fuori parete diretta griglia'
  ),
  (
    'rule_correct_return',
    'official_rules',
    'padel_kb_2026_07',
    'Risposta corretta e colpi validi',
    'risposta-corretta-colpi-validi-padel',
    'Un colpo e valido quando la palla supera la rete e rimbalza correttamente nel campo avversario, anche se poi tocca pareti o recinzioni.',
    'La risposta e corretta quando la palla viene colpita prima del secondo rimbalzo, supera la rete e rimbalza nel campo avversario. Dopo quel rimbalzo, puo toccare pareti o recinzioni consentite. I colpi al volo sono validi salvo eccezioni, ma il giocatore non deve toccare la rete.',
    'Colpisci prima del secondo rimbalzo e manda la palla nel campo avversario.',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"short_answer","text":"Prima del secondo rimbalzo, oltre rete, dentro il campo."},{"type":"example","text":"Volee dentro il campo avversario: valida."}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'risposta corretta colpo valido volee secondo rimbalzo rete campo avversario'
  ),
  (
    'rule_out_of_court',
    'ambiguous_situations',
    'padel_kb_2026_07',
    'Gioco e recupero fuori campo',
    'recupero-fuori-campo-padel',
    'Il recupero fuori campo e consentito solo quando il campo e abilitato e le condizioni di sicurezza e accesso rispettano il regolamento.',
    'Il gioco fuori campo non e automatico per tutti i campi. Il regolamento prevede misure e spazi minimi per gli accessi e per la zona esterna di sicurezza. Se il campo non e predisposto o il formato della partita non lo consente, la palla uscita resta gestita secondo le normali regole di punto.',
    'Fuori campo valido solo su campi predisposti e consentiti.',
    'intermediate',
    array['intermediate','advanced'],
    true,
    true,
    '[{"type":"attention","text":"Non tutti i campi permettono il recupero fuori campo."},{"type":"source","text":"FIP Rules of Padel"}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'fuori campo recupero out of court accesso sicurezza porte campo regolamento'
  ),
  (
    'court_dimensions_net',
    'court_surfaces',
    'padel_kb_2026_07',
    'Dimensioni campo e rete',
    'dimensioni-campo-rete-padel',
    'Il campo ufficiale e un rettangolo di 10 x 20 metri; la rete e lunga 10 metri e misura 0,88 m al centro e 0,92 m ai lati.',
    'Le misure ufficiali FIP definiscono un campo rettangolare di 10 metri di larghezza per 20 metri di lunghezza. La rete divide il campo a meta, con altezza piu bassa al centro e leggermente piu alta ai lati. Queste misure sono essenziali per regole, allenamento e spiegazioni in app.',
    'Campo: 10 x 20 m. Rete: 0,88 m centro, 0,92 m lati.',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"short_answer","text":"10 x 20 m; rete 0,88 m al centro e 0,92 m ai lati."}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'campo padel dimensioni 10 20 metri rete altezza centro lati'
  ),
  (
    'court_enclosures',
    'court_surfaces',
    'padel_kb_2026_07',
    'Vetri, pareti, griglie e accessi',
    'vetri-pareti-griglie-accessi-padel',
    'Il campo e chiuso da pareti/vetri e recinzioni; gli accessi devono rispettare misure e condizioni previste dal regolamento.',
    'Le pareti di fondo, le zone laterali, le griglie e gli accessi non sono solo elementi architettonici: influenzano rimbalzo, lettura della palla, recuperi e sicurezza. Le specifiche ufficiali definiscono materiali, altezze e aperture. Per gioco fuori campo servono accessi e spazi adeguati.',
    'Vetri e griglie fanno parte del gioco, ma accessi e sicurezza contano.',
    'intermediate',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"short_answer","text":"Vetri e griglie cambiano traiettorie e recuperi."},{"type":"attention","text":"Per fuori campo servono accessi regolamentari."}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'vetri pareti griglie mesh accessi porte out of court campo padel'
  ),
  (
    'court_surface_conditions',
    'court_surfaces',
    'padel_kb_2026_07',
    'Superficie, indoor, outdoor e condizioni',
    'superficie-indoor-outdoor-padel',
    'Superficie, sabbia, umidita e temperatura influenzano rimbalzo, velocita della palla e lettura dei vetri.',
    'Il regolamento consente superfici idonee; molte strutture usano erba sintetica sabbiata. In pratica, campi piu umidi o vetri freddi rendono il rimbalzo e le uscite di parete diversi. Indoor tende a essere piu prevedibile, outdoor aggiunge vento, umidita e luce variabile.',
    'Indoor piu prevedibile; outdoor richiede adattamento a vento, umidita e vetri.',
    'intermediate',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"short_answer","text":"Condizioni e superficie cambiano rimbalzo e timing."},{"type":"tip","text":"Nei campi lenti, privilegia controllo, lob profondi e pazienza."}]'::jsonb,
    'source_backed',
    'high',
    'published',
    'superficie erba sintetica sabbia indoor outdoor umidita temperatura vetro rimbalzo campo lento veloce'
  ),
  (
    'ball_official_specs',
    'balls',
    'padel_kb_2026_07',
    'Specifiche ufficiali delle palline',
    'specifiche-palline-padel',
    'Le palline ufficiali hanno peso, diametro, rimbalzo e pressione definiti da FIP; i tornei ufficiali usano palline certificate.',
    'Le specifiche FIP definiscono peso, dimensione, rimbalzo e pressione per le palline da padel. FIP distingue anche condizioni standard e alta quota e mantiene riferimenti per palline certificate. Per RallyMate, questi dati sono fonte primaria per FAQ su palline e confronto con tennis.',
    'Palline: usa specifiche FIP; nei tornei servono palline certificate.',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"short_answer","text":"Peso, diametro, rimbalzo e pressione sono definiti da FIP."}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'palline padel specifiche ufficiali peso diametro pressione rimbalzo certificate fip'
  ),
  (
    'ball_vs_tennis',
    'balls',
    'padel_kb_2026_07',
    'Palline da padel e da tennis',
    'palline-padel-vs-tennis',
    'Le palline da padel sono simili a quelle da tennis ma hanno specifiche proprie, spesso con pressione inferiore e comportamento meno vivo.',
    'A colpo d occhio le palline sembrano quasi uguali, ma padel e tennis hanno specifiche diverse. Le fonti federali indicano differenze soprattutto nella pressione e nel comportamento di rimbalzo. Per gioco serio e tornei, usa palline da padel omologate.',
    'Meglio usare palline da padel: sono simili, ma non equivalenti alle tennis.',
    'beginner',
    array['beginner','intermediate'],
    true,
    true,
    '[{"type":"short_answer","text":"Non sono equivalenti: usa palline da padel."},{"type":"faq","question":"Posso usare palline da tennis?","answer":"Solo in emergenza amatoriale, ma non e consigliato per ritmo e controllo."}]'::jsonb,
    'source_backed',
    'high',
    'published',
    'palline padel tennis differenze pressione rimbalzo meno vive omologate'
  ),
  (
    'racket_official_specs',
    'rackets',
    'padel_kb_2026_07',
    'Specifiche regolamentari della racchetta',
    'specifiche-racchetta-padel-regolamento',
    'La racchetta deve rispettare dimensioni massime e avere un cordino di sicurezza obbligatorio al polso.',
    'Il regolamento FIP stabilisce dimensioni massime della racchetta, spessore e caratteristiche generali. Il cordino di sicurezza da usare al polso e obbligatorio. Queste informazioni sono regolamentari, distinte dai consigli commerciali su forma, materiali o bilanciamento.',
    'Controlla dimensioni e cordino: il cordino al polso e obbligatorio.',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"short_answer","text":"Il cordino di sicurezza al polso e obbligatorio."},{"type":"source","text":"FIP Rules of Padel"}]'::jsonb,
    'official_source_required',
    'official',
    'published',
    'racchetta regolamento dimensioni spessore cordino polso sicurezza fip'
  ),
  (
    'racket_shapes',
    'rackets',
    'padel_kb_2026_07',
    'Forme racchetta: rotonda, goccia, diamante',
    'forme-racchetta-rotonda-goccia-diamante',
    'Rotonda privilegia controllo e sweet spot; diamante privilegia potenza; goccia e una soluzione ibrida.',
    'Le guide tecniche convergono su tre famiglie principali: rotonda, goccia/teardrop e diamante. La forma rotonda tende a offrire maggiore controllo e sweet spot piu centrale; la diamante tende a spostare peso e sweet spot verso l alto per piu potenza; la goccia cerca equilibrio tra controllo e spinta.',
    'Rotonda controllo, diamante potenza, goccia equilibrio.',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"short_answer","text":"Rotonda = controllo; diamante = potenza; goccia = equilibrio."},{"type":"attention","text":"Sono indicazioni tecniche, non regole ufficiali."}]'::jsonb,
    'source_backed',
    'high',
    'published',
    'racchetta forma rotonda goccia teardrop diamante controllo potenza sweet spot'
  ),
  (
    'racket_balance_materials',
    'racket_materials',
    'padel_kb_2026_07',
    'Bilanciamento, sweet spot e materiali',
    'bilanciamento-sweet-spot-materiali-racchetta',
    'Bilanciamento e materiali cambiano maneggevolezza, potenza, controllo e comfort generale.',
    'Un bilanciamento basso rende la racchetta piu maneggevole e tollerante; un bilanciamento alto puo aiutare nella potenza ma richiede piu tecnica. Carbonio, fibra di vetro, EVA e foam influenzano rigidita, uscita palla e comfort. Le indicazioni su gomito o spalla devono restare generali e non mediche.',
    'Bilanciamento basso: maneggevole. Alto: piu potenza, piu tecnico.',
    'intermediate',
    array['beginner','intermediate','advanced'],
    false,
    true,
    '[{"type":"short_answer","text":"Materiali e bilanciamento cambiano feeling, non sostituiscono prova sul campo."},{"type":"attention","text":"Nessun consiglio medico: per dolore consulta un professionista."}]'::jsonb,
    'source_backed',
    'medium',
    'published',
    'bilanciamento basso medio alto sweet spot carbonio fibra vetro eva foam comfort gomito spalla'
  ),
  (
    'technique_volley',
    'technique',
    'padel_kb_2026_07',
    'Volee di controllo',
    'volee-controllo-padel',
    'La volee nel padel serve a togliere tempo, mantenere posizione a rete e costruire il punto piu che a tirare sempre forte.',
    'La volee e una base del gioco a rete. Per principianti e intermedi e utile cercare controllo, direzione e profondita, tenendo la racchetta davanti e riducendo lo swing. RallyMate puo collegarla a errori gratuiti, punti vinti a rete e continuita negli scambi.',
    'Volee: racchetta davanti, swing corto, controllo prima della potenza.',
    'beginner',
    array['beginner','intermediate'],
    true,
    true,
    '[{"type":"tip","text":"Pensa a bloccare e guidare, non a colpire lungo."},{"type":"cta","target":"training_volley_control","text":"Apri allenamento volee di controllo"}]'::jsonb,
    'source_backed',
    'high',
    'published',
    'volee controllo rete swing corto profondita errori gratuiti allenamento'
  ),
  (
    'technique_lob',
    'technique',
    'padel_kb_2026_07',
    'Lob difensivo e offensivo',
    'lob-difensivo-offensivo-padel',
    'Il lob permette di uscire dalla pressione e riconquistare spazio, soprattutto quando gli avversari sono troppo vicini alla rete.',
    'Nel padel il lob non e solo un colpo difensivo. Se profondo e alto al punto giusto, spinge gli avversari indietro, apre la transizione e permette alla coppia di salire. I principianti dovrebbero usarlo per rallentare il punto invece di cercare colpi difficili sotto pressione.',
    'Sotto pressione: lob profondo, recupera campo e sali con il compagno.',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"tip","text":"Usa il lob per respirare e ribaltare la posizione."}]'::jsonb,
    'source_backed',
    'high',
    'published',
    'lob difesa attacco pressione rete transizione profondita principianti'
  ),
  (
    'technique_bandeja',
    'technique',
    'padel_kb_2026_07',
    'Bandeja',
    'bandeja-padel',
    'La bandeja e un overhead di controllo pensato per non perdere la rete quando arriva un lob non abbastanza profondo.',
    'La bandeja e un colpo tipico del padel usato per gestire lob intermedi senza forzare lo smash. L obiettivo e mantenere posizione, profondita e controllo, spesso con traiettoria sicura verso parete o angoli. E piu una soluzione tattica che un colpo di pura potenza.',
    'Bandeja: overhead di controllo per restare a rete.',
    'intermediate',
    array['intermediate','advanced'],
    true,
    true,
    '[{"type":"short_answer","text":"Usala per controllare un lob e non perdere la rete."},{"type":"cta","target":"training_bandeja_routine","text":"Allena bandeja e recupero rete"}]'::jsonb,
    'source_backed',
    'high',
    'published',
    'bandeja overhead controllo lob rete profondita tattica'
  ),
  (
    'technique_vibora',
    'technique',
    'padel_kb_2026_07',
    'Vibora',
    'vibora-padel',
    'La vibora e un overhead piu aggressivo della bandeja, usato per mettere pressione con effetto e traiettoria laterale.',
    'La vibora viene spesso spiegata come un colpo piu offensivo rispetto alla bandeja. Richiede timing, rotazione e controllo del corpo. E utile quando si vuole generare una palla scomoda dopo un lob gestibile, ma non deve diventare un colpo forzato a basso margine.',
    'Vibora: piu aggressiva della bandeja, ma serve margine.',
    'advanced',
    array['intermediate','advanced'],
    false,
    true,
    '[{"type":"short_answer","text":"Overhead aggressivo con effetto laterale."},{"type":"attention","text":"Consiglio tecnico da fonte coach, non regola ufficiale."}]'::jsonb,
    'source_backed',
    'medium',
    'published',
    'vibora overhead effetto laterale aggressivo bandeja pressione coach'
  ),
  (
    'role_left_side',
    'roles',
    'padel_kb_2026_07',
    'Giocatore di sinistra',
    'giocatore-sinistra-padel',
    'Il giocatore di sinistra tende ad avere piu responsabilita offensiva e copertura degli overhead, ma il ruolo dipende dalla coppia.',
    'Nel doppio di padel, il lato sinistro viene spesso associato a overhead, chiusura dei punti e maggiore iniziativa offensiva, soprattutto per giocatori destri. Non e una regola: compatibilita, mano dominante, stile e fiducia contano molto. RallyMate puo stimare il fit con rendimento, continuita e performance cambiando compagno.',
    'Sinistra: spesso piu offensivo e overhead, ma dipende dalla coppia.',
    'intermediate',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"short_answer","text":"Ruolo spesso piu offensivo, non obbligatorio."},{"type":"cta","target":"profile_role_setup","text":"Imposta il tuo ruolo"}]'::jsonb,
    'source_backed',
    'medium',
    'published',
    'giocatore sinistra ruolo offensivo overhead chiusura punti compagno'
  ),
  (
    'role_right_side',
    'roles',
    'padel_kb_2026_07',
    'Giocatore di destra',
    'giocatore-destra-padel',
    'Il giocatore di destra tende a dare equilibrio, costruzione e solidita, ma puo essere offensivo in base a mano e stile.',
    'Il lato destro e spesso associato a costruzione, difesa, pazienza e preparazione del punto. Un mancino a destra puo diventare molto offensivo per angoli e smash. RallyMate deve presentare il ruolo come una preferenza tattica, non come una categoria rigida.',
    'Destra: equilibrio e costruzione; un mancino puo essere molto offensivo.',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"short_answer","text":"Ruolo spesso di equilibrio e costruzione."},{"type":"attention","text":"Non e una regola fissa: conta la coppia."}]'::jsonb,
    'source_backed',
    'medium',
    'published',
    'giocatore destra ruolo costruzione equilibrio mancino difesa tattica'
  ),
  (
    'tactic_pair_communication',
    'tactics',
    'padel_kb_2026_07',
    'Comunicazione di coppia',
    'comunicazione-coppia-padel',
    'Comunicare prima e durante il punto riduce indecisioni, copre il centro e migliora la gestione dei lob.',
    'La comunicazione e una leva tattica essenziale: chiamate semplici su mia/tua, sale/scende, uomo/libero e centro possono ridurre errori evitabili. Per utenti RallyMate, il training puo collegare comunicazione a errori non forzati, punti decisivi e rendimento cambiando compagno.',
    'Usa chiamate brevi: mia, tua, sali, scendi, centro.',
    'beginner',
    array['beginner','intermediate','advanced'],
    true,
    true,
    '[{"type":"tip","text":"Prima del match decidete 4 chiamate semplici."},{"type":"cta","target":"training_pair_communication","text":"Allena comunicazione"}]'::jsonb,
    'source_backed',
    'high',
    'published',
    'comunicazione coppia mia tua centro lob compagno errori non forzati team'
  ),
  (
    'tactic_decisive_points',
    'tactics',
    'padel_kb_2026_07',
    'Gestione dei punti decisivi',
    'gestione-punti-decisivi-padel',
    'Nei punti decisivi conviene scegliere pattern ad alta percentuale, comunicazione chiara e target semplici.',
    'Tie-break, golden point e palle break premiano scelte ripetibili. Per molti giocatori e piu efficace ridurre il rischio: primo servizio solido, risposta profonda, lob quando sotto pressione, copertura centro e volee controllata. RallyMate puo misurare rendimento nei punti chiave e suggerire routine mirate.',
    'Punti chiave: pattern semplice, rischio basso, comunicazione chiara.',
    'intermediate',
    array['intermediate','advanced'],
    false,
    true,
    '[{"type":"tip","text":"Scegli un pattern sicuro prima del punto."},{"type":"cta","target":"training_decisive_points","text":"Allena punti decisivi"}]'::jsonb,
    'source_backed',
    'medium',
    'published',
    'punti decisivi tie break golden point break pressione pattern rischio comunicazione'
  )
on conflict (topic_id) do update set
  cluster_id = excluded.cluster_id,
  version_id = excluded.version_id,
  title = excluded.title,
  slug = excluded.slug,
  summary_short = excluded.summary_short,
  summary_extended = excluded.summary_extended,
  watch_summary = excluded.watch_summary,
  difficulty = excluded.difficulty,
  audience_level = excluded.audience_level,
  free_tier = excluded.free_tier,
  premium_tier = excluded.premium_tier,
  answer_blocks = excluded.answer_blocks,
  source_policy = excluded.source_policy,
  certainty = excluded.certainty,
  publish_state = excluded.publish_state,
  search_text = excluded.search_text,
  updated_at = now();

insert into public.knowledge_topic_tags (topic_id, tag)
values
  ('rule_scoring_base', 'punteggio'),
  ('rule_scoring_base', 'regole'),
  ('rule_scoring_base', 'watch'),
  ('rule_golden_point', 'golden-point'),
  ('rule_golden_point', 'punteggio'),
  ('rule_golden_point', 'watch'),
  ('rule_service', 'servizio'),
  ('rule_service', 'regole'),
  ('rule_service', 'watch'),
  ('rule_service_let_faults', 'let'),
  ('rule_service_let_faults', 'servizio'),
  ('rule_service_let_faults', 'fallo'),
  ('rule_ball_in_play_walls', 'pareti'),
  ('rule_ball_in_play_walls', 'griglie'),
  ('rule_ball_in_play_walls', 'regole'),
  ('rule_point_lost', 'fallo'),
  ('rule_point_lost', 'regole'),
  ('rule_correct_return', 'regole'),
  ('rule_correct_return', 'volee'),
  ('rule_out_of_court', 'campo'),
  ('rule_out_of_court', 'regole'),
  ('court_dimensions_net', 'campo'),
  ('court_dimensions_net', 'watch'),
  ('court_enclosures', 'campo'),
  ('court_enclosures', 'pareti'),
  ('court_enclosures', 'griglie'),
  ('court_surface_conditions', 'campo'),
  ('ball_official_specs', 'palline'),
  ('ball_official_specs', 'watch'),
  ('ball_vs_tennis', 'palline'),
  ('ball_vs_tennis', 'principiante'),
  ('racket_official_specs', 'racchette'),
  ('racket_official_specs', 'regole'),
  ('racket_shapes', 'racchette'),
  ('racket_shapes', 'controllo'),
  ('racket_shapes', 'potenza'),
  ('racket_balance_materials', 'racchette'),
  ('racket_balance_materials', 'comfort'),
  ('racket_balance_materials', 'premium'),
  ('technique_volley', 'volee'),
  ('technique_volley', 'training'),
  ('technique_lob', 'lob'),
  ('technique_lob', 'principiante'),
  ('technique_bandeja', 'bandeja'),
  ('technique_bandeja', 'training'),
  ('technique_vibora', 'vibora'),
  ('technique_vibora', 'premium'),
  ('role_left_side', 'sinistra'),
  ('role_left_side', 'premium'),
  ('role_right_side', 'destra'),
  ('tactic_pair_communication', 'comunicazione'),
  ('tactic_pair_communication', 'training'),
  ('tactic_decisive_points', 'golden-point'),
  ('tactic_decisive_points', 'premium'),
  ('tactic_decisive_points', 'training')
on conflict (topic_id, tag) do nothing;

insert into public.knowledge_topic_sources (topic_id, source_id, evidence_note, source_page, confidence)
values
  ('rule_scoring_base', 'fip_rules_2026', 'Official scoring sequence and match format rules.', 'Scoring rules', 'high'),
  ('rule_golden_point', 'fip_rules_2026', 'Official golden point/deuce format description.', 'Scoring rules', 'high'),
  ('rule_service', 'fip_rules_2026', 'Official service execution requirements.', 'Service rules', 'high'),
  ('rule_service', 'lta_padel_rules', 'Federation practical explanation of serve and let examples.', 'Serving section', 'medium'),
  ('rule_service_let_faults', 'fip_rules_2026', 'Official service let and fault conditions.', 'Service and let rules', 'high'),
  ('rule_service_let_faults', 'lta_padel_rules', 'Practical examples of let and service faults.', 'Rules guide', 'medium'),
  ('rule_ball_in_play_walls', 'fip_rules_2026', 'Official ball-in-play and valid/invalid return rules.', 'Ball in play', 'high'),
  ('rule_point_lost', 'fip_rules_2026', 'Official point-lost conditions.', 'Point lost', 'high'),
  ('rule_correct_return', 'fip_rules_2026', 'Official correct return conditions.', 'Correct return', 'high'),
  ('rule_out_of_court', 'fip_rules_2026', 'Official out-of-court play and access requirements.', 'Out-of-court play', 'high'),
  ('court_dimensions_net', 'fip_rules_2026', 'Official court and net measurements.', 'Court and net', 'high'),
  ('court_dimensions_net', 'lta_padel_faq', 'Federation beginner FAQ confirms standard 20x10 court dimensions.', 'Court FAQ', 'medium'),
  ('court_enclosures', 'fip_rules_2026', 'Official enclosure, wall, fence and access specifications.', 'Court enclosure', 'high'),
  ('court_enclosures', 'lta_court_guidance_2025', 'Federation construction guidance for court layout and safe external area.', 'Court guidance', 'medium'),
  ('court_surface_conditions', 'fip_rules_2026', 'Official permitted ground surface categories.', 'Ground surface', 'high'),
  ('court_surface_conditions', 'lta_court_guidance_2025', 'Federation guidance on sand-dressed synthetic surface and practical court requirements.', 'Construction guidance', 'medium'),
  ('ball_official_specs', 'fip_balls_2024', 'Official ball measurements, pressure and certified ball context.', 'Ball specifications', 'high'),
  ('ball_official_specs', 'fip_ball_certification_2024', 'Official certification process for game balls.', 'Certification process', 'high'),
  ('ball_vs_tennis', 'lta_padel_faq', 'Federation FAQ explains padel ball differences from tennis balls.', 'Padel balls FAQ', 'medium'),
  ('ball_vs_tennis', 'fip_balls_2024', 'Official padel ball specification baseline.', 'Ball specifications', 'high'),
  ('racket_official_specs', 'fip_rules_2026', 'Official racket dimensions and safety cord requirement.', 'Racket rules', 'high'),
  ('racket_shapes', 'wilson_racket_guide', 'Manufacturer guide explains round, teardrop and diamond racket shape tradeoffs.', 'Racket shape guide', 'medium'),
  ('racket_shapes', 'decathlon_racket_guide', 'Retailer guide supports shape-to-skill and power/control mapping.', 'Racket guide', 'medium'),
  ('racket_balance_materials', 'wilson_racket_guide', 'Manufacturer guide explains sweet spot, balance and foam concepts.', 'Racket guide', 'medium'),
  ('racket_balance_materials', 'decathlon_racket_guide', 'Retailer guide explains head balance and shape fit.', 'Racket guide', 'medium'),
  ('technique_volley', 'head_shots_guide', 'Manufacturer educational guide describes volley among essential padel shots.', 'Shot guide', 'medium'),
  ('technique_volley', 'lta_beginner_skills', 'Federation beginner guidance emphasizes control over power and net play.', 'Beginner skills', 'medium'),
  ('technique_lob', 'lta_beginner_skills', 'Federation beginner tips recommend using lobs to move opponents away from net.', 'Beginner skills', 'medium'),
  ('technique_bandeja', 'head_shots_guide', 'Manufacturer educational guide lists bandeja among padel shots.', 'Shot guide', 'medium'),
  ('technique_vibora', 'padel_school_vibora', 'Coach article positions vibora as more aggressive than bandeja.', 'Vibora technique', 'medium'),
  ('technique_vibora', 'head_shots_guide', 'Manufacturer guide lists vibora among padel shots.', 'Shot guide', 'medium'),
  ('role_left_side', 'padel_school_left_side', 'Coach article explains left-side player role and overhead responsibilities.', 'Left side player', 'medium'),
  ('role_right_side', 'padel_school_right_side', 'Coach article explains right-side player role, consistency and strategist framing.', 'Right side player', 'medium'),
  ('tactic_pair_communication', 'lta_beginner_skills', 'Federation beginner guidance recommends communication with the partner.', 'Beginner skills', 'medium'),
  ('tactic_decisive_points', 'fip_rules_2026', 'Official context for tie-break and golden point formats.', 'Scoring rules', 'high'),
  ('tactic_decisive_points', 'lta_beginner_skills', 'Federation beginner guidance supports control over power and simple tactical choices.', 'Beginner skills', 'medium')
on conflict (topic_id, source_id, evidence_note) do update set
  source_page = excluded.source_page,
  confidence = excluded.confidence;

insert into public.padel_rules (
  topic_id,
  rule_number,
  category,
  user_question,
  short_answer,
  detailed_answer,
  examples,
  edge_cases,
  official_source_id
)
values
  (
    'rule_scoring_base',
    'Scoring',
    'punteggio',
    'Come si contano i punti nel padel?',
    'Si conta 0, 15, 30, 40 e game. Sul 40 pari il formato decide tra vantaggi o golden point.',
    'Il sistema base usa 0, 15, 30, 40 e game. Il match puo usare diversi formati, quindi prima di iniziare bisogna chiarire se sul 40 pari si gioca con vantaggi o golden point e se il set prevede tie-break o super tie-break.',
    '[{"scenario":"Partita amatoriale","answer":"Decidete prima se usare vantaggi o golden point."},{"scenario":"Torneo","answer":"Seguite il formato indicato dal regolamento della competizione."}]'::jsonb,
    '[{"case":"Formato non dichiarato","resolution":"Chiarire prima della partita; in app mostrare entrambe le opzioni."}]'::jsonb,
    'fip_rules_2026'
  ),
  (
    'rule_golden_point',
    'Scoring - Golden Point',
    'punteggio',
    'Che cosa succede sul quaranta pari con golden point?',
    'Si gioca un punto decisivo. La coppia in risposta sceglie il lato da cui ricevere.',
    'Quando il formato prevede golden point, il 40 pari non apre una sequenza di vantaggi. Si gioca un solo punto: chi lo vince conquista il game. La coppia in risposta sceglie il lato di risposta.',
    '[{"scenario":"40 pari","answer":"Chi risponde sceglie lato, poi punto secco."}]'::jsonb,
    '[{"case":"Giocatori in dubbio","resolution":"Se il formato non era stato concordato, fermarsi e concordare prima di servire."}]'::jsonb,
    'fip_rules_2026'
  ),
  (
    'rule_service',
    'Service',
    'servizio',
    'Come si serve correttamente nel padel?',
    'Servi sotto mano dopo rimbalzo, colpendo sotto la cintura e mirando al box diagonale.',
    'Il servizio deve partire dietro la linea di servizio. La palla deve rimbalzare e poi essere colpita sotto la cintura. Deve superare la rete e cadere nel box diagonalmente opposto. Il server non deve calpestare la linea o avanzare prima del colpo.',
    '[{"scenario":"Servizio corretto","answer":"Rimbalzo, colpo sotto cintura, box diagonale."},{"scenario":"Tocchi la linea prima del colpo","answer":"Fallo di servizio."}]'::jsonb,
    '[{"case":"Palla sul nastro e dentro","resolution":"Let sul servizio, si ripete se il seguito e regolare."}]'::jsonb,
    'fip_rules_2026'
  ),
  (
    'rule_service_let_faults',
    'Service let',
    'let',
    'Se il servizio tocca la rete e poi entra e buono?',
    'E let: si ripete, se la palla entra nel box corretto e non genera una condizione di fallo.',
    'Il tocco della rete sul servizio non e automaticamente fallo. Se la palla supera la rete, rimbalza nel box corretto e il resto della traiettoria rispetta il regolamento, il servizio si ripete.',
    '[{"scenario":"Nastro e box corretto","answer":"Let, ripeti il servizio."},{"scenario":"Nastro e fuori box","answer":"Fallo."}]'::jsonb,
    '[{"case":"Dopo il box tocca griglia","resolution":"Verificare le condizioni specifiche del regolamento e del formato usato."}]'::jsonb,
    'fip_rules_2026'
  ),
  (
    'rule_ball_in_play_walls',
    'Ball in play',
    'palla in gioco',
    'Posso usare il vetro per giocare la palla?',
    'Si, ma la palla deve essere giocata secondo sequenza valida: campo, poi parete o parete propria prima del colpo secondo le regole.',
    'Le pareti sono parte del gioco, ma la palla non puo colpire direttamente una parete avversaria prima di rimbalzare nel campo avversario. Dal proprio lato puoi usare pareti e vetri per preparare il colpo, se riesci a colpire prima del secondo rimbalzo.',
    '[{"scenario":"Palla rimbalza nel campo avversario e poi sul vetro","answer":"Il punto continua."},{"scenario":"Colpo diretto sul vetro avversario","answer":"Punto perso."}]'::jsonb,
    '[{"case":"Griglia laterale","resolution":"Controllare se il contatto avviene dopo un rimbalzo valido e secondo regola."}]'::jsonb,
    'fip_rules_2026'
  ),
  (
    'rule_point_lost',
    'Point lost',
    'falli',
    'Quando perdo il punto?',
    'Perdi il punto con doppio rimbalzo, palla fuori, tocco rete, invasione non valida o colpo diretto su elementi non validi.',
    'Le situazioni piu comuni di punto perso sono: lasciare due rimbalzi nel proprio campo, non mandare la palla nel campo avversario, toccare la rete durante il punto, colpire in modo non consentito o mandare la palla direttamente contro pareti o recinzioni avversarie senza rimbalzo valido.',
    '[{"scenario":"La palla rimbalza due volte","answer":"Punto perso."},{"scenario":"Tocchi la rete dopo aver colpito","answer":"Punto perso se il punto e ancora in corso."}]'::jsonb,
    '[{"case":"Recupero fuori campo","resolution":"Valido solo se campo e condizioni lo consentono."}]'::jsonb,
    'fip_rules_2026'
  ),
  (
    'rule_correct_return',
    'Correct return',
    'colpo valido',
    'Quando una risposta e corretta?',
    'Quando colpisci prima del secondo rimbalzo e mandi la palla oltre rete nel campo avversario.',
    'La risposta e corretta se la palla viene colpita prima del secondo rimbalzo, supera la rete e rimbalza correttamente nel campo avversario. Dopo il rimbalzo valido puo toccare pareti o recinzioni consentite.',
    '[{"scenario":"Volee nel campo avversario","answer":"Valida."},{"scenario":"Palla colpita dopo secondo rimbalzo","answer":"Punto perso."}]'::jsonb,
    '[{"case":"Palla con molto effetto torna nel tuo campo","resolution":"Controllare la regola specifica su palla che torna e possibilita di colpo oltre rete senza toccarla."}]'::jsonb,
    'fip_rules_2026'
  ),
  (
    'rule_out_of_court',
    'Out of court',
    'fuori campo',
    'Posso uscire dal campo per recuperare una palla?',
    'Solo se il campo e predisposto e il gioco fuori campo e consentito dal regolamento/formato.',
    'Il recupero fuori campo richiede accessi e zona esterna adeguati. Non tutti i campi sono omologati o sicuri per questa modalita. In app va presentato come caso avanzato e dipendente dal campo.',
    '[{"scenario":"Campo con accessi e zona libera","answer":"Il recupero puo essere consentito."},{"scenario":"Campo chiuso senza spazio esterno","answer":"Non trattarlo come recupero consentito."}]'::jsonb,
    '[{"case":"Partita amatoriale","resolution":"Concordare prima se il fuori campo e giocabile."}]'::jsonb,
    'fip_rules_2026'
  )
on conflict (topic_id) do update set
  rule_number = excluded.rule_number,
  category = excluded.category,
  user_question = excluded.user_question,
  short_answer = excluded.short_answer,
  detailed_answer = excluded.detailed_answer,
  examples = excluded.examples,
  edge_cases = excluded.edge_cases,
  official_source_id = excluded.official_source_id;

insert into public.rule_faqs_v2 (
  faq_id,
  rule_topic_id,
  question,
  answer_short,
  answer_long,
  watch_answer,
  tags,
  free_available,
  premium_available,
  source_id,
  certainty
)
values
  ('faq_score_how', 'rule_scoring_base', 'Come funziona il punteggio nel padel?', '0, 15, 30, 40 e game; sul 40 pari dipende dal formato.', 'Il padel usa il punteggio 0, 15, 30, 40 e game. Prima della partita chiarisci se userete vantaggi o golden point sul 40 pari.', '0-15-30-40-game. Sul 40 pari: vantaggi o golden point.', array['punteggio','watch'], true, true, 'fip_rules_2026', 'official'),
  ('faq_golden_point_side', 'rule_golden_point', 'Chi sceglie il lato nel golden point?', 'La coppia in risposta sceglie il lato.', 'Nel golden point sul 40 pari si gioca un punto decisivo. La coppia in risposta sceglie da quale lato ricevere.', 'Golden point: chi risponde sceglie lato.', array['golden-point','punteggio','watch'], true, true, 'fip_rules_2026', 'official'),
  ('faq_service_net', 'rule_service_let_faults', 'Se il servizio tocca la rete si ripete?', 'Si, se poi cade correttamente nel box previsto.', 'Il servizio che tocca il nastro e poi entra correttamente e let: si ripete. Se non entra nel box corretto o produce fallo, non e let valido.', 'Nastro + box corretto = let.', array['servizio','let','watch'], true, true, 'fip_rules_2026', 'official'),
  ('faq_wall_direct', 'rule_ball_in_play_walls', 'Posso tirare direttamente sul vetro avversario?', 'No, prima la palla deve rimbalzare nel campo avversario.', 'Se la palla colpisce direttamente vetro o recinzione avversaria senza rimbalzo valido nel campo, il colpo non e valido.', 'Prima campo, poi vetro.', array['pareti','regole','watch'], true, true, 'fip_rules_2026', 'official'),
  ('faq_double_bounce', 'rule_point_lost', 'Il doppio rimbalzo e sempre punto perso?', 'Si, se la palla rimbalza due volte nel tuo campo prima del colpo.', 'Uno dei falli piu comuni e lasciare rimbalzare due volte la palla nel proprio campo. Devi colpire prima del secondo rimbalzo.', 'Due rimbalzi nel tuo campo = punto perso.', array['fallo','watch'], true, true, 'fip_rules_2026', 'official'),
  ('faq_out_of_court', 'rule_out_of_court', 'Il recupero fuori campo e sempre valido?', 'No, solo su campi predisposti e quando il formato lo consente.', 'Il fuori campo richiede accessi e zona esterna adeguati. Se il campo non e predisposto, non considerarlo una giocata consentita.', 'Fuori campo solo se il campo e predisposto.', array['campo','regole'], true, true, 'fip_rules_2026', 'official'),
  ('faq_tennis_balls', 'ball_vs_tennis', 'Posso usare palline da tennis per giocare a padel?', 'Meglio di no: le palline da padel hanno specifiche proprie.', 'Le palline da padel sono simili a quelle da tennis ma non equivalenti. Per ritmo, rimbalzo e partite ufficiali usa palline da padel omologate.', 'Usa palline da padel, non tennis.', array['palline','principiante','watch'], true, true, 'lta_padel_faq', 'high'),
  ('faq_racket_beginner', 'racket_shapes', 'Che racchetta conviene a un principiante?', 'Di solito una rotonda o bilanciata verso il controllo.', 'Per iniziare e spesso piu utile una racchetta tollerante, con sweet spot ampio e buon controllo. La forma rotonda e una scelta comune, ma peso e comfort percepito vanno provati.', 'Principiante: cerca controllo e sweet spot ampio.', array['racchette','principiante'], true, true, 'wilson_racket_guide', 'medium')
on conflict (faq_id) do update set
  rule_topic_id = excluded.rule_topic_id,
  question = excluded.question,
  answer_short = excluded.answer_short,
  answer_long = excluded.answer_long,
  watch_answer = excluded.watch_answer,
  tags = excluded.tags,
  free_available = excluded.free_available,
  premium_available = excluded.premium_available,
  source_id = excluded.source_id,
  certainty = excluded.certainty;

insert into public.court_features (
  topic_id,
  feature_type,
  technical_description,
  impact_on_play,
  pros,
  cons,
  adaptation_tips,
  official_reference,
  source_id
)
values
  (
    'court_dimensions_net',
    'dimensions_and_net',
    'Campo rettangolare 10 x 20 metri; rete centrale con altezza ufficiale differenziata tra centro e lati.',
    'Le dimensioni compatte rendono fondamentali posizione, pareti e copertura del centro.',
    '["Standard chiaro per app, training e confronto campi","Aiuta spiegazioni semplici per principianti"]'::jsonb,
    '["Campi non standard possono alterare ritmo e misure percepite"]'::jsonb,
    '["Usa riferimenti visivi: linea servizio, centro, vetro di fondo","Allena spostamenti brevi e ritorno in posizione"]'::jsonb,
    'FIP Rules of Padel - Court and net',
    'fip_rules_2026'
  ),
  (
    'court_enclosures',
    'walls_fences_access',
    'Pareti/vetri, griglie e accessi definiscono rimbalzi, recuperi e condizioni per il gioco fuori campo.',
    'Vetri e griglie cambiano lettura della traiettoria; accessi e spazio esterno determinano se il fuori campo e praticabile.',
    '["Rende il padel tatticamente unico","Permette recuperi e traiettorie creative"]'::jsonb,
    '["Rimbalzi difficili per principianti","Rischio sicurezza se accessi/spazi non sono adeguati"]'::jsonb,
    '["Osserva il primo rimbalzo sul vetro durante il riscaldamento","Su griglia cerca margine, non precisione estrema"]'::jsonb,
    'FIP Rules of Padel - Enclosures and out-of-court play',
    'fip_rules_2026'
  ),
  (
    'court_surface_conditions',
    'surface_conditions',
    'Superficie idonea e spesso sintetica sabbiata; indoor/outdoor, umidita e temperatura incidono su rimbalzo e velocita.',
    'Campi piu lenti premiano pazienza e lob; condizioni outdoor richiedono adattamento a vento, luce e vetri umidi.',
    '["Indoor piu prevedibile","Outdoor allena adattamento e gestione condizioni"]'::jsonb,
    '["Umidita e vetro freddo possono ridurre prevedibilita","Vento e luce possono alterare timing"]'::jsonb,
    '["Riscaldati testando uscita di parete","Riduci rischio nei primi game","Aumenta margine sui lob outdoor"]'::jsonb,
    'FIP ground surface plus LTA construction guidance',
    'lta_court_guidance_2025'
  )
on conflict (topic_id) do update set
  feature_type = excluded.feature_type,
  technical_description = excluded.technical_description,
  impact_on_play = excluded.impact_on_play,
  pros = excluded.pros,
  cons = excluded.cons,
  adaptation_tips = excluded.adaptation_tips,
  official_reference = excluded.official_reference,
  source_id = excluded.source_id;

insert into public.equipment_categories (category_id, title, description, free_available, premium_available)
values
  ('rackets', 'Racchette', 'Forme, materiali, bilanciamento, modelli e confronti deterministici.', true, true),
  ('balls', 'Palline', 'Specifiche, pressione, durata e comportamento indoor/outdoor.', true, true),
  ('court', 'Campo', 'Dimensioni, rete, superfici, vetri, griglie e accessi.', true, true)
on conflict (category_id) do update set
  title = excluded.title,
  description = excluded.description,
  free_available = excluded.free_available,
  premium_available = excluded.premium_available;

insert into public.ball_types (
  ball_type_id,
  topic_id,
  title,
  pressure_type,
  diameter_cm_range,
  weight_g_range,
  rebound_cm_range,
  pressure_spec,
  behavior_notes,
  official_standard,
  source_id,
  certainty
)
values
  (
    'standard_padel_ball',
    'ball_official_specs',
    'Pallina da padel standard',
    'pressurized_or_pressureless_according_to_certification',
    '6.35-6.77',
    '56.0-59.4',
    '135-145',
    'Official FIP pressure specification applies; verify latest FIP ball document before publication.',
    'Standard for normal play and official certification context.',
    true,
    'fip_balls_2024',
    'official'
  ),
  (
    'high_altitude_padel_ball',
    'ball_official_specs',
    'Pallina da padel per alta quota',
    'high_altitude_specification',
    '6.35-6.77',
    '56.0-59.4',
    '121.92-135',
    'High-altitude conditions have distinct rebound specification in FIP ball document.',
    'Used where altitude changes rebound behavior; show only as technical/advanced context.',
    true,
    'fip_balls_2024',
    'official'
  ),
  (
    'beginner_control_ball',
    'ball_vs_tennis',
    'Pallina percepita lenta per principianti',
    'indicative_play_behavior',
    null,
    null,
    null,
    'Not an official category in this seed; use only as practical behavior descriptor.',
    'A slower-feeling ball can make rallies more controllable for beginners, but model choice must be based on certified products and conditions.',
    false,
    'lta_padel_faq',
    'indicative'
  )
on conflict (ball_type_id) do update set
  topic_id = excluded.topic_id,
  title = excluded.title,
  pressure_type = excluded.pressure_type,
  diameter_cm_range = excluded.diameter_cm_range,
  weight_g_range = excluded.weight_g_range,
  rebound_cm_range = excluded.rebound_cm_range,
  pressure_spec = excluded.pressure_spec,
  behavior_notes = excluded.behavior_notes,
  official_standard = excluded.official_standard,
  source_id = excluded.source_id,
  certainty = excluded.certainty;

insert into public.racket_types (
  type_id,
  topic_id,
  title,
  shape,
  balance,
  core,
  frame_material,
  face_material,
  surface,
  recommended_level,
  recommended_style,
  impact_scores,
  pros,
  cons,
  faqs,
  source_id,
  certainty
)
values
  (
    'round_control',
    'racket_shapes',
    'Racchetta rotonda controllo',
    'round',
    'low_to_medium',
    null,
    null,
    null,
    null,
    'beginner_to_intermediate',
    'Controllo, tolleranza e gioco regolare.',
    '{"control":5,"power":2,"maneuverability":5,"comfort":4,"technical_demand":2}'::jsonb,
    '["Sweet spot ampio","Facile da gestire","Buona scelta per iniziare"]'::jsonb,
    '["Meno potenza gratuita","Puo limitare chi cerca smash aggressivi"]'::jsonb,
    '[{"question":"E adatta ai principianti?","answer":"Spesso si, per controllo e tolleranza."}]'::jsonb,
    'wilson_racket_guide',
    'high'
  ),
  (
    'teardrop_hybrid',
    'racket_shapes',
    'Racchetta a goccia ibrida',
    'teardrop',
    'medium',
    null,
    null,
    null,
    null,
    'intermediate',
    'Equilibrio tra controllo e potenza.',
    '{"control":4,"power":4,"maneuverability":4,"comfort":3,"technical_demand":3}'::jsonb,
    '["Buon compromesso","Adatta a crescita tecnica","Versatile per ruoli diversi"]'::jsonb,
    '["Meno estrema di una controllo o potenza pura","Serve un minimo di tecnica"]'::jsonb,
    '[{"question":"E una forma universale?","answer":"E una scelta ibrida, non automaticamente perfetta per tutti."}]'::jsonb,
    'wilson_racket_guide',
    'high'
  ),
  (
    'diamond_power',
    'racket_shapes',
    'Racchetta diamante potenza',
    'diamond',
    'high',
    null,
    null,
    null,
    null,
    'advanced',
    'Potenza, overhead e gioco aggressivo.',
    '{"control":2,"power":5,"maneuverability":2,"comfort":2,"technical_demand":5}'::jsonb,
    '["Piu leva per smash e colpi alti","Fit naturale per gioco aggressivo"]'::jsonb,
    '["Meno tollerante","Richiede tecnica e timing","Puo affaticare se troppo pesante o rigida"]'::jsonb,
    '[{"question":"Va bene per iniziare?","answer":"Di solito no, meglio provarla solo se hai buona tecnica."}]'::jsonb,
    'wilson_racket_guide',
    'high'
  ),
  (
    'soft_eva_comfort',
    'racket_balance_materials',
    'Nucleo morbido orientato comfort',
    null,
    null,
    'soft_eva_or_foam',
    null,
    null,
    null,
    'beginner_to_intermediate',
    'Comfort generale, uscita palla facile e ritmo controllato.',
    '{"control":4,"power":3,"maneuverability":4,"comfort":5,"technical_demand":2}'::jsonb,
    '["Feeling piu morbido","Uscita palla facile","Aiuta chi cerca tolleranza"]'::jsonb,
    '["Meno precisione percepita per alcuni giocatori avanzati","Puo perdere brillantezza nel tempo"]'::jsonb,
    '[{"question":"Aiuta per gomito o spalla?","answer":"Puo risultare piu confortevole, ma non e un consiglio medico."}]'::jsonb,
    'decathlon_racket_guide',
    'medium'
  ),
  (
    'carbon_hard_power',
    'racket_balance_materials',
    'Carbonio rigido orientato potenza',
    null,
    'medium_to_high',
    'medium_to_hard_eva',
    'carbon',
    'carbon',
    'smooth_or_rough',
    'advanced',
    'Gioco offensivo e impatto deciso.',
    '{"control":3,"power":5,"maneuverability":2,"comfort":2,"technical_demand":5}'::jsonb,
    '["Risposta piu secca","Maggiore potenziale di potenza","Buona stabilita per impatti forti"]'::jsonb,
    '["Richiede tecnica","Meno tollerante","Comfort soggettivo da verificare"]'::jsonb,
    '[{"question":"E sempre migliore?","answer":"No, dipende da livello, stile e tolleranza fisica."}]'::jsonb,
    'wilson_racket_guide',
    'medium'
  )
on conflict (type_id) do update set
  topic_id = excluded.topic_id,
  title = excluded.title,
  shape = excluded.shape,
  balance = excluded.balance,
  core = excluded.core,
  frame_material = excluded.frame_material,
  face_material = excluded.face_material,
  surface = excluded.surface,
  recommended_level = excluded.recommended_level,
  recommended_style = excluded.recommended_style,
  impact_scores = excluded.impact_scores,
  pros = excluded.pros,
  cons = excluded.cons,
  faqs = excluded.faqs,
  source_id = excluded.source_id,
  certainty = excluded.certainty;

insert into public.racket_models (
  model_id,
  brand,
  model,
  model_year,
  shape,
  weight_declared,
  balance_declared,
  frame_material,
  face_material,
  core_material,
  surface,
  thickness_mm,
  level_recommended,
  style_recommended,
  price_amount,
  price_currency,
  technical_specs,
  reliability_notes,
  manufacturer_source_id,
  secondary_source_ids
)
values
  (
    'babolat_air_viper_26',
    'Babolat',
    'Air Viper 2.6',
    '2.6',
    'teardrop',
    '355 g +/- 10 g',
    '265 mm',
    'carbon',
    '16K carbon',
    'X-EVA',
    null,
    38,
    'advanced',
    'dynamic_power_aerial_aggressive',
    null,
    null,
    '{"declared_typology":"aerial_striker","declared_shape":"teardrop","declared_thickness":"38 mm"}'::jsonb,
    'Manufacturer source. Price intentionally omitted because it can drift by country and campaign.',
    'babolat_air_viper_26',
    '{}'
  ),
  (
    'nox_at10_genius_18k_alum_2025',
    'NOX',
    'AT10 Genius 18K Alum by Agustin Tapia',
    '2025',
    'teardrop',
    '360-375 g',
    null,
    '100% carbon',
    '18K Alum carbon',
    'MLD Black EVA',
    'rough',
    38,
    'advanced_professional',
    'balanced_control_power',
    null,
    null,
    '{"declared_power":90,"declared_control":100,"declared_feel":"intermediate-hard","declared_rough_surface":true}'::jsonb,
    'Manufacturer source. Scores are declared by the brand and should not be compared as universal lab metrics.',
    'nox_at10_18k_2025',
    '{}'
  ),
  (
    'head_speed_pro_2025',
    'HEAD',
    'Speed Pro',
    '2025',
    'teardrop',
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    'advanced_tournament',
    'tactical_dynamic_power',
    null,
    null,
    '{"declared_positioning":"tournament players","declared_benefit":"tactical and dynamic power","declared_shape":"teardrop"}'::jsonb,
    'Manufacturer source excerpt does not expose all technical fields in parsed content; keep unknown fields null instead of guessing.',
    'head_speed_pro_2025',
    '{}'
  ),
  (
    'wilson_defy_pro_v1',
    'Wilson',
    'Defy Pro V1',
    'V1',
    'diamond',
    '370 g',
    null,
    null,
    '15K carbon',
    null,
    'Spin2 texture',
    null,
    'advanced',
    'power_aggressive',
    null,
    null,
    '{"declared_technologies":["15K Carbon","Spin2 Texture","Duo Grid"],"declared_shape":"diamond","declared_family":"Defy V1"}'::jsonb,
    'Manufacturer product announcement. Validate current product page before store-facing recommendations.',
    'wilson_defy_v1',
    '{}'
  )
on conflict (model_id) do update set
  brand = excluded.brand,
  model = excluded.model,
  model_year = excluded.model_year,
  shape = excluded.shape,
  weight_declared = excluded.weight_declared,
  balance_declared = excluded.balance_declared,
  frame_material = excluded.frame_material,
  face_material = excluded.face_material,
  core_material = excluded.core_material,
  surface = excluded.surface,
  thickness_mm = excluded.thickness_mm,
  level_recommended = excluded.level_recommended,
  style_recommended = excluded.style_recommended,
  price_amount = excluded.price_amount,
  price_currency = excluded.price_currency,
  technical_specs = excluded.technical_specs,
  reliability_notes = excluded.reliability_notes,
  manufacturer_source_id = excluded.manufacturer_source_id,
  secondary_source_ids = excluded.secondary_source_ids,
  updated_at = now();

insert into public.racket_comparisons (
  comparison_id,
  title,
  model_a_id,
  model_b_id,
  type_a_id,
  type_b_id,
  criteria_weights,
  result,
  deterministic_rule,
  source_policy,
  premium_available
)
values
  (
    'type_round_vs_diamond',
    'Racchetta rotonda controllo vs diamante potenza',
    null,
    null,
    'round_control',
    'diamond_power',
    '{"control":0.30,"power":0.25,"maneuverability":0.20,"comfort":0.15,"technical_demand":0.10}'::jsonb,
    '{"winner_for_beginner":"round_control","winner_for_power":"diamond_power","summary":"Round is safer for control and learning; diamond is stronger for advanced power but less forgiving."}'::jsonb,
    'Compare impact_scores using declared weighted criteria. Do not infer medical suitability.',
    'structured_fields_only',
    true
  ),
  (
    'type_teardrop_vs_round',
    'Racchetta a goccia ibrida vs rotonda controllo',
    null,
    null,
    'teardrop_hybrid',
    'round_control',
    '{"control":0.30,"power":0.25,"maneuverability":0.20,"comfort":0.15,"technical_demand":0.10}'::jsonb,
    '{"winner_for_first_racket":"round_control","winner_for_growth":"teardrop_hybrid","summary":"Round is more forgiving; teardrop gives more balanced growth once technique is stable."}'::jsonb,
    'Compare impact_scores and recommended_level only.',
    'structured_fields_only',
    true
  ),
  (
    'model_air_viper_vs_at10',
    'Babolat Air Viper 2.6 vs NOX AT10 Genius 18K Alum 2025',
    'babolat_air_viper_26',
    'nox_at10_genius_18k_alum_2025',
    null,
    null,
    '{"declared_weight":0.15,"shape":0.15,"core":0.20,"face_material":0.20,"style":0.30}'::jsonb,
    '{"comparison_mode":"field_presence_and_declared_positioning","summary":"Air Viper is positioned around dynamic aerial aggression; AT10 is declared as a high-control balanced pro model. Test on court before buying."}'::jsonb,
    'Use only manufacturer-declared fields; do not compare brand scores across manufacturers as objective lab values.',
    'structured_fields_only',
    true
  )
on conflict (comparison_id) do update set
  title = excluded.title,
  model_a_id = excluded.model_a_id,
  model_b_id = excluded.model_b_id,
  type_a_id = excluded.type_a_id,
  type_b_id = excluded.type_b_id,
  criteria_weights = excluded.criteria_weights,
  result = excluded.result,
  deterministic_rule = excluded.deterministic_rule,
  source_policy = excluded.source_policy,
  premium_available = excluded.premium_available;

insert into public.technique_topics (
  topic_id,
  shot_type,
  role,
  user_level,
  game_context,
  common_errors,
  linked_drills,
  rallymate_metrics,
  source_id
)
values
  (
    'technique_volley',
    'volee',
    'any',
    'beginner_to_intermediate',
    'Gioco a rete, costruzione del punto e chiusura controllata.',
    '["Swing troppo ampio","Cercare potenza prima della direzione","Racchetta bassa in attesa"]'::jsonb,
    '[{"training_id":"training_volley_control","label":"Volee di controllo"}]'::jsonb,
    array['unforced_errors','net_points_won','rally_length'],
    'lta_beginner_skills'
  ),
  (
    'technique_lob',
    'lob',
    'any',
    'all',
    'Difesa sotto pressione e transizione verso rete.',
    '["Lob corto","Colpo troppo piatto","Non salire dopo un lob efficace"]'::jsonb,
    '[{"training_id":"training_defense_lob","label":"Difesa e lob"}]'::jsonb,
    array['forced_errors_saved','transition_success','rally_recovery'],
    'lta_beginner_skills'
  ),
  (
    'technique_bandeja',
    'bandeja',
    'left_or_right_depending_position',
    'intermediate_to_advanced',
    'Gestione di lob intermedi mantenendo posizione a rete.',
    '["Trasformarla sempre in smash","Colpo troppo corto","Perdere equilibrio dopo l impatto"]'::jsonb,
    '[{"training_id":"training_bandeja_routine","label":"Bandeja e recupero rete"}]'::jsonb,
    array['overhead_errors','net_position_retained','point_control'],
    'head_shots_guide'
  ),
  (
    'technique_vibora',
    'vibora',
    'mostly_left_or_advanced_right',
    'intermediate_to_advanced',
    'Overhead aggressivo per creare palla scomoda e pressione.',
    '["Cercare effetto senza margine","Colpire in ritardo","Usarla quando serve solo controllo"]'::jsonb,
    '[{"training_id":"training_bandeja_routine","label":"Progressione bandeja-vibora"}]'::jsonb,
    array['overhead_winners','forced_errors','overhead_errors'],
    'padel_school_vibora'
  )
on conflict (topic_id) do update set
  shot_type = excluded.shot_type,
  role = excluded.role,
  user_level = excluded.user_level,
  game_context = excluded.game_context,
  common_errors = excluded.common_errors,
  linked_drills = excluded.linked_drills,
  rallymate_metrics = excluded.rallymate_metrics,
  source_id = excluded.source_id;

insert into public.tactical_topics (
  topic_id,
  tactic_type,
  role,
  situation,
  principles,
  common_mistakes,
  rallymate_metrics,
  source_id
)
values
  (
    'role_left_side',
    'role_selection',
    'left',
    'Scelta lato e responsabilita offensive della coppia.',
    '["Piu responsabilita sugli overhead","Copertura del centro con colpi aggressivi","Dipende da mano dominante e partnership"]'::jsonb,
    '["Trattare il ruolo come obbligatorio","Forzare smash senza posizione","Non coordinarsi con il compagno"]'::jsonb,
    array['partner_variance','overhead_success','decisive_points_won'],
    'padel_school_left_side'
  ),
  (
    'role_right_side',
    'role_selection',
    'right',
    'Scelta lato e responsabilita di costruzione/strategia.',
    '["Consistenza e lettura del punto","Creare occasioni per la coppia","Adattarsi alla mano dominante del compagno"]'::jsonb,
    '["Essere troppo passivi","Non comunicare","Forzare colpi a bassa percentuale"]'::jsonb,
    array['unforced_errors','assist_points','partner_variance'],
    'padel_school_right_side'
  ),
  (
    'tactic_pair_communication',
    'pair_communication',
    'pair',
    'Durante scambio, lob e transizioni.',
    '["Chiamate brevi","Accordi prima del match","Copertura del centro dichiarata"]'::jsonb,
    '["Parlare troppo tardi","Usare chiamate ambigue","Non decidere chi prende il centro"]'::jsonb,
    array['unforced_errors','center_errors','decisive_points_won'],
    'lta_beginner_skills'
  ),
  (
    'tactic_decisive_points',
    'pressure_management',
    'pair',
    'Tie-break, golden point e palle break.',
    '["Pattern ad alta percentuale","Primo servizio solido","Risposta profonda","Lob se sotto pressione"]'::jsonb,
    '["Cambiare piano all ultimo","Cercare winner immediato","Ridurre comunicazione"]'::jsonb,
    array['clutch_points_won','unforced_errors','serve_points_won'],
    'lta_beginner_skills'
  )
on conflict (topic_id) do update set
  tactic_type = excluded.tactic_type,
  role = excluded.role,
  situation = excluded.situation,
  principles = excluded.principles,
  common_mistakes = excluded.common_mistakes,
  rallymate_metrics = excluded.rallymate_metrics,
  source_id = excluded.source_id;

insert into public.training_knowledge (
  training_id,
  topic_id,
  objective,
  duration_minutes,
  level,
  role,
  materials,
  description,
  steps,
  mistakes_to_avoid,
  metric_to_watch,
  analytics_links,
  source_id,
  free_available,
  premium_available
)
values
  (
    'training_volley_control',
    'technique_volley',
    'Migliorare controllo, direzione e stabilita della volee.',
    18,
    'beginner',
    'any',
    array['campo','racchetta','palline','compagno o coach'],
    'Routine semplice per trasformare la volee in colpo stabile: meno swing, piu controllo e target chiari.',
    '[{"step":1,"text":"5 minuti di volee lente incrociate con swing corto."},{"step":2,"text":"5 minuti alternando profondita e palla ai piedi."},{"step":3,"text":"5 minuti con target grande verso angoli sicuri."},{"step":4,"text":"3 minuti di punto condizionato: winner solo dopo due volee controllate."}]'::jsonb,
    '["Swing ampio","Polso troppo attivo","Cercare winner sul primo colpo"]'::jsonb,
    'unforced_errors_at_net',
    array['net_points_won','unforced_errors','rally_length'],
    'lta_beginner_skills',
    true,
    true
  ),
  (
    'training_defense_lob',
    'technique_lob',
    'Usare il lob per uscire dalla pressione e recuperare posizione.',
    20,
    'beginner',
    'any',
    array['campo','racchetta','palline','compagno'],
    'Allenamento per trasformare situazioni difensive in transizioni ordinate verso rete.',
    '[{"step":1,"text":"5 minuti di lob da fondo campo senza pressione."},{"step":2,"text":"5 minuti dopo palla bassa o parete semplice."},{"step":3,"text":"5 minuti lob + salita controllata."},{"step":4,"text":"5 minuti punto condizionato: sotto pressione si deve giocare un lob profondo."}]'::jsonb,
    '["Lob corto","Non guardare posizione avversari","Restare fermi dopo un lob profondo"]'::jsonb,
    'successful_defensive_recovery',
    array['transition_success','forced_errors_saved','rally_recovery'],
    'lta_beginner_skills',
    true,
    true
  ),
  (
    'training_bandeja_routine',
    'technique_bandeja',
    'Gestire lob intermedi con bandeja sicura e ritorno a rete.',
    24,
    'intermediate',
    'left_or_right',
    array['campo','racchetta','palline','coach o lanciatore'],
    'Progressione per scegliere controllo e posizione invece di forzare smash da palla non ideale.',
    '[{"step":1,"text":"6 minuti di impatto controllato su lob morbidi."},{"step":2,"text":"6 minuti target profondo verso vetro laterale/fondo."},{"step":3,"text":"6 minuti bandeja + recupero posizione a rete."},{"step":4,"text":"6 minuti punto condizionato: su lob intermedio vietato lo smash."}]'::jsonb,
    '["Colpire troppo frontale","Perdere equilibrio","Non recuperare rete dopo il colpo"]'::jsonb,
    'net_position_retained_after_overhead',
    array['overhead_errors','net_position_retained','point_control'],
    'head_shots_guide',
    true,
    true
  ),
  (
    'training_serve_first_shot',
    'rule_service',
    'Rendere servizio e primo colpo una sequenza semplice e ripetibile.',
    16,
    'beginner',
    'any',
    array['campo','racchetta','palline'],
    'Routine per collegare servizio regolare, posizione e primo colpo senza cercare ace irrealistici.',
    '[{"step":1,"text":"4 minuti solo servizio nel box con target ampio."},{"step":2,"text":"4 minuti servizio + split step."},{"step":3,"text":"4 minuti servizio + prima volee controllata."},{"step":4,"text":"4 minuti mini-game iniziando sempre da seconda sicura."}]'::jsonb,
    '["Servire troppo forte","Entrare in campo senza equilibrio","Non preparare il primo colpo"]'::jsonb,
    'serve_points_started_in_play',
    array['serve_faults','first_shot_errors','serve_points_won'],
    'fip_rules_2026',
    true,
    true
  ),
  (
    'training_pair_communication',
    'tactic_pair_communication',
    'Ridurre indecisioni con chiamate semplici e ruoli chiari.',
    15,
    'all',
    'pair',
    array['campo','racchetta','palline','compagno'],
    'Routine breve per decidere chiamate comuni e applicarle in scambi semplici.',
    '[{"step":1,"text":"Scegliete 4 chiamate: mia, tua, sali, centro."},{"step":2,"text":"5 minuti scambi lenti chiamando ogni palla dubbia."},{"step":3,"text":"5 minuti lob obbligatorio con chiamata sali/scendi."},{"step":4,"text":"5 minuti punto libero con focus solo su comunicazione."}]'::jsonb,
    '["Chiamate lunghe","Parlare dopo l impatto","Non decidere il centro prima del punto"]'::jsonb,
    'center_confusion_errors',
    array['center_errors','unforced_errors','partner_variance'],
    'lta_beginner_skills',
    true,
    true
  ),
  (
    'training_decisive_points',
    'tactic_decisive_points',
    'Costruire pattern affidabili per tie-break, golden point e palle break.',
    22,
    'intermediate',
    'pair',
    array['campo','racchetta','palline','compagno'],
    'Allenamento premium per punti chiave: meno improvvisazione, piu sequenze ad alta percentuale.',
    '[{"step":1,"text":"Definite due pattern sicuri: servizio+volee e risposta profonda+lob."},{"step":2,"text":"8 punti partendo sempre da golden point."},{"step":3,"text":"8 punti partendo da 5-5 nel tie-break."},{"step":4,"text":"Debrief: segnate errore, scelta e comunicazione."}]'::jsonb,
    '["Cambiare schema sotto pressione","Cercare colpi spettacolari","Non parlare prima del punto"]'::jsonb,
    'clutch_points_won',
    array['clutch_points_won','unforced_errors','serve_points_won'],
    'lta_beginner_skills',
    false,
    true
  )
on conflict (training_id) do update set
  topic_id = excluded.topic_id,
  objective = excluded.objective,
  duration_minutes = excluded.duration_minutes,
  level = excluded.level,
  role = excluded.role,
  materials = excluded.materials,
  description = excluded.description,
  steps = excluded.steps,
  mistakes_to_avoid = excluded.mistakes_to_avoid,
  metric_to_watch = excluded.metric_to_watch,
  analytics_links = excluded.analytics_links,
  source_id = excluded.source_id,
  free_available = excluded.free_available,
  premium_available = excluded.premium_available;

insert into public.assistant_citations (
  topic_id,
  source_id,
  quote_snippet,
  paraphrase,
  url,
  accessed_at
)
values
  ('court_dimensions_net', 'fip_rules_2026', null, 'FIP defines the padel court as 10 by 20 metres and specifies net dimensions.', 'https://www.padelfip.com/wp-content/uploads/2025/12/FIP_Rules-of-Padel.pdf', date '2026-07-06'),
  ('rule_service', 'fip_rules_2026', null, 'FIP service rules define underhand service after a bounce and into the diagonal service box.', 'https://www.padelfip.com/wp-content/uploads/2025/12/FIP_Rules-of-Padel.pdf', date '2026-07-06'),
  ('rule_golden_point', 'fip_rules_2026', null, 'FIP rules describe the decisive point format and receiving-side choice.', 'https://www.padelfip.com/wp-content/uploads/2025/12/FIP_Rules-of-Padel.pdf', date '2026-07-06'),
  ('ball_official_specs', 'fip_balls_2024', null, 'FIP ball documentation defines official ball dimensions, mass, rebound and pressure categories.', 'https://www.padelfip.com/wp-content/uploads/2024/04/Balls.pdf', date '2026-07-06'),
  ('ball_vs_tennis', 'lta_padel_faq', null, 'LTA explains that padel balls and tennis balls are similar but have different pressure characteristics.', 'https://www.ltapadel.org.uk/play/padel-faqs/', date '2026-07-06'),
  ('racket_shapes', 'wilson_racket_guide', null, 'Wilson explains round, teardrop and diamond racket families with control/power tradeoffs.', 'https://www.wilson.com/en-us/blog/padel/how-tos/how-choose-padel-racket', date '2026-07-06'),
  ('technique_volley', 'lta_beginner_skills', null, 'LTA beginner guidance emphasizes control, communication and net-position fundamentals.', 'https://www.ltapadel.org.uk/play/how-to-get-started-playing-padel/skills-for-beginners/', date '2026-07-06'),
  ('technique_vibora', 'padel_school_vibora', null, 'The Padel School presents vibora as a more aggressive overhead option than bandeja.', 'https://thepadelschool.com/padel-tips/the-vibora-technique', date '2026-07-06'),
  ('role_left_side', 'padel_school_left_side', null, 'The Padel School explains left-side role responsibilities and overhead-oriented tactics.', 'https://thepadelschool.com/padel-tips/left-side-player', date '2026-07-06'),
  ('role_right_side', 'padel_school_right_side', null, 'The Padel School explains right-side role consistency, overhead choices and strategist framing.', 'https://thepadelschool.com/padel-tips/right-side-player', date '2026-07-06')
on conflict (topic_id, source_id, url, paraphrase) do nothing;

comment on table public.knowledge_embeddings is
  'Optional semantic index cache. This migration avoids requiring pgvector; production can replace embedding_values with vector when pgvector is enabled.';
