# Momentum - autenticazione e cloud remediation

Data verifica: 13 luglio 2026

## Causa esatta

La build mobile installata era stata prodotta senza i compile-time define
`SUPABASE_URL` e `SUPABASE_ANON_KEY`. Il progetto li leggeva solo tramite
`String.fromEnvironment`, quindi una build avviata direttamente da Flutter,
Xcode o Android Studio senza gli argomenti corretti risultava offline anche
quando progetto, Edge Functions e secret erano configurati sul backend.

Contemporaneamente, un vecchio profilo Drift locale faceva saltare
l'onboarding, ma non rappresentava una sessione Supabase. Le due condizioni
venivano presentate all'utente come uno stato quasi unico: profilo presente,
cloud non configurato e funzionalita cloud non autenticate.

Sono emersi anche questi problemi correlati:

- sessione Supabase precedentemente persistita in SharedPreferences;
- upload implicito del profilo locale dopo un login, senza conferma di
  proprieta e con rischio di attribuzione al nuovo account;
- assenza di uno stato persistente per conferma email e collegamento differito;
- recupero password privo della fase finale di impostazione nuova password;
- messaggi client che suggerivano di configurare DeepSeek all'utente finale;
- immagini, social e sync che in alcuni punti verificavano solo la sessione,
  non il collegamento esplicito del profilo locale.

## Stato implementato

L'app distingue ora:

1. profilo esclusivamente locale;
2. account registrato ma non autenticato;
3. conferma email in attesa;
4. sessione Supabase valida con collegamento profilo richiesto;
5. account diverso da quello precedentemente collegato;
6. profilo cloud incompleto;
7. profilo locale e account cloud collegati;
8. piano Free, Premium e ruolo test/super admin.

Un login non carica piu automaticamente i dati locali. L'utente deve scegliere
`Collega senza perdere dati`; fino a quel momento social, backup, immagini,
Duo Mode e Assistant non possono attribuire dati all'account autenticato.

Il piano Free sincronizza solo il profilo base consentito. Il backup completo
di partite, eventi, team, allenamenti, analytics e preferenze resta protetto
dall'entitlement Premium. Dati salute, token, credenziali e diagnostica del
dispositivo non vengono inclusi nel backup generico.

## Configurazione client sicura

Il file locale usato su questa macchina e:

```text
~/.config/rallymate/client.env
```

Ha permessi `0600` ed e esterno al repository. Deve contenere soltanto valori
client-safe:

```dotenv
SUPABASE_URL=https://<PROJECT_REF>.supabase.co
SUPABASE_ANON_KEY=<PUBLISHABLE_KEY_O_LEGACY_ANON_JWT>
RALLYMATE_PRIVACY_URL=https://<DOMINIO>/privacy
RALLYMATE_TERMS_URL=https://<DOMINIO>/terms
```

Non inserire mai `service_role`, `sb_secret_*`, `DEEPSEEK_API_KEY` o altri
secret server-side. Il wrapper rifiuta anche un vecchio JWT Supabase con ruolo
`service_role` prima della compilazione.

## Comandi build

```bash
cd apps/rallymate

tool/rallymate doctor
tool/rallymate run -d <DEVICE_ID>
tool/rallymate build-apk --debug
tool/rallymate build-appbundle --release

tool/rallymate configure-ios --debug
open ios/Runner.xcworkspace

tool/rallymate configure-ios --release
tool/rallymate build-ipa --release
```

Per staging usare un file separato:

```bash
RALLYMATE_CLIENT_ENV="$HOME/.config/rallymate/staging.env" \
  tool/rallymate run -d <DEVICE_ID>
```

Android Studio deve ricevere
`--dart-define-from-file=$HOME/.config/rallymate/client.env`. Prima di un run o
archive diretto da Xcode eseguire sempre `tool/rallymate configure-ios` con la
configurazione corretta.

## DeepSeek e Assistant

La chiave DeepSeek rimane esclusivamente nei Supabase Edge Function secrets.
Il flusso e:

```text
client autenticato -> assistant Edge Function -> JWT + entitlement
-> secret server-side -> DeepSeek -> risposta strutturata al client
```

La function `assistant` e attiva in versione 13 con verifica JWT. L'azione
diagnostica autenticata restituisce solo flag booleani, mai secret o token.
Il client distingue sessione scaduta, piano insufficiente e indisponibilita
temporanea, senza mostrare istruzioni tecniche su DeepSeek.

## Sessioni e sicurezza

- Android: sessione in storage cifrato con Android Keystore.
- iOS: sessione in Keychain con accessibilita `first unlock, this device`.
- Sessioni SharedPreferences precedenti: migrate una volta e poi eliminate.
- Token corrotti o non strutturalmente validi: invalidati.
- Reinstall iOS: un marker locale impedisce il ripristino silenzioso di una
  sessione Keychain appartenente a una precedente installazione.
- Logout/cambio account: pulizia delle cache cloud e degli entitlement runtime,
  senza cancellare lo storico locale.
- DeepSeek e service role: assenti dagli artefatti mobile.

Il target iOS include `keychain-access-groups`. In Apple Developer e nel
profilo di firma deve restare abilitato Keychain Sharing. Le build simulatore
`--no-codesign` verificano la compilazione, ma per testare il Keychain va usato
`tool/rallymate run` o una build firmata.

## Verifiche eseguite

- `flutter analyze`: 0 problemi.
- `flutter test`: 70/70 test superati.
- test configurazione mancante, URL/chiave malformati e key privilegiate;
- test sessione valida/corrotta e migrazione profilo locale;
- test conflitto account e collegamento esplicito;
- test messaggi Assistant privi di dettagli provider;
- test regressione Keychain entitlement iOS;
- secret scan repository e artefatti: pulita;
- wrapper: JWT `service_role` artificiale correttamente rifiutato;
- Assistant remoto: utente Free `403 plan_required`, utente Pro `200` con
  risposta e fonti; account temporanei rimossi;
- Edge health autenticato: provider e modello configurati;
- Android Debug APK configurato: build, installazione e avvio su Pixel 10 Pro;
- vecchio profilo locale preservato sul Pixel e form email/password disponibile;
- log Pixel: `Supabase init completed`, nessun crash auth;
- Android Release AAB: compilato;
- iOS Simulator: avvio configurato e `Supabase init completed` con Keychain;
- iOS Release device: compilato senza firma finale.

## File sorgente modificati

Configurazione e pipeline:

- `.github/workflows/rallymate-ci.yml`
- `scripts/ci_local.sh`
- `apps/rallymate/.gitignore`
- `apps/rallymate/config/client.env.example`
- `apps/rallymate/tool/rallymate`
- `apps/rallymate/README.md`
- `docs/SETUP.md`
- `apps/rallymate/pubspec.yaml`
- `apps/rallymate/pubspec.lock`

Cloud, autenticazione e runtime:

- `apps/rallymate/lib/services/cloud/cloud_config.dart`
- `apps/rallymate/lib/services/cloud/cloud_service.dart`
- `apps/rallymate/lib/services/cloud/secure_session_storage.dart`
- `apps/rallymate/lib/data/repositories/repositories.dart`
- `apps/rallymate/lib/app.dart`
- `apps/rallymate/lib/features/auth/auth_screen.dart`
- `apps/rallymate/lib/features/auth/cloud_diagnostics_screen.dart`
- `apps/rallymate/lib/features/rules/pro_chat_screen.dart`
- `apps/rallymate/lib/services/wearable_match_dispatcher.dart`
- `backend/supabase/functions/assistant/index.ts`

Ownership cloud e superfici collegate:

- `apps/rallymate/lib/features/profile/profile_screen.dart`
- `apps/rallymate/lib/features/profile/profile_edit_screen.dart`
- `apps/rallymate/lib/features/privacy/privacy_screen.dart`
- `apps/rallymate/lib/services/profile_image_service.dart`
- `apps/rallymate/lib/services/team_image_service.dart`
- `apps/rallymate/lib/features/social/social_screen.dart`
- `apps/rallymate/lib/features/social/friends_screen.dart`
- `apps/rallymate/lib/features/social/friend_groups_screen.dart`
- `apps/rallymate/lib/features/social/invite_redeem_screen.dart`
- `apps/rallymate/lib/features/match_setup/match_setup_screen.dart`
- `apps/rallymate/lib/features/teams/team_detail_screen.dart`
- `apps/rallymate/lib/features/training/athlete_coach_section.dart`

iOS e test:

- `apps/rallymate/ios/Runner/Runner.entitlements`
- `apps/rallymate/ios/Runner.xcodeproj/project.pbxproj`
- `apps/rallymate/test/cloud_auth_contract_test.dart`

I file Flutter/Xcode/Gradle generati sono stati aggiornati dalle build. Tre file
preesistenti (`coach_athletes_tab.dart`, `live_match_controller.dart` e
`pdf_report_service.dart`) hanno ricevuto soltanto formattazione automatica,
senza modifica funzionale intenzionale.

## Passaggi esterni ancora necessari

1. Supabase Dashboard -> Authentication -> URL Configuration: aggiungere
   esattamente `rallymate://auth-callback` ai Redirect URLs.
2. Verificare invio reale delle email di conferma e recupero password con il
   provider SMTP scelto e i template di produzione.
3. Apple Developer/Xcode: mantenere HealthKit e Keychain Sharing nel profilo di
   firma; creare un archive firmato per TestFlight.
4. Google Play: firmare l'AAB con la chiave upload di produzione.
5. Inserire URL HTTPS pubblici reali per Privacy e Termini e le chiavi client
   RevenueCat, se non ancora presenti nel file di release.
6. Incrementare `version`/build number rispetto a `0.1.0+1` prima della prima
   submission.
7. Eseguire su account proprietario reale: registrazione, click email,
   recupero password, logout/login, collegamento dati e verifica backup.

Il 13 luglio l'iPhone 15 e l'Apple Watch associato risultavano registrati in
CoreDevice ma `unavailable`; per questo la verifica runtime fisica iOS resta un
passaggio esterno, mentre compilazione Release e runtime simulatore sono verdi.
