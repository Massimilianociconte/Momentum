# Rischi noti e limitazioni — Momentum (audit 2026-07-26)

Rischi residui accettati o da monitorare. Nessuno è bloccante per la submission; rivalutare a ogni release.

## 1. Tecnici

| # | Rischio | Impatto | Mitigazione attuale | Azione futura |
|---|---|---|---|---|
| T1 | `coach-checkout` (Stripe): `verifyReceipt()` hardcoded `false` — la feature coach checkout è disattivata fail-closed | Nessuno per gli utenti (feature invisibile); debito tecnico | Fail-closed: nessun pagamento può completarsi | Implementare verifica reale prima di attivare la feature; non menzionarla nel listing |
| T2 | Primo release con R8 attivo (minify introdotto durante l'audit) | Possibili crash da classi rimosse in percorsi non coperti dai test | Keep rules Garmin CIQ; AAB release compila; CI verifica R8 a ogni PR | Smoke test completo su build release firmata (piano §2 di `release-test-plan.md`); caricare mapping.txt in Console |
| T3 | Nessun SDK di crash reporting nel client | Diagnosi crash solo via Android Vitals (aggregata, ritardata) | Vitals + pre-launch report | Valutare Sentry/Crashlytics in release successiva (aggiornando Data Safety) |
| T4 | Wear OS testato solo su emulatore in CI | Comportamenti device-specific (FGS health, sensori) non coperti | Unit test + assembleRelease in CI | Test su watch fisico nel closed testing |
| T5 | Peso AAB elevato (~90 MB con placeholder) | Download lento, possibile attrito installazione | R8 + resource shrinking attivi; asset 3D/immagini principali cause | Audit asset (model_viewer, immagini) se il peso store supera ~150 MB |

## 2. Policy / review

| # | Rischio | Probabilità | Mitigazione |
|---|---|---|---|
| P1 | Review Health Connect più severa (richiesta demo/video o rifiuto primo giro) | Media | `health-app-declaration.md` pronto; rationale implementato; video del flusso preparabile in anticipo |
| P2 | Data Safety incoerente con il comportamento rilevato dai crawler Google | Bassa | Mapping conservativo (`data-safety-mapping.md`): il backup salute è dichiarato come raccolto |
| P3 | UGC: moderazione ritenuta insufficiente (foto team/avatar) | Bassa-media | Segnalazione e blocco presenti; policy UGC nei ToS da verificare (vedi `terms-of-service-draft.md`) |
| P4 | Contenuti AI: risposte errate su regole/tecnica percepite come claim | Bassa | Disclaimer assistente; nessun tema salute/medico nelle risposte |
| P5 | Requisito 12 tester/14 giorni allunga il time-to-market | Certa (se account personale) | Pianificato in `release-test-plan.md`; avviare il closed test il prima possibile |

## 3. Operativi

| # | Rischio | Mitigazione |
|---|---|---|
| O1 | Perdita del keystore upload | Play App Signing attivo → si può richiedere reset upload key a Google; conservare il keystore in password manager/vault con backup |
| O2 | Secrets edge functions non configurati in produzione al primo deploy | Checklist §8 di `google-play-manual-checklist.md`; le funzioni falliscono chiuse |
| O3 | URL privacy/termini non ancora pubblicati | Bloccante per la submission: gap tracciato in `privacy-policy-draft.md` / `terms-of-service-draft.md` |
| O4 | Account Google Cloud/Firebase: `google-services.json` produzione non committato (corretto) ma necessario alla build | Documentato nella checklist manuale; conservare fuori repo |
| O5 | Dipendenza da RevenueCat (SPOF per entitlement) | Webhook + stato server con scadenza: in caso di outage RevenueCat gli entitlement attivi restano validi fino a scadenza |

## 4. Fuori scope dichiarati

- iOS/watchOS, Garmin, Fitbit: non toccati da questo audit (nessuna regressione introdotta: modifiche limitate ad Android/Flutter guardate da piattaforma).
- Compliance App Store Apple: coperta separatamente (`docs/legal/STORE_COMPLIANCE.md`).
