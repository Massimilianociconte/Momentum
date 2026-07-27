# RallyMate — Backend Supabase

Backend **minimo** (PRD 9.3): il piano Free usa il cloud soltanto per account
email e profilo essenziale; partite e allenamenti restano locali. Il cloud
completo serve backup Premium, social opt-in, link recap, coach marketplace e
assistant Pro.

## Struttura

```
migrations/
  0001_core.sql        # schema + RLS (profiles, backups, wrapped_cards,
                       # coach_*, assistant_queries, rules_faq)
  0002_functions.sql   # increment_card_views, set_plan (webhook RevenueCat)
  0003_seed_rules_faq.sql
  0004_social_light.sql
  0005_deepseek_admin_assistant.sql
  0006_assistant_reports.sql
  0007_padel_knowledge_base.sql
  0008_duo_mode.sql    # Duo Mode premium: duo_sessions (codice invito 2h,
                       # RPC duo_create_session/duo_join_session),
                       # duo_events (timeline append-only, seq server
                       # autorevole, RLS per-team), profiles.premium_override
                       # (tester senza acquisto, solo service role)
  20260711223214_wearable_provider_integrations.sql
                       # OAuth/provider tokens cifrati, pairing monouso,
                       # ingest idempotente e riepiloghi Google Health
  20260712023000_scope_wearable_event_idempotency.sql
                       # idempotenza isolata per account
  20260712024500_fitbit_command_queue.sql
                       # comandi Fitbit durevoli e legati al token proprietario
  20260712110305_premium_backup_v2.sql
                       # payload gerarchico Premium, integrita server-side,
                       # limite 20 MiB e RLS separata Free/Premium
  20260713031500_transient_data_retention.sql
                       # cleanup_transient_data(): retention giornaliera
                       # (pg_cron 03:17 UTC) di rate events, pairing/oauth
                       # scaduti, ingest ACKati, comandi chiusi, sessioni
                       # Duo concluse e assistant_queries oltre 180 giorni
  20260715123000_push_notifications.sql
                       # registry token privato, outbox idempotente, trigger
                       # social/coach e RPC service-role per il dispatcher
  20260715133000_push_notification_retention.sql
                       # audit consegne max 30 giorni, cleanup giornaliero
  20260715134500_push_token_minimization.sql
                       # rimozione immediata al logout e purge degli
                       # identificativi provider invalidati dopo 30 giorni
functions/
  recap/               # GET  pagina pubblica Rally Wrapped (HTML <8KB, CDN cache)
  assistant/           # POST Rally Pro Assistant (DeepSeek proxy con limiti+cache)
  coach-checkout/      # POST registrazione acquisto pacchetto + commissione
  delete-account/      # GET pagina istruzioni + POST cancellazione account cloud
  revenuecat-webhook/  # POST eventi RevenueCat → profiles.plan (set_plan)
  wearable-gateway/    # pairing, ingest/ACK, coda comandi Fitbit, plan gate
  google-health/       # OAuth, refresh, riepilogo giornaliero e revoca
  google-health-webhook/ # webhook Google firmato e idempotente
  push-dispatch/       # dispatcher server-only APNs/FCM con retry e invalidazione
```

## Setup

```bash
cd /path/to/RallyMate_App-padel
supabase login
supabase init --workdir backend             # solo se manca backend/supabase/config.toml
supabase link --project-ref <PROJECT_REF> --workdir backend
supabase db push --workdir backend          # applica le migrations
supabase functions deploy recap --no-verify-jwt --workdir backend
supabase functions deploy assistant --workdir backend
supabase functions deploy coach-checkout --workdir backend
supabase functions deploy delete-account --no-verify-jwt --workdir backend
supabase functions deploy revenuecat-webhook --no-verify-jwt --workdir backend
supabase functions deploy wearable-gateway --no-verify-jwt --workdir backend
supabase functions deploy google-health --no-verify-jwt --workdir backend
supabase functions deploy google-health-webhook --no-verify-jwt --workdir backend
supabase functions deploy push-dispatch --no-verify-jwt --workdir backend
supabase secrets set DEEPSEEK_API_KEY=<deepseek-api-key> --workdir backend
supabase secrets set DEEPSEEK_MODEL=deepseek-v4-flash --workdir backend
# opzionale; default già corretto
supabase secrets set DEEPSEEK_BASE_URL=https://api.deepseek.com --workdir backend
supabase secrets set REVENUECAT_WEBHOOK_SECRET=<random> --workdir backend
supabase secrets set GOOGLE_HEALTH_CLIENT_ID=<google-oauth-client-id> --workdir backend
supabase secrets set GOOGLE_HEALTH_CLIENT_SECRET=<google-oauth-client-secret> --workdir backend
supabase secrets set GOOGLE_HEALTH_REDIRECT_URI=https://<PROJECT_REF>.supabase.co/functions/v1/google-health --workdir backend
supabase secrets set WEARABLE_TOKEN_ENCRYPTION_KEY=<base64-32-random-bytes> --workdir backend
supabase secrets set GOOGLE_HEALTH_WEBHOOK_AUTHORIZATION='Bearer <random>' --workdir backend
supabase secrets set RALLYMATE_ALLOWED_ORIGINS=https://<public-domain> --workdir backend
supabase secrets set SUPPORT_EMAIL=<public-support-email> --workdir backend
supabase secrets set PUSH_DISPATCH_SECRET='<random-32-byte-secret>' --workdir backend
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(jq -c . /secure/path/firebase-service-account.json)" --workdir backend
supabase secrets set APNS_TEAM_ID=<apple-team-id> --workdir backend
supabase secrets set APNS_KEY_ID=<apns-key-id> --workdir backend
supabase secrets set APNS_PRIVATE_KEY="$(cat /secure/path/AuthKey_<KEY_ID>.p8)" --workdir backend
supabase secrets set APNS_BUNDLE_ID=com.rallymate.rallymate --workdir backend
```

### Attivazione push APNs/FCM

La migrazione push, i secret provider, la function e lo scheduler vanno
attivati come una sola release. Non applicare i trigger in produzione finché
il dispatcher non può consegnare, altrimenti l'outbox accumula eventi senza
consumer.

1. Android: scarica il solo `google-services.json` client nel percorso
   `apps/momentum/android/app/google-services.json` (ignorato da Git). Il
   service account FCM resta invece esclusivamente nel secret server-side
   `FCM_SERVICE_ACCOUNT_JSON`.
2. Apple: abilita Push Notifications sull'App ID/target Runner e crea una APNs
   Auth Key `.p8`; non aggiungere la chiave al progetto.
3. Genera una credenziale dispatcher separata, ad esempio
   `openssl rand -base64 32`, e impostala sia come secret della function sia
   nello scheduler protetto.
4. Deploya `push-dispatch`, imposta tutti i secret, applica le tre migrazioni
   push e soltanto alla fine abilita una chiamata POST ogni minuto a
   `https://<PROJECT_REF>.supabase.co/functions/v1/push-dispatch` con header
   `X-RallyMate-Push-Secret` e body `{"limit":25}`. Conserva il secret nel
   vault dello scheduler, mai nel SQL o nel repository.
5. Verifica manualmente una singola esecuzione:

```bash
curl --fail-with-body -X POST \
  "https://<PROJECT_REF>.supabase.co/functions/v1/push-dispatch" \
  -H "Content-Type: application/json" \
  -H "X-RallyMate-Push-Secret: $PUSH_DISPATCH_SECRET" \
  -d '{"limit":25}'
```

La risposta attesa a coda vuota è
`{"ok":true,"claimed":0,"sent":0}`. Esegui poi un test reale con due
account/dispositivi in foreground, background e app terminata; controlla
deep link, deduplicazione, disattivazione al logout e invalidazione token.

In Supabase Dashboard → Authentication → URL Configuration aggiungi esattamente
`rallymate://auth-callback` ai Redirect URLs. È il callback nativo usato per
conferma account, cambio email e recupero password; non contiene secrets.

### Account owner / super admin di test

Gli indirizzi owner non sono versionati nelle migration. Mantienili nel SQL
editor o nei secret del progetto, mai nel repository.

1. Crea il tuo normale account dall'app con email e password.
2. Dal SQL editor Supabase esegui:

```sql
select public.grant_super_admin_by_email('tua-email@example.com');
```

Questo imposta `profiles.account_role='super_admin'`, piano locale `coach`
per il test e limiti assistant più alti. La funzione non è eseguibile dai
client anon/auth: va usata solo da SQL editor o service role.

In alternativa, per un bypass server-side vincolato alla tua identità:

```bash
supabase secrets set RALLYMATE_SUPER_ADMIN_EMAILS=tua-email@example.com --workdir backend
# oppure
supabase secrets set RALLYMATE_SUPER_ADMIN_USER_IDS=<auth-user-uuid> --workdir backend
```

## Controllo costi (PRD Rischio 2)

| Leva | Implementazione |
|---|---|
| LLM solo premium | `assistant` verifica `profiles.plan ∈ {pro, coach}` o `account_role ∈ {admin, super_admin}` |
| Limiti | 20 domande/giorno, 5 live/partita; override per `super_admin` |
| Cache | risposta riusata 30gg su hash domanda normalizzata (costo zero) |
| RAG leggero prima del LLM | `rules_faq`, knowledge training/app e contesto locale sintetico iniettati nel prompt |
| Knowledge base padel | `knowledge_*`, `padel_rules`, `rule_faqs_v2`, `training_knowledge`, `racket_*`, `ball_types`, `court_features` |
| Modello economico | `deepseek-v4-flash`, thinking disabilitato per latenza/costo |
| Monitoraggio | `assistant_queries.cost_estimate_microusd` |
| Segnalazioni | `assistant_reports` raccoglie i report in-app delle risposte problematiche |

## Sicurezza

- RLS su tutte le tabelle; il client non può: cambiare il proprio `plan`,
  scrivere acquisti, scrivere query assistant.
- `plan` scritto solo da `set_plan` (service role / webhook RevenueCat).
- `account_role`, limiti assistant e super-admin sono immutabili dai client.
- `DEEPSEEK_API_KEY` vive solo nei secrets Supabase/Edge Function, mai in app.
- `assistant` accetta `surface=mobile|watch` e `clientContext` sintetico: il
  backend limita lunghezza, ricontrolla piano e non si fida del solo client.
- `assistant` carica la nuova knowledge base se presente; se la migration non
  e' ancora stata applicata, degrada sulle FAQ legacy senza bloccare il LLM.
- Acquisti coach idempotenti su `(store, store_tx_id)` — anti-replay.
- `coach-checkout` fallisce chiuso finché non è attiva una vera verifica
  ricevuta server-side; non esiste alcun bypass client o di ambiente.
- La lettura pubblica dei recap passa solo dalla edge function (rispetta
  `privacy`, incrementa `view_count`, cache CDN).

## Bloccanti prima di attivare il marketplace Coach

- Implementare `coach-checkout/verifyReceipt` con App Store Server API, Play
  Developer API o webhook RevenueCat e configurare i prodotti IAP. Fino ad
  allora il client non mostra acquisti e la function rifiuta ogni ricevuta.
- Storage/R2 per `wrapped_cards.image_url` (immagini card condivise).
