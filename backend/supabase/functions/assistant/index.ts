// Edge function: Pallino Assistant.
//
// DeepSeek V4 Flash integration. The mobile app never sees the API key:
// Flutter calls this authenticated Supabase Edge Function, the function checks
// Premium/Super Admin eligibility, then calls DeepSeek server-side.
//
// Required secret:
//   DEEPSEEK_API_KEY=<deepseek-api-key>
//
// Optional secrets:
//   DEEPSEEK_MODEL=deepseek-v4-flash
//   RALLYMATE_SUPER_ADMIN_EMAILS=owner@example.com
//   RALLYMATE_SUPER_ADMIN_USER_IDS=<uuid>,<uuid>

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  type AssistantProfileGate,
  resolveAssistantAccess,
} from "../_shared/assistant_access.ts";
import { persistAssistantQueryMutation } from "../_shared/assistant_query_lifecycle.ts";
import { hasActiveEntitlement } from "../_shared/entitlement.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const DEEPSEEK_KEY = Deno.env.get("DEEPSEEK_API_KEY") ?? "";
const DEEPSEEK_MODEL = Deno.env.get("DEEPSEEK_MODEL") ?? "deepseek-v4-flash";
const DEEPSEEK_BASE_URL = Deno.env.get("DEEPSEEK_BASE_URL") ??
  "https://api.deepseek.com";

// Limiti PRD: premium controllato lato server, con override admin esplicito.
const DEFAULT_DAILY_LIMIT = 20;
const DEFAULT_LIVE_MATCH_LIMIT = 5;
const SUPER_ADMIN_DAILY_LIMIT = 200;
const CACHE_DAYS = 30;
const CACHE_KEY_VERSION = "assistant-v17-kb-versioned-cited-sources";
// The cache key also carries a fingerprint of the knowledge base (below), so a
// migration that corrects a rule invalidates every cached answer built on the
// old text instead of serving it for up to CACHE_DAYS.
const KB_FINGERPRINT_TTL_MS = 5 * 60 * 1000;
const MAX_HISTORY_TURNS = 12;
const MAX_QUESTION_CHARS = 700;
const MAX_CONTEXT_CHARS = 2400;
const MAX_CLIENT_CONTEXT_CHARS = 2200;
const MAX_ANSWER_REPORT_CHARS = 4000;
const MAX_REPORT_DETAILS_CHARS = 1000;

const ALLOWED_MODES = [
  "RULES",
  "LIVE_MATCH",
  "POST_MATCH",
  "TRAINING",
  "APP_HELP",
] as const;

type AssistantMode = typeof ALLOWED_MODES[number];
type ChatMessage = { role: "user" | "assistant"; content: string };
type AssistantSurface = "mobile" | "watch";
type KnowledgeKind =
  | "rule"
  | "training"
  | "app"
  | "safety"
  | "client"
  | "court"
  | "ball"
  | "equipment"
  | "technique"
  | "tactics"
  | "role";
type KnowledgeDoc = {
  id: string;
  kind: KnowledgeKind;
  title: string;
  body: string;
  source: string;
  url?: string;
  certainty?: string;
  tags: string[];
};

let kbFingerprintCache: { value: string; expiresAt: number } | null = null;

/**
 * Version tag of the deployed knowledge base, memoized per isolate.
 *
 * Combines the latest `knowledge_versions` row with the rules FAQ edition and
 * its last update, so any forward migration that re-seeds rules or topics
 * produces a new cache namespace. Returns null when the fingerprint cannot be
 * read: the caller then skips the cache rather than risk serving an answer
 * built on superseded rules.
 */
async function knowledgeFingerprint(): Promise<string | null> {
  const now = Date.now();
  if (kbFingerprintCache && kbFingerprintCache.expiresAt > now) {
    return kbFingerprintCache.value;
  }
  try {
    const [versionRes, faqRes] = await Promise.all([
      supabase
        .from("knowledge_versions")
        .select("version_id, effective_date")
        .order("effective_date", { ascending: false })
        .order("version_id", { ascending: false })
        .limit(1)
        .maybeSingle(),
      supabase
        .from("rules_faq")
        .select("rules_version, updated_at")
        .order("updated_at", { ascending: false })
        .limit(1)
        .maybeSingle(),
    ]);
    if (versionRes.error || faqRes.error) {
      console.error(
        "kb_fingerprint_failed",
        versionRes.error?.message ?? faqRes.error?.message,
      );
      return null;
    }
    const value = [
      versionRes.data?.version_id ?? "no-kb-version",
      faqRes.data?.rules_version ?? "no-rules-version",
      faqRes.data?.updated_at ?? "no-rules-update",
    ].join("~");
    kbFingerprintCache = { value, expiresAt: now + KB_FINGERPRINT_TTL_MS };
    return value;
  } catch (error) {
    console.error("kb_fingerprint_failed", errorMessage(error));
    return null;
  }
}

/** Ids the model actually cited, as instructed by rule 8 of the system prompt. */
function citedDocs(answer: string, docs: KnowledgeDoc[]): KnowledgeDoc[] {
  const byId = new Map(docs.map((doc) => [doc.id.toLowerCase(), doc]));
  const used = new Map<string, KnowledgeDoc>();
  for (const match of answer.matchAll(/\[([A-Za-z0-9_:.\-]+)\]/g)) {
    const doc = byId.get(match[1].toLowerCase());
    if (doc) used.set(doc.id, doc);
  }
  return [...used.values()];
}

function toSourceRefs(docs: KnowledgeDoc[]) {
  return docs.map((d) => ({
    id: d.id,
    source: d.source,
    url: d.url,
    certainty: d.certainty,
    kind: d.kind,
    title: d.title,
  }));
}

/** Defense-in-depth: drop high-risk health tokens from client-supplied context. */
function scrubHealthLeakage(raw: string): string {
  if (!raw) return raw;
  const banned =
    /\b(healthkit|health connect|google health|oura|whoop|hrv|rmssd|bpm|heart rate|frequenza cardiaca|sonno|sleep session|passi|steps|calorie attive|active calories)\b/gi;
  const cleaned = raw.replace(banned, "[redacted-health]");
  return cleaned;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const jwt = req.headers.get("authorization")?.replace("Bearer ", "");
  if (!jwt) return json({ error: "unauthorized" }, 401);

  const { data: userData } = await supabase.auth.getUser(jwt);
  const user = userData?.user;
  if (!user) return json({ error: "unauthorized" }, 401);

  const body = await req.json().catch(() => null);
  const profile = await loadOrCreateProfile(user.id, user.email ?? "");
  const secretAdmin = isSecretAllowlisted(
    user.id,
    user.email ?? "",
    user.email_confirmed_at != null,
  );
  if (secretAdmin && profile.account_role !== "super_admin") {
    await markSuperAdmin(user.id, "edge-secret-allowlist");
    profile.account_role = "super_admin";
    profile.plan = "coach";
    profile.premium_override = true;
    profile.assistant_enabled = true;
    profile.assistant_daily_limit = SUPER_ADMIN_DAILY_LIMIT;
  }

  let activeEntitlement: boolean;
  try {
    activeEntitlement = await hasActiveEntitlement(
      supabase,
      user.id,
      ["pro", "coach"],
    );
  } catch (error) {
    console.error(
      "assistant entitlement lookup",
      error instanceof Error ? error.message : "unknown",
    );
    return json({ error: "temporarily_unavailable" }, 503);
  }
  const access = resolveAssistantAccess(profile, activeEntitlement);

  if (body?.action === "health") {
    return json({
      ok: true,
      authenticated: true,
      profileReady: true,
      entitled: access.entitled,
      assistantEnabled: profile.assistant_enabled,
      providerConfigured: DEEPSEEK_KEY.length > 0,
      modelConfigured: DEEPSEEK_MODEL.length > 0,
      effectivePlan: access.effectivePlan,
      edgeVersion: 14,
    });
  }

  if (!profile.assistant_enabled) {
    return json({ error: "assistant_disabled" }, 403);
  }
  if (!access.entitled) {
    return json({ error: "plan_required", requiredPlan: "pro" }, 403);
  }

  if (body?.action === "report") {
    await reportAssistantOutput(user.id, body ?? {});
    return json({ reported: true });
  }

  if (!DEEPSEEK_KEY) {
    return json({ error: "no_llm_configured" }, 503);
  }

  const question = (body?.question ?? "")
    .toString()
    .trim()
    .slice(0, MAX_QUESTION_CHARS);
  const mode = parseMode(body?.mode);
  const surface = parseSurface(body?.surface);
  const matchId = body?.matchId?.toString().slice(0, 120) ?? null;
  const matchContext = scrubHealthLeakage(
    (body?.matchContext ?? "").toString().slice(0, MAX_CONTEXT_CHARS),
  );
  const clientContext = scrubHealthLeakage(
    (body?.clientContext ?? "").toString().slice(0, MAX_CLIENT_CONTEXT_CHARS),
  );
  const history = sanitizeHistory(body?.history);
  if (!question) return json({ error: "empty_question" }, 400);

  const dailyLimit = access.privileged
    ? profile.assistant_daily_limit ?? SUPER_ADMIN_DAILY_LIMIT
    : profile.assistant_daily_limit ?? DEFAULT_DAILY_LIMIT;
  const liveLimit = access.privileged
    ? profile.assistant_live_limit ?? 30
    : profile.assistant_live_limit ?? DEFAULT_LIVE_MATCH_LIMIT;

  const kbVersion = await knowledgeFingerprint();
  const qHash = await sha256(
    `${CACHE_KEY_VERSION}|${kbVersion ?? "kb-unknown"}|${
      normalize(question)
    }|${mode}|${surface}|${access.cacheScope}`,
  );

  // Claim atomico dello slot (advisory lock + count + insert nella stessa
  // transazione, migrazione 20260715151000): N richieste parallele non
  // possono superare i limiti pagando comunque DeepSeek. La riga pending
  // (answer null) viene finalizzata a risposta ottenuta o eliminata se
  // l'LLM fallisce.
  const { data: claimRows, error: claimError } = await supabase.rpc(
    "claim_assistant_slot",
    {
      p_match_id: matchId,
      p_mode: mode,
      p_question: question,
      p_question_hash: qHash,
      p_user_id: user.id,
      p_daily_limit: dailyLimit,
      p_live_limit: liveLimit,
    },
  );
  const claim = Array.isArray(claimRows) ? claimRows[0] : claimRows;
  if (claimError || !claim) {
    console.error("claim_slot_failed", claimError?.message);
    return json({ error: "quota_check_failed" }, 500);
  }
  if (claim.reason === "daily_limit") {
    return json({ error: "daily_limit", remainingToday: 0 }, 429);
  }
  if (claim.reason === "live_limit") {
    return json({ error: "live_limit" }, 429);
  }
  const queryId = claim.query_id as string;
  const usedToday = Number(claim.used_today ?? 0);

  // kbVersion === null: the knowledge base edition could not be read, so a
  // cache hit cannot be proven current. Answer fresh instead of risking a
  // superseded rule.
  if (kbVersion && !matchContext && !clientContext && history.length === 0) {
    const since = new Date(Date.now() - CACHE_DAYS * 864e5).toISOString();
    const { data: hit } = await supabase
      .from("assistant_queries")
      .select("answer, sources")
      .eq("question_hash", qHash)
      .not("answer", "is", null)
      .gte("created_at", since)
      .limit(1)
      .maybeSingle();
    if (hit?.answer) {
      try {
        await finalizeQuery(
          queryId,
          hit.answer,
          hit.sources,
          DEEPSEEK_MODEL,
          true,
          0,
        );
      } catch (error) {
        console.error("assistant_query_finalize_failed", errorMessage(error));
        try {
          await releaseQuery(queryId);
        } catch (releaseError) {
          console.error(
            "assistant_query_release_failed",
            errorMessage(releaseError),
          );
        }
        return json({ error: "quota_persistence_failed" }, 503);
      }
      return json({
        answer: hit.answer,
        sources: hit.sources,
        cached: true,
        // finalizeQuery(cached=true) ha appena rimborsato lo slot: i
        // cache-hit non consumano quota (migrazione 20260715153000).
        remainingToday: dailyLimit - usedToday,
        model: DEEPSEEK_MODEL,
      });
    }
  }

  const [faq, knowledge] = await Promise.all([
    loadRulesFaq(),
    loadKnowledgeDocs(),
  ]);
  const retrieved = retrieveKnowledge({
    question,
    mode,
    faq,
    knowledge,
    clientContext,
    surface,
  });
  const knowledgeBlock = formatKnowledge(retrieved);

  const system = buildSystemPrompt(
    mode,
    knowledgeBlock,
    surface,
    access.promptContext,
  );
  const contextParts = [
    matchContext ? `Contesto partita/app:\n${matchContext}` : "",
    clientContext
      ? `Contesto locale sintetico autorizzato:\n${clientContext}`
      : "",
  ].filter(Boolean);
  const userMsg = contextParts.length
    ? `${contextParts.join("\n\n")}\n\nDomanda: ${question}`
    : question;
  const messages: ChatMessage[] = [
    ...history,
    { role: "user", content: userMsg },
  ];

  let answer = "";
  let cost = 0;
  try {
    ({ answer, cost } = await askDeepSeek(system, messages, surface));
    answer = sanitizeAssistantAnswer(answer, surface);
  } catch (error) {
    console.error("deepseek_unavailable", String(error).slice(0, 180));
    // Rimborso: lo slot reclamato non deve contare se l'utente non ha
    // ricevuto alcuna risposta.
    try {
      await releaseQuery(queryId);
    } catch (releaseError) {
      console.error(
        "assistant_query_release_failed",
        errorMessage(releaseError),
      );
      return json({ error: "quota_persistence_failed" }, 503);
    }
    return json({ error: "llm_unavailable" }, 502);
  }

  // Only the documents the answer actually cites are reported as sources.
  // Listing everything the retriever returned overstated the grounding: a
  // document can be retrieved and never used.
  const sources = toSourceRefs(citedDocs(answer, retrieved));

  try {
    await finalizeQuery(queryId, answer, sources, DEEPSEEK_MODEL, false, cost);
  } catch (error) {
    // LLM already succeeded: return the answer and free the pending slot so a
    // failed finalize does not burn quota for retries.
    console.error("assistant_query_finalize_failed", errorMessage(error));
    try {
      await releaseQuery(queryId);
    } catch (releaseError) {
      console.error(
        "assistant_query_release_failed",
        errorMessage(releaseError),
      );
    }
    return json({
      answer,
      sources,
      cached: false,
      remainingToday: Math.max(0, dailyLimit - usedToday),
      model: DEEPSEEK_MODEL,
      warning: "quota_persistence_failed",
    });
  }

  return json({
    answer,
    sources,
    cached: false,
    remainingToday: dailyLimit - usedToday - 1,
    model: DEEPSEEK_MODEL,
  });
});

async function askDeepSeek(
  system: string,
  messages: ChatMessage[],
  surface: AssistantSurface,
): Promise<{ answer: string; cost: number }> {
  const controller = new AbortController();
  const timeoutMs = surface === "watch" ? 8_000 : 14_000;
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  const resp = await fetch(`${DEEPSEEK_BASE_URL}/chat/completions`, {
    method: "POST",
    signal: controller.signal,
    headers: {
      authorization: `Bearer ${DEEPSEEK_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: DEEPSEEK_MODEL,
      messages: [{ role: "system", content: system }, ...messages],
      temperature: 0.35,
      max_tokens: surface === "watch" ? 240 : 720,
      stream: false,
      // V4 defaults to thinking mode; the app assistant favors low latency.
      thinking: { type: "disabled" },
    }),
  }).finally(() => clearTimeout(timeout));
  if (!resp.ok) {
    const text = await resp.text().catch(() => "");
    throw new Error(`deepseek_${resp.status}_${text.slice(0, 120)}`);
  }

  const data = await resp.json();
  const answer = (data.choices?.[0]?.message?.content ?? "").toString().trim();
  if (!answer) throw new Error("deepseek_empty_answer");

  const usage = data.usage ?? {};
  const promptTokens = Number(usage.prompt_tokens ?? 0);
  const hitTokens = Number(
    usage.prompt_cache_hit_tokens ?? usage.prompt_cache_hit ?? 0,
  );
  const missTokens = Number(
    usage.prompt_cache_miss_tokens ??
      Math.max(0, promptTokens - hitTokens),
  );
  const outputTokens = Number(usage.completion_tokens ?? 0);
  // Official V4 Flash pricing unit: USD per 1M tokens. Stored as micro-USD.
  const cost = Math.round(
    hitTokens * 0.0028 + missTokens * 0.14 + outputTokens * 0.28,
  );
  return { answer, cost };
}

function sanitizeAssistantAnswer(
  raw: string,
  surface: AssistantSurface,
): string {
  const maxChars = surface === "watch" ? 700 : 2400;
  return raw
    .replace(/<[^>]*>/g, "")
    .replace(/```/g, "")
    .split("\n")
    .map((line) => line.trimEnd())
    .filter((line, index, lines) =>
      line.trim().length > 0 ||
      (index > 0 && index < lines.length - 1 &&
        lines[index - 1].trim().length > 0)
    )
    .join("\n")
    .slice(0, maxChars)
    .trim();
}

function buildSystemPrompt(
  mode: AssistantMode,
  knowledgeBlock: string,
  surface: AssistantSurface,
  verifiedAccountContext: string,
): string {
  const modeBrief = {
    RULES:
      "Modalita regole: separa regola ufficiale e consiglio pratico. Per regole ufficiali usa solo la knowledge base FIP.",
    LIVE_MATCH:
      "Modalita partita live: rispondi in modo brevissimo e utile in movimento. Dai una sola azione consigliata.",
    POST_MATCH:
      "Modalita post-partita: collega statistiche, chimica di coppia/team e decisioni tecniche a un piano di miglioramento concreto. Usa i blocchi team/training del contesto locale se presenti.",
    TRAINING:
      "Modalita training: crea esercizi pratici, obiettivi settimanali e progressioni misurabili basandoti su catalogo training, log sessioni, RPE/ACWR e focus dal contesto locale. Non usare dati salute di sistema.",
    APP_HELP:
      "Modalita app-help: spiega come usare Momentum, account, backup, social, watch sync e piani Free/Plus/Pro senza inventare funzioni non presenti.",
  }[mode];

  const lengthRule = surface === "watch"
    ? "Rispondi per smartwatch: massimo 55 parole, frasi corte, una sola azione pratica."
    : "Rispondi per mobile: massimo 190 parole, leggibile e utile.";

  return `Sei Pallino, assistente premium di Momentum: competente, sportivo, ` +
    `chiaro e sintetico. Rispondi sempre in italiano. ${lengthRule} ` +
    `con tono incoraggiante ma professionale. Quando nomini l'app usa sempre ` +
    `"Momentum" (non RallyMate); quando parli di te stesso usa "Pallino" ` +
    `(non Rally Pro).\n\n` +
    `Contesto account verificato:\n${verifiedAccountContext}\n\n` +
    `${modeBrief}\n\n` +
    `Contesto locale autorizzato (se presente nel messaggio utente):\n` +
    `- Puoi usare profilo sportivo, form partite aggregate, catalogo e log di ` +
    `allenamento (RPE/minuti registrati in app), chimica team/coppie e scontri.\n` +
    `- Usa questi dati per: migliori coppie/team, scontri difficili, priorita ` +
    `di allenamento, progressioni e routine.\n` +
    `- Se un blocco dice "disabilitato dall'utente", non inventare metriche al suo posto.\n` +
    `- NON usare mai dati salute di piattaforma (HealthKit, Health Connect, ` +
    `Google Health, Oura, WHOOP, HR, sonno, calorie da health API). ` +
    `RPE/ACWR dei log app NON sono dati salute di sistema.\n\n` +
    `Regole ferree:\n` +
    `1. Non dare consigli medici o diagnosi.\n` +
    `2. Non sostituire arbitro, maestro o medico.\n` +
    `3. Non inventare regole: se le fonti qui sotto non coprono una regola, di' ` +
    `"non ho abbastanza certezza" e invita a verificare le FIP Rules of Padel.\n` +
    `4. Per supporto app, distingui le funzionalita Free, Plus, Pro e Coach, ` +
    `ma usa sempre il contesto account verificato per descrivere il piano corrente.\n` +
    `5. Non chiedere dati personali non necessari; non inventare email o ID account.\n` +
    `6. Non inventare winrate, sessioni o coppie assenti dal contesto locale.\n` +
    `7. Usa solo Markdown sicuro: titoli brevi con ##, **grassetto**, ` +
    `elenchi - e step 1. 2. 3. Niente HTML, tabelle o link non presenti nelle fonti.\n` +
    `8. Quando usi una fonte, inserisci il suo id tra parentesi quadre, es. [rule:serve_let].\n\n` +
    `Knowledge base recuperata:\n${knowledgeBlock}`;
}

async function loadRulesFaq(): Promise<
  {
    id: string;
    question: string;
    answer: string;
    source: string;
    keywords?: string[];
  }[]
> {
  const { data } = await supabase
    .from("rules_faq")
    .select("id, question, answer, source, rule_ref, rules_version, keywords")
    .limit(120);
  const legacy = ((data ?? []) as {
    id: string;
    question: string;
    answer: string;
    source: string;
    rule_ref?: string | null;
    rules_version?: string | null;
    keywords?: string[];
  }[]).map((item) => ({
    id: `legacy:${item.id}`,
    question: item.question,
    answer: item.answer,
    // The rule reference and the rulebook edition travel with the source so
    // the model can cite them instead of paraphrasing an unnumbered rule.
    source: [
      item.source,
      item.rule_ref,
      item.rules_version ? `ed. ${item.rules_version}` : null,
    ].filter(Boolean).join(", "),
    keywords: item.keywords,
  }));

  const { data: v2, error } = await supabase
    .from("rule_faqs_v2")
    .select(
      "faq_id, question, answer_short, answer_long, watch_answer, tags, source_id, certainty",
    )
    .limit(160);
  if (error) {
    console.warn("rule_faqs_v2_unavailable", error.message.slice(0, 120));
    return legacy;
  }

  const seeded = ((v2 ?? []) as {
    faq_id: string;
    question: string;
    answer_short: string;
    answer_long: string;
    watch_answer: string;
    tags: string[] | null;
    source_id: string;
    certainty: string;
  }[]).map((item) => ({
    id: `seed:${item.faq_id}`,
    question: item.question,
    answer:
      `${item.answer_short}\n${item.answer_long}\nWatch: ${item.watch_answer}`,
    source: `${item.source_id} (${item.certainty})`,
    keywords: item.tags ?? [],
  }));

  return [...seeded, ...legacy];
}

async function loadKnowledgeDocs(): Promise<KnowledgeDoc[]> {
  const { data: topics, error } = await supabase
    .from("knowledge_topics")
    .select(
      "topic_id, cluster_id, title, summary_short, summary_extended, watch_summary, difficulty, audience_level, free_tier, premium_tier, certainty, search_text",
    )
    .eq("publish_state", "published")
    .limit(180);
  if (error) {
    console.warn("knowledge_topics_unavailable", error.message.slice(0, 120));
    return [];
  }

  const rows = (topics ?? []) as {
    topic_id: string;
    cluster_id: string;
    title: string;
    summary_short: string;
    summary_extended: string;
    watch_summary: string;
    difficulty: string;
    audience_level: string[] | null;
    free_tier: boolean;
    premium_tier: boolean;
    certainty: string;
    search_text: string;
  }[];
  const topicIds = rows.map((row) => row.topic_id);
  if (topicIds.length === 0) return [];

  const [{ data: tagRows }, { data: linkRows }] = await Promise.all([
    supabase
      .from("knowledge_topic_tags")
      .select("topic_id, tag")
      .in("topic_id", topicIds),
    supabase
      .from("knowledge_topic_sources")
      .select("topic_id, source_id, evidence_note, confidence")
      .in("topic_id", topicIds),
  ]);

  const tagsByTopic = new Map<string, string[]>();
  for (const row of (tagRows ?? []) as { topic_id: string; tag: string }[]) {
    tagsByTopic.set(row.topic_id, [
      ...(tagsByTopic.get(row.topic_id) ?? []),
      row.tag,
    ]);
  }

  const links = (linkRows ?? []) as {
    topic_id: string;
    source_id: string;
    evidence_note: string;
    confidence: string;
  }[];
  const sourceIds = [...new Set(links.map((row) => row.source_id))];
  const { data: sourceRows } = sourceIds.length
    ? await supabase
      .from("knowledge_sources")
      .select("source_id, title, url, source_type, reliability")
      .in("source_id", sourceIds)
    : { data: [] };
  const sourceById = new Map(
    ((sourceRows ?? []) as {
      source_id: string;
      title: string;
      url: string;
      source_type: string;
      reliability: number;
    }[]).map((source) => [source.source_id, source]),
  );

  const linksByTopic = new Map<string, typeof links>();
  for (const link of links) {
    linksByTopic.set(link.topic_id, [
      ...(linksByTopic.get(link.topic_id) ?? []),
      link,
    ]);
  }

  return rows.map((row) => {
    const topicLinks = linksByTopic.get(row.topic_id) ?? [];
    const sourceLabels = topicLinks.map((link) => {
      const source = sourceById.get(link.source_id);
      if (!source) return `${link.source_id} (${link.confidence})`;
      return `${source.title} <${source.url}> (${source.source_type}, reliability ${source.reliability}/5)`;
    });
    const body = [
      row.summary_short,
      row.summary_extended,
      `Smartwatch: ${row.watch_summary}`,
      `Certezza: ${row.certainty}`,
      sourceLabels.length ? `Fonti: ${sourceLabels.join("; ")}` : "",
    ].filter(Boolean).join("\n");
    const firstSource = topicLinks[0]
      ? sourceById.get(topicLinks[0].source_id)
      : null;
    return {
      id: `kb:${row.topic_id}`,
      kind: kindFromCluster(row.cluster_id),
      title: row.title,
      body,
      source: sourceLabels.join("; ") || "Momentum knowledge base",
      url: firstSource?.url,
      certainty: row.certainty,
      tags: [
        row.cluster_id,
        row.difficulty,
        ...(row.audience_level ?? []),
        ...(row.free_tier ? ["free"] : []),
        ...(row.premium_tier ? ["premium"] : []),
        ...(tagsByTopic.get(row.topic_id) ?? []),
        ...tokenize(row.search_text).slice(0, 24),
      ],
    };
  });
}

function kindFromCluster(clusterId: string): KnowledgeKind {
  if (
    [
      "official_rules",
      "scoring_formats",
      "ambiguous_situations",
      "match_quick_faq",
      "smartwatch_faq",
    ].includes(clusterId)
  ) {
    return "rule";
  }
  if (clusterId === "court_surfaces") return "court";
  if (clusterId === "balls") return "ball";
  if (
    ["rackets", "racket_materials", "equipment_comparisons"].includes(clusterId)
  ) return "equipment";
  if (clusterId === "technique") return "technique";
  if (clusterId === "tactics") return "tactics";
  if (clusterId === "roles") return "role";
  if (clusterId === "training") return "training";
  return "app";
}

function retrieveKnowledge(args: {
  question: string;
  mode: AssistantMode;
  knowledge: KnowledgeDoc[];
  faq: {
    id: string;
    question: string;
    answer: string;
    source: string;
    keywords?: string[];
  }[];
  clientContext: string;
  surface: AssistantSurface;
}): KnowledgeDoc[] {
  const docs: KnowledgeDoc[] = [
    ...args.faq.map((f) => ({
      id: `rule:${f.id}`,
      kind: "rule" as const,
      title: f.question,
      body: f.answer,
      source: f.source,
      tags: f.keywords ?? [],
    })),
    ...args.knowledge,
    ...trainingKnowledge,
    ...appKnowledge,
    ...safetyKnowledge,
  ];

  if (args.clientContext.trim().length > 0) {
    docs.unshift({
      id: "client:local_context",
      kind: "client",
      title: "Contesto locale sintetico dell'app",
      body: args.clientContext,
      source: "Momentum local-first context, inviato dal client autenticato",
      tags: [
        "contesto",
        "locale",
        "training",
        "partita",
        "profilo",
        "team",
        "coppie",
        "winrate",
        "rpe",
        "acwr",
      ],
    });
  }

  const modeQuery = [
    args.mode === "TRAINING"
      ? "allenamento routine esercizi carico rpe acwr team coppie training log"
      : "",
    args.mode === "APP_HELP" ? "account backup premium watch app privacy" : "",
    args.mode === "POST_MATCH"
      ? "analisi partita errori statistiche focus team coppie scontri winrate"
      : "",
    args.mode === "LIVE_MATCH" ? "partita live consiglio breve tattica" : "",
  ].join(" ");
  const directTokens = new Set(tokenize(args.question));
  const contextTokens = new Set(
    tokenize(modeQuery).filter((token) => !directTokens.has(token)),
  );
  const kindBoost: Record<AssistantMode, Record<KnowledgeKind, number>> = {
    RULES: {
      rule: 3.0,
      court: 1.6,
      ball: 1.4,
      equipment: 0.7,
      technique: 0.5,
      tactics: 0.5,
      role: 0.4,
      training: 0.4,
      app: 0.2,
      safety: 0.5,
      client: 1.0,
    },
    LIVE_MATCH: {
      rule: 1.6,
      court: 0.8,
      ball: 0.6,
      equipment: 0.3,
      technique: 1.7,
      tactics: 1.8,
      role: 1.1,
      training: 1.2,
      app: 0.2,
      safety: 0.5,
      client: 2.0,
    },
    POST_MATCH: {
      rule: 0.6,
      court: 0.4,
      ball: 0.4,
      equipment: 0.5,
      technique: 2.0,
      tactics: 2.0,
      role: 1.5,
      training: 2.0,
      app: 0.2,
      safety: 0.5,
      client: 2.4,
    },
    TRAINING: {
      rule: 0.3,
      court: 0.4,
      ball: 0.3,
      equipment: 0.5,
      technique: 2.5,
      tactics: 2.1,
      role: 1.4,
      training: 3.0,
      app: 0.3,
      safety: 0.8,
      client: 2.2,
    },
    APP_HELP: {
      rule: 0.2,
      court: 0.5,
      ball: 0.5,
      equipment: 1.2,
      technique: 0.5,
      tactics: 0.5,
      role: 0.5,
      training: 0.4,
      app: 3.0,
      safety: 0.8,
      client: 1.2,
    },
  };

  const preferredKinds: Record<AssistantMode, Set<KnowledgeKind>> = {
    RULES: new Set(["rule", "court", "ball", "safety"]),
    LIVE_MATCH: new Set([
      "rule",
      "technique",
      "tactics",
      "role",
      "safety",
    ]),
    POST_MATCH: new Set([
      "technique",
      "tactics",
      "role",
      "training",
      "safety",
    ]),
    TRAINING: new Set([
      "technique",
      "tactics",
      "role",
      "training",
      "safety",
    ]),
    APP_HELP: new Set(["app", "safety"]),
  };
  const resultLimit = args.surface === "watch"
    ? 3
    : args.mode === "APP_HELP"
    ? 5
    : 7;

  return docs
    .map((doc) => {
      const haystack = new Set(tokenize([
        doc.id,
        doc.title,
        doc.body,
        ...doc.tags,
      ].join(" ")));
      const title = normalize(doc.title);
      const tagTokens = new Set(doc.tags.flatMap((tag) => tokenize(tag)));
      let score = kindBoost[args.mode][doc.kind];
      let directHits = 0;
      let contextHits = 0;
      for (const token of directTokens) {
        let matched = false;
        if (haystack.has(token)) {
          score += 3.0;
          matched = true;
        }
        if (tagTokens.has(token)) {
          score += 2.5;
          matched = true;
        }
        if (title.includes(token)) {
          score += 2.0;
          matched = true;
        }
        if (matched) directHits += 1;
      }
      for (const token of contextTokens) {
        if (haystack.has(token)) {
          score += 0.35;
          contextHits += 1;
        }
      }
      const preferred = preferredKinds[args.mode].has(doc.kind);
      const eligible = doc.kind === "client" ||
        (preferred && (directHits > 0 || contextHits > 0)) ||
        (args.mode !== "APP_HELP" && directHits > 0);
      return { doc, score, eligible };
    })
    .filter(({ score, eligible }) => eligible && score > 0.8)
    .sort((a, b) => b.score - a.score)
    .slice(0, resultLimit)
    .map(({ doc }) => doc);
}

function formatKnowledge(docs: KnowledgeDoc[]): string {
  if (docs.length === 0) {
    return "- Nessuna fonte recuperata. Se non sei certo, dichiara il limite.";
  }
  return docs
    .map((doc) =>
      `[${doc.id}] ${doc.title}\n` +
      `Tipo: ${doc.kind}\n` +
      `Fonte: ${doc.source}\n` +
      (doc.url ? `URL: ${doc.url}\n` : "") +
      (doc.certainty ? `Certezza: ${doc.certainty}\n` : "") +
      `Contenuto: ${doc.body}`
    )
    .join("\n\n");
}

const trainingKnowledge: KnowledgeDoc[] = [
  {
    id: "training:base_templates",
    kind: "training",
    title: "Template training gratuiti",
    body:
      "Gli utenti Free hanno routine statiche locali: volée di controllo, uscita di parete, bandeja base, servizio + primo colpo, difesa e lob. Sono utili per iniziare senza AI e senza costi cloud.",
    source: "Momentum training seed locale",
    tags: ["training", "free", "volée", "parete", "bandeja", "servizio", "lob"],
  },
  {
    id: "training:premium_templates",
    kind: "training",
    title: "Programmi training premium",
    body:
      "Plus/Pro sbloccano programmi guidati: smash e recupero rete, transizione difesa-attacco, pressione su servizio/risposta, condizionamento padel-specifico, programmi per giocatore destra/sinistra/flex e clutch tie-break.",
    source: "Momentum training seed premium",
    tags: [
      "premium",
      "smash",
      "transizione",
      "pressione",
      "condizionamento",
      "tie-break",
    ],
  },
  {
    id: "training:load",
    kind: "training",
    title: "Carico allenamento e RPE",
    body:
      "Momentum calcola il carico con session-RPE: minuti x sforzo percepito. ACWR 0.8-1.3 è zona ottimale; sopra 1.5 suggerisce recupero o sessione tecnica leggera. Non è un consiglio medico.",
    source: "Momentum TrainingLoad",
    tags: ["rpe", "acwr", "carico", "recupero", "minuti"],
  },
  {
    id: "training:focus",
    kind: "training",
    title: "Focus dai dati partita",
    body:
      "Il focus settimanale deriva da tie-break, punti decisivi, clutch score, win rate e difficoltà avversaria. Senza dati, l'app consiglia base dati: volée, uscita parete e riscaldamento.",
    source: "Momentum recommendFocus",
    tags: ["focus", "clutch", "win rate", "tie-break", "punti decisivi"],
  },
];

const appKnowledge: KnowledgeDoc[] = [
  {
    id: "app:free_vs_premium",
    kind: "app",
    title: "Differenza Free Plus Pro Coach",
    body:
      "Free: scoring locale, storico, 3 team, analytics base, FAQ regole e training base. Plus: backup cloud, analytics avanzate, Wrapped illimitato, training premium e team illimitati. Pro: Pallino Assistant (AI), Health Connect/Apple Salute, difficoltà avanzata e classifiche. Coach: strumenti coach e marketplace.",
    source: "Momentum entitlements",
    tags: ["free", "plus", "pro", "coach", "premium", "abbonamento"],
  },
  {
    id: "app:privacy",
    kind: "app",
    title: "Privacy e local-first",
    body:
      "Momentum funziona offline. Match, eventi, statistiche e dati salute restano sul dispositivo salvo funzioni cloud opzionali. Pallino Assistant (Pro/Coach) riceve domanda, cronologia, eventuale contesto partita e un contesto locale sintetico: profilo sportivo, stats partite, log/catalogo allenamento (RPE/minuti app), chimica team/coppie. Mai HealthKit/Health Connect/Google Health/Oura/WHOOP, email o ID account. L'utente puo disattivare training/team dal toggle privacy.",
    source: "Momentum privacy policy",
    tags: [
      "privacy",
      "locale",
      "cloud",
      "dati salute",
      "ai",
      "team",
      "training",
    ],
  },
  {
    id: "app:watch",
    kind: "app",
    title: "Smartwatch e sync",
    body:
      "Lo smartwatch serve per segnare punti rapidamente. Mantiene il log eventi locale, sincronizza col telefono quando disponibile e usa eventi idempotenti per evitare duplicati.",
    source: "Momentum watch sync contract",
    tags: ["watch", "smartwatch", "sync", "offline", "eventi"],
  },
  {
    id: "app:account_deletion",
    kind: "app",
    title: "Eliminazione account",
    body:
      "L'account e i dati cloud si eliminano da Profilo/Gestisci account con doppia conferma e digitazione ELIMINA. Per chi ha disinstallato l'app, le stesse istruzioni devono essere pubblicate sul sito Momentum indicato nella privacy policy.",
    source: "Momentum delete-account flow",
    tags: ["account", "eliminazione", "privacy", "cloud"],
  },
  {
    id: "app:health",
    kind: "app",
    title: "Salute e fitness",
    body:
      "Le integrazioni salute sono Pro e facoltative. Health Connect e HealthKit leggono aggregati locali; Apple Watch può scrivere una sessione workout solo con consenso. La connessione separata Google Health Pro può conservare sul backend aggregati giornalieri autorizzati per massimo 30 giorni. I dati salute di sistema sono revocabili e non vengono MAI usati per pubblicità, social ranking o contesto AI di Pallino. Distingui: i log di allenamento in-app (RPE/minuti) non sono campioni HealthKit/HC.",
    source: "Momentum health integration",
    tags: ["health", "salute", "fitness", "health connect", "healthkit", "pro"],
  },
  {
    id: "app:team_training_context",
    kind: "app",
    title: "Contesto team e training per Pallino",
    body:
      "Per piani Pro/Coach, Pallino puo usare riassunti locali di team (nomi, ruoli, winrate, clutch, tag avversari) e di allenamento (catalogo, sessioni, RPE, ACWR) per consigli su migliori coppie, scontri e routine. Non include note libere lunghe, immagini, email o dati salute di sistema. Se l'utente disattiva il toggle, questi blocchi non vengono inviati.",
    source: "Momentum assistant context policy",
    tags: [
      "team",
      "coppie",
      "allenamento",
      "training",
      "winrate",
      "pallino",
      "contesto",
    ],
  },
];

const safetyKnowledge: KnowledgeDoc[] = [
  {
    id: "safety:no_medical",
    kind: "safety",
    title: "Nessun consiglio medico",
    body:
      "Allenamenti, RPE, carico e recupero sono indicazioni generali sportive. In presenza di dolore, patologie, infortunio o dubbi sanitari, consiglia di fermarsi e sentire un professionista.",
    source: "Momentum safety policy",
    tags: ["sicurezza", "medico", "dolore", "infortunio", "recupero"],
  },
];

async function loadOrCreateProfile(
  userId: string,
  email: string,
): Promise<AssistantProfileGate> {
  const selectCols =
    "plan, account_role, premium_override, assistant_enabled, assistant_daily_limit, assistant_live_limit";

  const { data } = await supabase
    .from("profiles")
    .select(selectCols)
    .eq("user_id", userId)
    .maybeSingle();
  if (data) return data as AssistantProfileGate;

  const { error: insertError } = await supabase.from("profiles").insert({
    user_id: userId,
    name: email.split("@")[0] ?? "",
  });

  // Re-read so AFTER INSERT triggers (e.g. TEMP max-access / super-admin)
  // are reflected in plan, override and quotas.
  const { data: created, error: readError } = await supabase
    .from("profiles")
    .select(selectCols)
    .eq("user_id", userId)
    .maybeSingle();
  if (created) return created as AssistantProfileGate;

  console.error(
    "profile_bootstrap_failed",
    insertError?.message ?? "insert_unknown",
    readError?.message ?? "read_unknown",
  );
  return {
    plan: "free",
    account_role: "user",
    premium_override: false,
    assistant_enabled: true,
    assistant_daily_limit: DEFAULT_DAILY_LIMIT,
    assistant_live_limit: DEFAULT_LIVE_MATCH_LIMIT,
  };
}

async function markSuperAdmin(userId: string, source: string) {
  await supabase.from("profiles").update({
    plan: "coach",
    account_role: "super_admin",
    premium_override: true,
    assistant_enabled: true,
    assistant_daily_limit: SUPER_ADMIN_DAILY_LIMIT,
    assistant_live_limit: 30,
  }).eq("user_id", userId);
  await supabase.from("admin_test_accounts").upsert({
    user_id: userId,
    purpose: "owner deepseek assistant testing",
    granted_by: source,
    active: true,
  });
}

async function reportAssistantOutput(
  userId: string,
  body: Record<string, unknown>,
) {
  const question = (body?.question ?? "")
    .toString()
    .trim()
    .slice(0, MAX_QUESTION_CHARS);
  const answer = (body?.answer ?? "")
    .toString()
    .trim()
    .slice(0, MAX_ANSWER_REPORT_CHARS);
  const details = (body?.details ?? "")
    .toString()
    .trim()
    .slice(0, MAX_REPORT_DETAILS_CHARS);
  const rawReason = (body?.reason ?? "other").toString();
  const reason = [
      "offensive_or_unsafe",
      "dangerous_advice",
      "wrong_rule",
      "privacy_issue",
      "other",
    ].includes(rawReason)
    ? rawReason
    : "other";

  if (!answer) throw new Error("empty_report");
  await supabase.from("assistant_reports").insert({
    user_id: userId,
    mode: parseMode(body?.mode),
    question,
    answer,
    reason,
    details,
  });
}

function isSecretAllowlisted(
  userId: string,
  email: string,
  emailConfirmed: boolean,
): boolean {
  const ids = csv(Deno.env.get("RALLYMATE_SUPER_ADMIN_USER_IDS"));
  const emails = csv(Deno.env.get("RALLYMATE_SUPER_ADMIN_EMAILS"))
    .map((e) => e.toLowerCase());
  return ids.includes(userId) ||
    (emailConfirmed && email.length > 0 &&
      emails.includes(email.toLowerCase()));
}

function csv(value: string | undefined | null): string[] {
  return (value ?? "")
    .split(",")
    .map((v) => v.trim())
    .filter(Boolean);
}

function parseMode(raw: unknown): AssistantMode {
  const mode = raw?.toString() as AssistantMode | undefined;
  return mode && ALLOWED_MODES.includes(mode) ? mode : "RULES";
}

function parseSurface(raw: unknown): AssistantSurface {
  return raw?.toString() === "watch" ? "watch" : "mobile";
}

function sanitizeHistory(raw: unknown): ChatMessage[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((m) =>
      m && (m.role === "user" || m.role === "assistant") &&
      typeof m.content === "string"
    )
    .slice(-MAX_HISTORY_TURNS)
    .map((m) => ({
      role: m.role as "user" | "assistant",
      content: (m.content as string).slice(0, 1000),
    }));
}

function normalize(q: string): string {
  return q.toLowerCase().replace(/[^\p{L}\p{N} ]/gu, "").trim();
}

function tokenize(text: string): string[] {
  const stop = new Set([
    "il",
    "lo",
    "la",
    "i",
    "gli",
    "le",
    "un",
    "una",
    "di",
    "a",
    "da",
    "in",
    "con",
    "su",
    "per",
    "che",
    "come",
    "quando",
    "dove",
    "cosa",
    "e",
    "o",
    "ma",
    "se",
    "non",
    "mi",
    "me",
    "tu",
    "io",
    "è",
    "sono",
    "fare",
    "posso",
  ]);
  return normalize(text)
    .split(/\s+/)
    .map((t) => t.trim())
    .filter((t) => t.length > 1 && !stop.has(t));
}

async function sha256(s: string): Promise<string> {
  const buf = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(s),
  );
  return [...new Uint8Array(buf)]
    .map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function finalizeQuery(
  queryId: string,
  answer: string,
  sources: unknown,
  model: string | null,
  cached: boolean,
  cost: number,
) {
  await persistAssistantQueryMutation("finalize", async () => {
    const { data, error } = await supabase
      .from("assistant_queries")
      .update({
        answer,
        sources,
        model,
        cached,
        cost_estimate_microusd: cost,
      })
      .eq("query_id", queryId)
      .select("query_id")
      .maybeSingle();
    return { error, settled: data?.query_id === queryId };
  });
}

async function releaseQuery(queryId: string) {
  await persistAssistantQueryMutation("release", async () => {
    const { error } = await supabase
      .from("assistant_queries")
      .delete()
      .eq("query_id", queryId);
    // DELETE of a missing row is successful: this makes retries after an
    // uncertain response safe and confirms the desired absent state.
    return { error, settled: !error };
  });
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message.slice(0, 220) : "unknown";
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
