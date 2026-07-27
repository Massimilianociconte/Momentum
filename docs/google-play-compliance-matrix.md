# Google Play Compliance Matrix — Momentum (RallyMate)

Data audit: 2026-07-26 · App: `com.rallymate.rallymate` · Mobile 0.1.0+1 (targetSdk 36) · Wear OS 0.1.0 (1001, targetSdk 35)

Stati ammessi: CONFORME · CORRETTO DURANTE L'AUDIT · NON CONFORME · DA VERIFICARE MANUALMENTE · NON APPLICABILE · BLOCCANTE

| # | Requisito | Stato | Evidenza / File | Note |
|---|-----------|-------|------------------|------|
| 1 | Target API level mobile ≥ 36 | CONFORME | Merged manifest release: `uses-sdk targetSdkVersion=36` (`apps/momentum/build/app/intermediates/merged_manifests/release/.../AndroidManifest.xml`) | FlutterExtension default 36; minSdk 26 esplicito |
| 2 | Target API level Wear OS ≥ 35 | CONFORME | `wear/wearos/app/build.gradle.kts` (`targetSdk = 35`), merged manifest release | minSdk 30 (Wear OS 3+) |
| 3 | Supporto 16 KB page size | CONFORME | zipalign `-P 16` OK su entrambi gli APK release; ELF LOAD align ≥ 16384 su tutte le .so a 64 bit (libapp/libflutter 65536, altre 16384); `extractNativeLibs=false` | Verificato con zipalign 37.0.0 + parsing ELF |
| 4 | Formato AAB | CONFORME | `flutter build appbundle` produce `app-release.aab`; verificato in audit | Wear si pubblica come AAB/APK legato alla stessa release |
| 5 | Firma release mobile | CONFORME | `apps/momentum/android/app/build.gradle.kts`: signing da env var all-or-nothing, fail se parziale | Nessun keystore nel repo. Play App Signing: DA VERIFICARE MANUALMENTE in Console |
| 6 | Firma release Wear (stesso certificato) | CORRETTO DURANTE L'AUDIT | `wear/wearos/app/build.gradle.kts`: aggiunta signingConfig release con le stesse env var del telefono | Prima assente: release non firmabile |
| 7 | Offuscamento/shrinking release mobile | CORRETTO DURANTE L'AUDIT | `isMinifyEnabled/isShrinkResources = true` + `proguard-rules.pro` creato (keep Garmin CIQ) | Prima il release era non minificato |
| 8 | Versioning coerente phone/wear | CORRETTO DURANTE L'AUDIT | Wear versionCode 1→1001 (range 1xxx), versionName allineato 0.1.0 | Phone da pubspec (0.1.0+1) |
| 9 | Manifest: permessi minimi e motivati | CONFORME | Merged manifest release: nessun permesso location moderno (FINE_LOCATION solo maxSdk 30 per BLE legacy), BLUETOOTH_SCAN `neverForLocation` | Tabella completa in `data-safety-mapping.md` |
| 10 | Componenti exported giustificati | CONFORME | MainActivity (launcher), ViewPermissionUsageActivity (protetta da `START_VIEW_PERMISSION_USAGE`), WatchListenerService/PhoneListenerService (Data Layer, filtro `wear:` GMS), receiver protetti da permessi firma/DUMP | Audit merged manifest release phone+wear |
| 11 | Nessun foreground service telefono | CONFORME | Nessun FGS proprio dichiarato; `FOREGROUND_SERVICE` mergiata da WorkManager (SystemForegroundService, non usato con tipo) | Nessuna dichiarazione FGS type richiesta in Console per il telefono |
| 12 | FGS Wear con tipo dichiarato | CONFORME | `MatchWorkoutService` `foregroundServiceType="health"` + `FOREGROUND_SERVICE_HEALTH` | Uso: sessione workout attiva, conforme alle policy FGS health |
| 13 | Health Connect: permessi minimi READ | CONFORME | 6 permessi READ (steps, active calories, HR, exercise, HRV, sleep); solo aggregati, range max 7 giorni (`HealthConnectBridge.kt`) | Nessuna scrittura |
| 14 | Health Connect: rationale/privacy intent | CORRETTO DURANTE L'AUDIT | Handler `ACTION_SHOW_PERMISSIONS_RATIONALE` + `VIEW_PERMISSION_USAGE` implementato in `MainActivity.kt` → schermata Privacy e dati (`/privacy`) | Prima l'intent-filter era dichiarato senza handler |
| 15 | Dichiarazione Health apps (Console) | DA VERIFICARE MANUALMENTE | Bozza in `health-app-declaration.md` | Va compilata nel form "Health apps" di Play Console |
| 16 | Privacy policy URL | DA VERIFICARE MANUALMENTE | Testi completi serviti da `https://playmomentum.it/privacy/` e `/privacy-en/` (pagine Astro che renderizzano `docs/legal/`); manca solo titolare + deploy | URL iniettato via `RALLYMATE_PRIVACY_URL` |
| 17 | Cancellazione account (in-app + URL web) | CONFORME | In-app: `auth_screen.dart` (doppia conferma + "ELIMINA"); web: edge function `delete-account` GET (pagina) / POST (cancellazione); `CloudConfig.deleteAccountUrl` | Flusso completo in `account-deletion-flow.md` |
| 18 | Data Safety form | DA VERIFICARE MANUALMENTE | Mapping completo in `data-safety-mapping.md` | Compilare in Console con quel mapping |
| 19 | Play Billing per beni digitali | CONFORME | RevenueCat (`purchases_flutter` 9.x, Billing client 8.0.0 nel merged manifest); prodotti `rallymate_{plus,pro,coach}_monthly` | Nessun sistema di pagamento alternativo per beni digitali |
| 20 | Verifica entitlement server-side | CONFORME | Webhook RevenueCat (Bearer + HMAC opz.) → `apply_revenuecat_plan_event`; gate server `has_active_entitlement` con scadenza | Coach checkout: `verifyReceipt()` fail-closed, feature disattiva (known risk, non bloccante) |
| 21 | Bypass di test escluso dal release | CORRETTO DURANTE L'AUDIT | `cloud_config.dart`: `testPremium` ora AND `!dart.vm.product` | Prima bastava il dart-define anche in release |
| 22 | Cleartext traffic vietato | CONFORME | `network_security_config.xml`: cleartext solo localhost/127.0.0.1/10.0.2.2 (loopback model_viewer) | |
| 23 | Backup/trasferimento dati esclusi | CONFORME | `allowBackup=false` + `backup_rules.xml`/`data_extraction_rules.xml` escludono tutto | Sessione in flutter_secure_storage con marker anti-reinstallo |
| 24 | Nessun segreto nel repo/client | CONFORME | Chiavi via `--dart-define`; `validateCloudClientConfig` rifiuta `sb_secret_`/service_role; secret scan in CI | |
| 25 | RLS su dati cloud | CONFORME | RLS su 20+ tabelle; pgTAP + `supabase db advisors` in CI | 9 edge function `verify_jwt=false` fanno auth manuale (audit ok) |
| 26 | Deep link sicuri | CONFORME | Schema custom `rallymate://` con validazione input in `app.dart`; `flutter_deeplinking_enabled=false` (gestione app_links) | Nessun App Link https da verificare |
| 27 | Wear OS standalone | CONFORME | `com.google.android.wearable.standalone=true`; scoring funziona offline | |
| 28 | Wear OS: stesso applicationId | CONFORME | `com.rallymate.rallymate` su entrambi | Richiesto per Data Layer |
| 29 | UGC (social, foto team) con moderazione | DA VERIFICARE MANUALMENTE | Segnalazione/blocco presenti lato social; verificare completezza policy UGC in Console | Foto profilo/team: upload consapevole, storage RLS |
| 30 | AI assistant: quota e sicurezza | CONFORME | Edge function `assistant` con quota atomica, cache hits free, contesto minimizzato (no dati salute), opt-out contesto in Privacy | Dichiarare in App Content se richiesto |
| 31 | Notifiche opt-in | CONFORME | `POST_NOTIFICATIONS` runtime; FCM auto-init disattivato fino al consenso (`firebase_messaging_auto_init_enabled=false`) | |
| 32 | IARC questionnaire | DA VERIFICARE MANUALMENTE | Indicazioni in `google-play-manual-checklist.md` | Sport, no contenuti sensibili → attesa PEGI 3 |
| 33 | Closed test 12 tester / 14 giorni | DA VERIFICARE MANUALMENTE | Piano in `release-test-plan.md` | Requisito per account personali creati dopo nov 2023 |
| 34 | Pre-launch report | DA VERIFICARE MANUALMENTE | Da eseguire dopo il primo upload in Console | |
| 35 | Store listing IT/EN | DA VERIFICARE MANUALMENTE | Bozze `play-store-listing-it.md` / `play-store-listing-en.md`; asset in `play-store-assets-checklist.md` | Screenshot da produrre |
| 36 | CI: build release verificate | CORRETTO DURANTE L'AUDIT | `rallymate-ci.yml`: aggiunti step AAB release (R8) mobile e `assembleRelease` Wear | |

## Sintesi

- BLOCCANTI: nessuno a livello di codice/configurazione.
- CORRETTI DURANTE L'AUDIT: 6 (minify mobile, firma Wear, versioning Wear, rationale Health Connect, neutralizzazione bypass test in release, CI release check).
- DA VERIFICARE MANUALMENTE: 8 azioni Play Console (vedi `google-play-manual-checklist.md`).
