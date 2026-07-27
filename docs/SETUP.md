# Setup credenziali — checklist per andare live

L'app è **completa e funzionante offline senza alcuna credenziale**:
scoring, storico, analytics, team, FAQ regole, card immagine, allenamenti,
watch sync. Le credenziali attivano le feature cloud/premium.

## 1. Supabase (account, backup Plus, link recap, assistant Pro, coach)

```bash
# a) crea il progetto su https://supabase.com → copia URL + anon key
# b) login CLI e collega il progetto giusto
supabase login
cd backend/supabase
supabase link --project-ref <PROJECT_REF>

# c) applica schema, knowledge base, social/Duo e provider wearable
supabase db push

# d) deploy edge functions
# Deploy recap only after configuring a custom Supabase domain (or moving the
# page to a static web host) and real store URLs; shared Supabase domains force
# browser-renderable HTML to text/plain.
supabase functions deploy recap --no-verify-jwt
supabase functions deploy assistant
supabase functions deploy coach-checkout
supabase functions deploy delete-account --no-verify-jwt
supabase functions deploy revenuecat-webhook --no-verify-jwt
supabase functions deploy wearable-gateway --no-verify-jwt
supabase functions deploy google-health --no-verify-jwt
supabase functions deploy google-health-webhook --no-verify-jwt
supabase functions deploy health-provider --no-verify-jwt
supabase functions deploy health-provider-webhook --no-verify-jwt
supabase functions deploy push-dispatch --no-verify-jwt

# e) secrets — il chatbot Pro usa DeepSeek V4 Flash server-side.
supabase secrets set DEEPSEEK_API_KEY=<deepseek-api-key>
supabase secrets set DEEPSEEK_MODEL=deepseek-v4-flash
supabase secrets set DEEPSEEK_BASE_URL=https://api.deepseek.com   # opzionale
supabase secrets set REVENUECAT_WEBHOOK_SECRET=<random>    # webhook piani
supabase secrets set GOOGLE_HEALTH_CLIENT_ID=<google-oauth-client-id>
supabase secrets set GOOGLE_HEALTH_CLIENT_SECRET=<google-oauth-client-secret>
supabase secrets set GOOGLE_HEALTH_REDIRECT_URI=https://<PROJECT_REF>.supabase.co/functions/v1/google-health
supabase secrets set WEARABLE_TOKEN_ENCRYPTION_KEY=<base64-32-random-bytes>
supabase secrets set GOOGLE_HEALTH_WEBHOOK_AUTHORIZATION='Bearer <random-webhook-credential>'
supabase secrets set RALLYMATE_ALLOWED_ORIGINS=https://<public-rallymate-domain>
# Set only after the listings exist; recap hides the CTA while absent.
supabase secrets set RALLYMATE_APP_STORE_URL=https://apps.apple.com/app/id<APP_ID>
supabase secrets set RALLYMATE_PLAY_STORE_URL=https://play.google.com/store/apps/details?id=com.rallymate.rallymate
supabase secrets set PUSH_DISPATCH_SECRET='<random-32-byte-secret>'
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(jq -c . /secure/path/firebase-service-account.json)"
supabase secrets set APNS_TEAM_ID=<apple-team-id>
supabase secrets set APNS_KEY_ID=<apns-key-id>
supabase secrets set APNS_PRIVATE_KEY="$(cat /secure/path/AuthKey_<KEY_ID>.p8)"
supabase secrets set APNS_BUNDLE_ID=com.rallymate.rallymate
supabase secrets list
```

Le push richiedono anche il file client Android
`apps/rallymate/android/app/google-services.json`, la capability Push
Notifications sul target iOS e un job POST ogni minuto verso
`/functions/v1/push-dispatch`, autenticato con
`X-Momentum-Push-Secret`. Non committare il file service account, la chiave
APNs `.p8` o il secret dispatcher. Attiva migrazioni push, function, secret e
scheduler come una sola release; fino ad allora lascia lo scheduler spento.

Test manuale del dispatcher:

```bash
curl --fail-with-body -X POST \
  "https://<PROJECT_REF>.supabase.co/functions/v1/push-dispatch" \
  -H "Content-Type: application/json" \
  -H "X-Momentum-Push-Secret: $PUSH_DISPATCH_SECRET" \
  -d '{"limit":25}'
```

Le integrazioni dirette Oura e WHOOP sono predisposte, ma il rollout resta
`DISABLED` finché non sono approvate e testate con account reali. Solo dopo
l'approvazione dei provider configura i secret seguenti:

```bash
supabase secrets set OURA_CLIENT_ID=<oura-client-id>
supabase secrets set OURA_CLIENT_SECRET=<oura-client-secret>
supabase secrets set OURA_REDIRECT_URI=https://<PROJECT_REF>.supabase.co/functions/v1/health-provider/oura/callback
supabase secrets set WHOOP_CLIENT_ID=<whoop-client-id>
supabase secrets set WHOOP_CLIENT_SECRET=<whoop-client-secret>
supabase secrets set WHOOP_REDIRECT_URI=https://<PROJECT_REF>.supabase.co/functions/v1/health-provider/whoop/callback
supabase secrets set WHOOP_WEBHOOK_SECRET=<whoop-webhook-signing-secret>
```

Registra gli stessi redirect nei portali provider e configura in WHOOP il
webhook v2:
`https://<PROJECT_REF>.supabase.co/functions/v1/health-provider-webhook`.
Non modificare il rollout prima di avere completato consenso, refresh token,
revoca, cancellazione, webhook firmato e test della retention:

```sql
update public.health_provider_features
set rollout = 'INTERNAL', updated_at = now()
where provider in ('OURA_DIRECT', 'WHOOP_DIRECT');
```

Passa a `BETA` o `PRODUCTION` solo dopo la relativa approvazione; non serve
alcuna chiave Oura/WHOOP nel client Flutter.

La chiave DeepSeek NON va mai in `--dart-define`, `Info.plist`,
`AndroidManifest`, `.env` committati o codice Flutter. Va salvata solo nei
Supabase Edge Function secrets, perché l'app chiama la function `assistant`
con il JWT dell'utente e la function chiama DeepSeek con
`Deno.env.get('DEEPSEEK_API_KEY')`.

Verifica rapida della function:

```bash
# API pubblica: il GET risponde anche sul dominio condiviso, ma Supabase forza
# l'HTML a text/plain. Per Play Console pubblica la pagina equivalente sul sito
# Momentum o abilita un custom domain Supabase.
curl -i https://<PROJECT_REF>.supabase.co/functions/v1/delete-account

# assistant richiede sempre JWT utente: Free deve ricevere plan_required,
# Pro/super_admin deve ricevere answer + sources.
curl -i -X POST https://<PROJECT_REF>.supabase.co/functions/v1/assistant \
  -H "Authorization: Bearer <USER_JWT>" \
  -H "Content-Type: application/json" \
  -d '{"question":"Come funziona il golden point?","mode":"RULES","surface":"mobile"}'
```

Poi dall'app:

1. Avvia con `SUPABASE_URL` e `SUPABASE_ANON_KEY`.
2. Accedi con un account Pro/super admin.
3. Apri Profilo → Pallino Assistant.
4. Fai una domanda. Eventuali problemi del provider vengono mostrati
   all’utente come indisponibilità temporanea; la diagnostica tecnica è
   disponibile solo nelle build Debug.
5. Premi "Segnala risposta" su una risposta AI e verifica che compaia una
   riga in `public.assistant_reports`.

### URL pubblici Privacy e Terms

Prima della submission pubblica due pagine HTTPS stabili:

- Privacy Policy: contenuto da `docs/legal/PRIVACY_POLICY.md` o versione HTML
  equivalente.
- Terms of Service: contenuto da `docs/legal/TERMS_OF_SERVICE.md` o versione
  HTML equivalente.

Puoi ospitarle su sito ufficiale, Netlify, GitHub Pages o altra pagina HTTPS
pubblica indicizzabile dai reviewer. Non usare localhost, URL temporanei,
documenti privati Google Drive o link con login. Dopo il deploy passa gli URL
alla build Flutter con i nomi esatti usati dall'app:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://<PROJECT_REF>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<SUPABASE_ANON_OR_PUBLISHABLE_KEY> \
  --dart-define=RALLYMATE_PRIVACY_URL=https://<dominio>/privacy \
  --dart-define=RALLYMATE_TERMS_URL=https://<dominio>/terms
```

Nota: i nomi corretti sono `RALLYMATE_PRIVACY_URL` e
`RALLYMATE_TERMS_URL`, con underscore. Verifica nell'app aprendo paywall e
Privacy: i pulsanti devono aprire gli URL pubblici, non mostrare il messaggio
"Configura ... prima della pubblicazione".

Avvia l'app con la configurazione client centralizzata (nessuna modifica al
codice e nessun secret server-side nel file):

```bash
cd apps/rallymate
mkdir -p "$HOME/.config/rallymate"
cp config/client.env.example "$HOME/.config/rallymate/client.env"
chmod 600 "$HOME/.config/rallymate/client.env"
# Compila i valori pubblici nel file, poi:
tool/rallymate doctor
tool/rallymate run -d <DEVICE_ID>
```

Per Android Studio aggiungi
`--dart-define-from-file=$HOME/.config/rallymate/client.env` agli argomenti
Flutter. Per Xcode esegui prima `tool/rallymate configure-ios --debug` e apri
`ios/Runner.xcworkspace`. Per Release/TestFlight/Play usa sempre i comandi
`tool/rallymate build-ipa --release` e
`tool/rallymate build-appbundle --release`.

In Supabase Dashboard → Authentication → URL Configuration aggiungi tra i
Redirect URLs consentiti `rallymate://auth-callback`. Non sostituirlo con
localhost: serve per conferma email e recupero password su iOS e Android.

Su Apple Developer/Xcode conserva il capability Keychain Sharing del target
Runner: la sessione Supabase viene salvata nel Keychain e
`ios/Runner/Runner.entitlements` contiene `keychain-access-groups`. Le build
simulatore `--no-codesign` verificano solo la compilazione; per verificare
realmente autenticazione e Keychain usa `tool/rallymate run -d <SIMULATOR_ID>`.

## 2. RevenueCat (abbonamenti Plus/Pro/Coach)

1. Crea l'app su https://app.revenuecat.com (progetti iOS + Android).
2. **Entitlements** con questi id esatti: `plus`, `pro`, `coach`.
3. Prodotti store: `rallymate_plus_monthly`, `rallymate_pro_monthly`,
   `rallymate_coach_monthly` (App Store Connect + Play Console) e offering
   default con i 3 package mensili.
4. Webhook: URL
   `https://<PROJECT_REF>.supabase.co/functions/v1/revenuecat-webhook`,
   authorization header `Bearer <REVENUECAT_WEBHOOK_SECRET>`.
5. Avvia con le chiavi:

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=REVENUECAT_ANDROID_KEY=goog_... \
  --dart-define=REVENUECAT_IOS_KEY=appl_...
```

Senza chiavi RevenueCat il paywall attiva i piani in locale **solo in
build di debug**. In release senza store gli acquisti sono bloccati
(paywall sicuro).

## Bypass premium per il testing

```bash
flutter run --dart-define=RALLYMATE_TEST_PREMIUM=true
```

Sblocca TUTTI i piani lato client (analytics premium, wrapped, training,
area coach) senza pagare. Le feature server-side (backup, chatbot Pro,
creazione pacchetti) restano protette da RLS sul piano reale: per testarle
end-to-end imposta il piano sul DB:

```sql
update profiles set plan = 'pro' where user_id = '<uid>';
```

### Account super admin personale

Metodo consigliato:

1. Crea il tuo account dall'app: Profilo → Crea account.
2. Applica le migration incluso `0005_deepseek_admin_assistant.sql`.
3. In Supabase SQL editor:

```sql
select public.grant_super_admin_by_email('tua-email@example.com');
```

4. Esci e rientra nell'app: il sync base leggerà `account_role='super_admin'`
   e abiliterà localmente tutte le superfici Premium/Coach per il tuo test.

Metodo alternativo senza SQL manuale:

```bash
supabase secrets set RALLYMATE_SUPER_ADMIN_EMAILS=tua-email@example.com
supabase functions deploy assistant
```

Alla prima chiamata autenticata alla function, quell'email viene marcata come
`super_admin`. Questo bypass vale solo lato server per l'assistente; per vedere
subito tutte le schermate premium in UI resta preferibile il grant SQL.

## 3. Coach checkout — prima del lancio

`backend/supabase/functions/coach-checkout/index.ts` ora fallisce chiuso:
senza verifica ricevuta server-side ritorna `receipt_invalid`.

Per test locali puoi impostare temporaneamente:

```bash
supabase secrets set ALLOW_UNVERIFIED_COACH_RECEIPTS=true
```

Non usare quel secret in produzione. Prima del lancio collega App Store
Server API, Google Play Developer API o RevenueCat con lo stesso `storeTxId`.

## 4. Watch

- **Wear OS**: `wear/wearos` — applicationId `com.rallymate.rallymate`
  (NON cambiarlo: deve combaciare col telefono) e stessa firma.
  `./gradlew :app:assembleDebug` → installa su watch.
- **Apple Watch companion**: dalla root esegui
  `ruby scripts/sync_watchos_target.rb`, poi apri
  `apps/rallymate/ios/Runner.xcworkspace`. Il target `RallyMateWatchApp` è
  incorporato automaticamente in `Runner.app/Watch`, usa il bundle derivato
  `com.rallymate.rallymate.watchkitapp` e lo stesso team di firma di Runner.
  Seleziona `RallyMateWatchApp` per il debug diretto sul Watch o `Runner` per
  installare telefono e companion insieme. `wear/watchos/project.yml` resta
  una spec XcodeGen opzionale per build isolate, non il percorso di release.
- **Garmin Connect IQ**: `wear/garmin-connectiq`. Configura SDK 9.2.0 e
  developer key fuori dal repo, poi esegui `scripts/build.sh venu3` e
  `scripts/test.sh venu3`. `scripts/validate_matrix.sh` compila i 95 profili e
  `scripts/export.sh` crea il pacchetto firmato `build/Momentum.iq`. I bridge
  mobile usano gli SDK ufficiali Garmin.
- **Fitbit OS**: `wear/fitbit-os`. `npm ci && npm test && npm run build &&
  npm run build:legacy` genera i binari OS 5 e OS 4. Per release passa
  `RALLYMATE_WEARABLE_GATEWAY_URL` a `npm run build:release` e marca la Gallery
  listing come Paid.
- **Fitbit Air / Google Health**: non ha UI di scoring. Il collegamento Pro usa
  OAuth server-side e i due endpoint Google Health descritti in
  `wear/fitbit-google-health/README.md`.
- **Galaxy Watch Tizen**: nessun nuovo binario e nessun pairing simulato;
  Samsung ha chiuso nuove pubblicazioni/aggiornamenti. L'app guida verso
  Galaxy Watch4+ con Wear OS.

## 5. Store listing (quando pronti)

- Deep link `rallymate://` già registrato (Android + iOS).
- Android release: conserva la upload key fuori dal repository e configura
  tutte le variabili seguenti. Una configurazione parziale ora interrompe la
  build; la firma debug in release resta consentita solo per smoke test locali.

```bash
export RALLYMATE_ANDROID_KEYSTORE_PATH="$HOME/.config/rallymate/android/upload-keystore.jks"
export RALLYMATE_ANDROID_KEYSTORE_PASSWORD='<password-keystore>'
export RALLYMATE_ANDROID_KEY_ALIAS='upload'
export RALLYMATE_ANDROID_KEY_PASSWORD='<password-chiave>'
flutter build appbundle --release
```

- URL store recap: impostare i secrets `RALLYMATE_APP_STORE_URL` e
  `RALLYMATE_PLAY_STORE_URL` solo con listing reali. Non sono più hardcoded.
- Privacy: i dati partita restano sul device (free); dichiara backup/LLM
  solo per i piani a pagamento.

## Cosa resta fuori (per scelta, roadmap PRD)

Fase 1.5/2: mini-LLM locale, tornei e club dashboard. HealthKit, Health
Connect, Wear OS Health Services, Garmin Connect IQ, Fitbit OS e Google Health
sono implementati nel repository; prima di dichiararli pubblicamente restano
obbligatori account provider, credenziali, approvazioni e test sui device fisici
elencati nei README dei moduli.
