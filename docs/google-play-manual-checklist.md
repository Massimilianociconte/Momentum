# Checklist manuale Play Console — Momentum

Azioni che solo il proprietario dell'account sviluppatore può completare. Spuntare in ordine.

## 1. Account e app
- [ ] Account Play Console attivo con identità verificata (D-U-N-S se organizzazione).
- [ ] Creare l'app: nome "Momentum", lingua predefinita italiano, tipo App, gratuita con acquisti in-app.
- [ ] Package: `com.rallymate.rallymate` (fissato al primo upload, non modificabile).
- [ ] Attivare **Play App Signing** al primo upload (consigliato: chiave di firma gestita da Google; il keystore locale diventa upload key).

## 2. Firma e primo upload
- [ ] Generare keystore upload con `scripts/generate_upload_keystore.sh` (lo crea fuori dal repo) e valorizzare le 4 env var `RALLYMATE_ANDROID_KEYSTORE_PATH/PASSWORD`, `RALLYMATE_ANDROID_KEY_ALIAS/PASSWORD`.
- [ ] Build store: `tool/rallymate build-appbundle --release` con `RALLYMATE_CLIENT_ENV` di produzione (URL Supabase reali, chiave `sb_publishable_`, `REVENUECAT_ANDROID_KEY=goog_...`, `RALLYMATE_PRIVACY_URL`, `RALLYMATE_TERMS_URL`).
- [ ] Wear: `./gradlew bundleRelease` in `wear/wearos` con le stesse env var (stesso certificato del telefono, obbligatorio per il Data Layer).
- [ ] Nella release, caricare AAB telefono + AAB Wear (form factor Wear OS).

## 3. Dichiarazioni App content (Policy → App content)
- [ ] **Privacy policy URL**: `https://playmomentum.it/privacy/` (pagina già implementata nel sito, renderizza `docs/legal/PRIVACY_POLICY.md`; EN: `https://playmomentum.it/privacy-en/`). Prima della submission: compilare il titolare nei markdown e deployare il sito. Lo stesso URL va passato come `RALLYMATE_PRIVACY_URL` alla build.
- [ ] **Data Safety**: compilare con `data-safety-mapping.md`.
- [ ] **Health apps**: dichiarare uso Health Connect come da `health-connect-permissions.md` + `health-app-declaration.md`.
- [ ] **Account deletion**: URL = `https://playmomentum.it/elimina-account/` (pagina istruzioni già nel sito); in alternativa `<SUPABASE_URL>/functions/v1/delete-account`. Dichiarare anche la cancellazione in-app.
- [ ] **Ads**: dichiarare "nessuna pubblicità".
- [ ] **Target audience**: 13+ (l'app richiede account facoltativo, nessun contenuto per bambini). Non selezionare target < 13.
- [ ] **News app**: No. **COVID-19**: No. **Government app**: No.
- [ ] **Login credentials per la review**: fornire l'account di test (vedi `google-play-reviewer-instructions.md`).
- [ ] **IARC**: compilare il questionario (sport/utility, nessuna violenza, nessun contenuto sessuale, acquisti digitali sì, interazione utenti sì per il social). Esito atteso: PEGI 3 / Everyone con avviso "interazione utenti / acquisti".
- [ ] **UGC**: dichiarare presenza di contenuti generati dagli utenti (foto profilo/team, nomi) con strumenti di segnalazione e blocco.

## 4. Prodotti in-app
- [ ] Creare 3 abbonamenti in Monetizzazione → Abbonamenti: `rallymate_plus_monthly`, `rallymate_pro_monthly`, `rallymate_coach_monthly` (base plan mensile ciascuno, come in `billing-products-matrix.md`).
- [ ] Collegare l'app a RevenueCat (service credentials + notifiche RTDN pub/sub) e verificare gli entitlement `plus`, `pro`, `coach`.
- [ ] Configurare il webhook RevenueCat → `<SUPABASE_URL>/functions/v1/revenuecat-webhook` con Bearer secret (`REVENUECAT_WEBHOOK_SECRET`) e HMAC opzionale.

## 5. Store listing
- [ ] Testi IT/EN da `play-store-listing-it.md` / `play-store-listing-en.md`.
- [ ] Asset grafici come da `play-store-assets-checklist.md` (icona 512, feature graphic 1024×500, ≥4 screenshot telefono, ≥1 screenshot Wear rotondo).

## 6. Test track (obbligatorio per account personali post-nov 2023)
- [ ] Closed testing: creare track, invitare ≥ 12 tester, mantenerli iscritti 14 giorni consecutivi (piano in `release-test-plan.md`).
- [ ] Risolvere i finding del **pre-launch report** dopo ogni upload.
- [ ] Richiedere l'accesso alla produzione al termine dei 14 giorni.

## 7. Post-submission
- [ ] Monitorare Android Vitals (crash rate < 1.09%, ANR < 0.47%).
- [ ] Configurare rollout graduale (10% → 50% → 100%) come da `release-and-rollback.md`.

## 8. Fuori Play Console
- [ ] Deployare `apps/momentum-web` (le pagine `/privacy/`, `/privacy-en/`, `/termini/`, `/elimina-account/` sono pronte); impostare `PUBLIC_SUPPORT_EMAIL` nell'ambiente di build del sito e compilare il titolare in `docs/legal/*.md` per togliere l'avviso bozza.
- [ ] Verificare che il progetto Supabase di produzione abbia: secrets edge functions impostati, redirect URL `rallymate://auth-callback` in Auth, retention job attivi.
- [ ] Google Cloud/Firebase: `google-services.json` di produzione in `apps/momentum/android/app/` al momento della build (non committato).
