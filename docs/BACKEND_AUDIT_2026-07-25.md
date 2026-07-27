# Momentum — Audit backend Supabase · 2026-07-25

Progetto collegato via CLI: **`bbxomuvfczdkqcwsjfdm` (RallyMate)**.
Strumenti usati: `supabase db advisors --linked`, `supabase db lint --linked`,
`supabase migration list --linked`, `deno fmt/lint/check/test`.
(Il token MCP disponibile non ha permessi su questa organizzazione: tutte le
verifiche sono passate dalla CLI collegata.)

---

## 1. Drift migration: produzione era indietro di 5 · **risolto**

`supabase migration list --linked` mostrava 5 migration locali mai applicate:

| Migration | Contenuto |
|---|---|
| `20260721010000` | flussi invito social completi (push personalizzati, deep link, inviti team mirati) |
| `20260721120000` | grant di esecuzione su `has_active_entitlement`, `has_cloud_media_access`, `has_duo_access`, `has_pro_access` |
| `20260721130000` | quota assistant: ignora claim non finalizzati + cleanup |
| `20260721140000` | rebrand copy push/inviti → Momentum |
| `20260721150000` | rebrand knowledge base / FAQ → Momentum |

Effetto pratico: le notifiche push e le copy degli inviti in produzione
dicevano ancora "RallyMate".

### Due migration erano rotte e non erano mai state applicabili

**a) `20260721010000` — `SQLSTATE 42P13`**

`social_inbox()` passava da 6 a 7 colonne di ritorno (aggiunta `meta jsonb`),
ma il file usava `create or replace`: PostgreSQL non consente di cambiare il
tipo di ritorno di una funzione esistente. Corretto con `drop function if
exists` prima della creazione, e i grant (persi dal drop) sono ripristinati in
fondo al file:

```sql
drop function if exists public.social_inbox();
create function public.social_inbox() returns table (…, meta jsonb) …
revoke all on function public.social_inbox() from public, anon;
grant execute on function public.social_inbox() to authenticated, service_role;
```

**b) `20260721150000` — `SQLSTATE 42703`**

Aggiornava `public.knowledge_topics.body`, colonna **inesistente**. Lo schema
reale (`0007_padel_knowledge_base.sql`) ha `title`, `summary_short`,
`summary_extended`, `watch_summary`, `answer_blocks` (jsonb) e `search_text`.
La migration è stata riscritta sulle colonne reali, incluso il rebrand dentro
il JSON di `answer_blocks` e l'allineamento di `search_text`, più
`knowledge_clusters`, `padel_rules` e `rule_faqs_v2` (queste ultime in un blocco
`do $$ … $$` perché opzionali).

Entrambe le migration fallivano anche in `scripts/ci_local.sh`
(`run_supabase_db` → `supabase db reset`), quindi quel passo di CI non era mai
stato eseguito con successo su queste due.

### Stato finale

```
supabase db push  →  5/5 applicate
supabase migration list --linked  →  locale e remoto allineati
supabase db lint --linked --schema public  →  No schema errors found
supabase db advisors --linked --type performance  →  0 warning
```

---

## 2. Bypass di test attivo in produzione · **NON toccato, richiede una tua decisione**

Gli advisor riportano in produzione due funzioni che esistono solo nello script
temporaneo `backend/supabase/scripts/TEMP_TEST_MAX_ACCESS.sql`:

- `public.trg_test_max_access_after_profile_insert()`
- `public.trg_test_max_access_before_profile_update()`
- (più `public.is_test_max_access_enabled()`, eseguibile da `authenticated`)

Quello script — applicato a mano dal SQL Editor, **non presente in nessuna
migration** — fa sì che `has_active_entitlement()` restituisca `true` per
chiunque quando il flag `app_runtime_flags.test_max_access` è `'true'`, e
imposta `plan='coach'` + `premium_override=true` su tutti i profili, anche sui
nuovi iscritti (trigger). Lo script stesso avvisa: *"TESTING ONLY — do not
leave this on production stores."*

**Non l'ho revertito** perché il rollback porta tutti gli utenti a `free`,
azzera `premium_override` e impone un re-sync di RevenueCat per gli abbonati
reali: è una decisione di business, non un bug da correggere in autonomia.

Verifica dello stato attuale del flag (dal SQL Editor):

```sql
select key, value, updated_at from public.app_runtime_flags;
```

Il rollback completo è già scritto nella sezione `REVERT` in fondo a
`TEMP_TEST_MAX_ACCESS.sql`. Nota: il push delle migration **non** ha toccato
il bypass (nessuna delle 5 ridefinisce `has_active_entitlement`).

Esposizione diretta: bassa. Le due `trg_*` sono trigger function e una chiamata
RPC diretta fallisce comunque (*"trigger functions can only be called as
triggers"*). Il rischio reale è il bypass in sé, non l'RPC.

---

## 3. Altri esiti advisor

- **54 × `authenticated_security_definer_function_executable`** — è la
  superficie RPC legittima dell'app (social, duo, coach, inviti, push,
  wearable). Le 5 nuove rispetto a prima del push sono esattamente quelle
  introdotte/concesse dalle migration appena applicate:
  `has_cloud_media_access`, `has_duo_access`, `has_pro_access`,
  `invite_user_to_my_team`, `respond_team_invite`. Nessuna anomalia.
- **`auth_leaked_password_protection` disattivata** — hardening consigliato
  (controllo HaveIBeenPwned). È un'impostazione della dashboard Auth, non
  codice: va attivata da te.
- **Performance advisors: 0 warning.**

---

## 4. Edge Functions

```
deno fmt --check functions   →  1 file non formattato (assistant/index.ts) → corretto
deno lint functions          →  34 file, 0 problemi
deno check functions/*/index.ts →  11 function, 0 errori di tipo
deno test                    →  44 test, 0 failure
```

Il file non formattato avrebbe fatto fallire `run_supabase` in
`scripts/ci_local.sh`.

---

## 5. Nota di naming

La migration `20260719240000_p1_p2_team_join_and_invite_polish.sql` usa
`24` come ora nel timestamp: non è un orario valido, quindi la CLI non riesce a
formattarne la data in `migration list` (la mostra come stringa grezza).
Funziona, ma è un nome da evitare in futuro.

---

## 6. Garmin — partite riprendibili (parziale)

File nuovo `wear/garmin-connectiq/source/RallyMateResumable.mc`:
`RallyMateResumablePolicy` (stesse regole di merge di watchOS/Wear OS: il
terminale vince, la versione più alta vince, a parità vince il più recente) e
`RallyMateResumableStore` (persistenza in `Storage`, guardia di idempotenza,
rifiuto delle versioni vecchie). `RallyMateSync` accetta i messaggi
`MATCH_LIFECYCLE` e `RESUMABLE_SNAPSHOT`; il telefono li invia da
`WatchSyncService._publishToGarmin()` sullo stesso trasporto Connect IQ già
usato per `START_MATCH`.

5 nuovi test Run No Evil, binario di test compilato.

**Cosa manca:** l'azione di ripresa *dal_ Garmin. Il payload Connect IQ non
porta il journal e `RallyMateScoreModel.startMatch()` non accetta un log
eventi: farlo ripartire senza journal significherebbe ricominciare da 0–0, cioè
esattamente il bug che ho impedito sulle altre piattaforme. La strada corretta
è un round-trip `REQUEST_RESUME` → il telefono invia `START_MATCH` con il
journal completo, e non è stata implementata.

**Fitbit:** non toccato. Lì il telefono non parla direttamente con l'orologio:
passa dal `wearable-gateway`, quindi servirebbe prima un endpoint nuovo lato
backend. È una decisione separata.
