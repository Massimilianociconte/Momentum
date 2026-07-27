# Data Safety mapping — Momentum

Mapping per il form Play Console → App content → Data safety. Basato sull'audit del codice (2026-07-26): client Flutter, edge functions Supabase, RevenueCat, FCM.

## Risposte generali

| Domanda | Risposta | Motivazione |
|---|---|---|
| L'app raccoglie o condivide dati utente? | Sì (raccoglie) | Account cloud opzionale, social, push |
| Tutti i dati in transito sono cifrati? | Sì | Solo HTTPS; cleartext limitato a localhost (`network_security_config.xml`) |
| Fornisci un modo per richiedere la cancellazione? | Sì | In-app + URL `delete-account` (vedi `account-deletion-flow.md`) |
| Dati raccolti da app inviate a terze parti? | Sì, limitatamente | RevenueCat (acquisti), Firebase Cloud Messaging (token push), provider AI per il testo delle domande all'assistente |

Nota: l'uso è **facoltativo senza account** — lo scoring locale non raccoglie nulla. Le voci sotto valgono solo quando l'utente attiva le funzioni cloud.

## Tipi di dati

| Categoria Play | Dato | Raccolto | Condiviso | Facoltativo | Scopo | Evidenza |
|---|---|---|---|---|---|---|
| Info personali → Indirizzo email | Email account | Sì | No | Sì (solo con account) | Funzionalità app, gestione account | Supabase Auth |
| Info personali → Nome | Nickname/nome profilo | Sì | No | Sì | Funzionalità app, social | tabella profili |
| Foto e video → Foto | Avatar profilo/team | Sì | No | Sì | Funzionalità app (social) | storage `profile_avatar` con RLS |
| Salute e fitness → Info salute | Aggregati Health Connect (passi, calorie attive, FC, sessioni, HRV, sonno) | No* | No | Sì | Solo elaborazione on-device | *Restano sul dispositivo; inclusi nel backup cifrato premium solo se l'utente lo attiva → in tal caso dichiarare "Raccolto: Sì, cifrato, cancellabile" |
| Salute e fitness → Fitness | Dati workout dal watch (FC durante match) | Sì (se sync attiva) | No | Sì | Funzionalità app (statistiche match) | wearable-gateway/Data Layer |
| Attività app → Interazioni | Match, punteggi, statistiche | Sì (se account) | No | Sì | Funzionalità app, backup | tabelle match con RLS |
| Attività app → Altri contenuti generati | Messaggi assistente AI, contenuti social (team, gruppi) | Sì | Sì (solo testo domande → provider AI) | Sì | Funzionalità app | edge function `assistant` (contesto minimizzato, mai dati salute) |
| Info app e prestazioni → Crash log | Nessun SDK crash di terze parti | No | No | — | — | Nessun Crashlytics/Sentry nel client |
| ID dispositivo o altri ID | Token push FCM, ID installazione | Sì | Sì (FCM) | Sì (opt-in notifiche) | Funzionalità app (push) | `push_devices` con retention e minimizzazione |
| Info finanziarie → Cronologia acquisti | Stato abbonamento/entitlement | Sì | Sì (RevenueCat) | Sì | Funzionalità app (premium) | webhook `revenuecat-webhook` |

## Punti d'attenzione per la compilazione

1. **Health Connect**: nel form Data Safety i dati letti da Health Connect e mai trasmessi fuori dal dispositivo NON vanno dichiarati come "raccolti". Se si lascia attivabile il backup premium v2 (che può includere derivati salute cifrati), dichiarare "Salute e fitness — raccolto, cifrato in transito, cancellabile, non condiviso". Scegliere la posizione più conservativa: **dichiararlo**.
2. **Condivisione con provider AI**: solo il testo delle domande dell'utente; dichiarare sotto "Altri contenuti generati dagli utenti → condiviso per funzionalità dell'app". Il contesto non include mai dati salute (verificato nella edge function).
3. **Nessuna raccolta per pubblicità o analytics di terze parti**: non esistono SDK ads/analytics nel client.
4. **Cancellazione**: tutti i dati dichiarati sono cancellati con l'account (edge function `delete-account` + retention job).
5. Ripetere le stesse dichiarazioni per l'artefatto **Wear OS** (stessa scheda, stessi dati: il watch invia FC/eventi workout al telefono/gateway).
