# Piano di test release — Momentum

Copre: test automatici (già in CI), test manuali pre-submission e closed testing (12 tester / 14 giorni).

## 1. Test automatici (stato: verdi al 2026-07-26)

| Suite | Comando | Esito audit |
|---|---|---|
| Core Dart | `dart test` in `packages/momentum_core` | ✅ in CI |
| Flutter app | `flutter analyze` + `flutter test` in `apps/momentum` | ✅ "No issues found!", 139 test passati |
| Build release mobile (R8) | `flutter build appbundle --release` (placeholders) | ✅ AAB 89.7 MB |
| Wear OS | `./gradlew testDebugUnitTest assembleRelease` | ✅ BUILD SUCCESSFUL |
| Supabase | pgTAP + advisors in CI | ✅ in CI |
| 16 KB | zipalign `-c -P 16` + ELF align | ✅ entrambi gli APK |

## 2. Test manuali pre-submission (su build release firmata, device fisici)

Device minimi: 1 telefono Android 14/15/16, 1 telefono Android 8-10 (minSdk 26 path), 1 watch Wear OS 4+.

### Funzionali core
- [ ] Onboarding completo e skip; scoring offline senza account (golden point, tie-break, super tie-break, undo).
- [ ] Registrazione, login, logout, reset password; deep link `rallymate://auth-callback`.
- [ ] Cancellazione account (vedi `account-deletion-flow.md` §6).

### Health Connect
- [ ] Richiesta permessi → concessione parziale → totale → revoca da HC (l'app degrada senza crash).
- [ ] Rationale: da HC → Momentum → informativa privacy si apre `/privacy` (app chiusa E aperta).
- [ ] Device senza Health Connect: sezioni insight nascoste.

### Wear OS
- [ ] Installazione da Play sul watch (dopo upload nel track), avvio standalone senza telefono.
- [ ] Match completo dal watch: FGS health attivo, FC visibile, notifica ongoing corretta.
- [ ] Sync watch↔telefono con entrambe le app; pausa/ripresa cross-device.

### Billing (license tester)
- [ ] Acquisto Plus/Pro/Coach, sblocco entitlement in app e lato server.
- [ ] Annullamento e scadenza (test clock), restore su secondo device, downgrade/upgrade.
- [ ] Verifica che in release `RALLYMATE_TEST_PREMIUM` non abbia effetto.

### Notifiche e varie
- [ ] Opt-in notifiche: nessun token FCM prima del consenso; push ricevuta dopo.
- [ ] Assistente AI: risposta, quota esaurita gestita con messaggio chiaro.
- [ ] Rotazione, dark mode, font scale 200%, TalkBack sui flussi principali.
- [ ] Kill dell'app durante un match → riapertura ripristina lo stato.

## 3. Closed testing (obbligo Play per account personali post-nov 2023)

1. Track **Closed testing → Alpha**: caricare AAB telefono + AAB Wear.
2. Lista email con **≥ 12 tester** (consiglio 15-20 per margine); i tester devono accettare l'invito e installare l'app.
3. Mantenere i tester **iscritti per 14 giorni consecutivi**; pubblicare almeno un aggiornamento se emergono fix.
4. Raccogliere feedback strutturato (form: device, versione OS, bug, crash).
5. Dopo ogni upload: risolvere i finding del **pre-launch report** (crash, security, accessibilità).
6. Al giorno 14+: richiedere accesso produzione rispondendo al questionario (descrivere test svolti, tester, fix).

## 4. Criteri di uscita (go/no-go per produzione)

- 0 crash riproducibili nei flussi core; crash rate track < 1%.
- Pre-launch report senza errori bloccanti.
- Tutti i box §2 spuntati su build firmata release.
- Checklist manuale Console completata (`google-play-manual-checklist.md`).
