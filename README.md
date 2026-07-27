# 🎾 Momentum

**Segna i punti dal polso. Chiedi regole alla mascotte. Analizza ogni
partita. Migliora come giocatore e come coppia.**

App padel mobile + smartwatch, **offline-first**, con scoring live da
Apple Watch / Galaxy Watch (Wear OS), analytics per ruolo e per coppia,
mascotte regolamento, card condivisibili stile Wrapped e monetizzazione
freemium + coach (vedi `PRD - RallyMate.pdf`; alcuni identificatori tecnici
mantengono ancora il nome storico RallyMate).

## Monorepo

```
packages/rally_core/     Motore Dart condiviso: scoring event-sourced,
                         analytics, regole FIP, wrapped. 42 test.
apps/rallymate/          App Flutter iOS+Android (Drift, Riverpod, go_router)
                         + bridge nativi watch (Kotlin/Swift). 4 test.
apps/padelandia-web/     Landing Astro mobile-first, supporto, SEO/GEO,
                         asset art-directed desktop/mobile.
wear/wearos/             App nativa Wear OS (Kotlin, Compose for Wear OS,
                         Data Layer). Port engine con 10 test JVM.
wear/watchos/            Companion nativa watchOS (SwiftUI, HealthKit,
                         WatchConnectivity). Port engine con 20 test host.
backend/supabase/        Schema + RLS + edge functions (recap pubblici,
                         assistant LLM Pro, coach checkout).
docs/                    Architettura, strategia costi.
```

## Principio cardine: un solo motore di punteggio

Il punteggio è **event-sourced**: la lista `MatchEvent` è l'unica fonte di
verità, lo stato è sempre ricostruito con il replay. L'undo funziona
sempre (anche oltre i confini di game/set) perché è un evento anch'esso.
Il motore è implementato tre volte con **semantica e wire format JSON
identici** (Dart / Kotlin / Swift) e ogni port ha la stessa suite di test:
Star Point FIP 2026, golden point, vantaggi, tie-break 7-6, super tie-break, rotazione
servizio, cambio campo, free play, undo, ricostruzione da JSON.

## Quick start

```bash
# 1. Core (test)
cd packages/rally_core && dart test

# 2. App mobile
cd apps/rallymate && flutter pub get && flutter run

# 3. Wear OS
cd wear/wearos && ./gradlew :app:assembleDebug :app:testDebugUnitTest

# 4. watchOS (engine test + target companion nel progetto iOS)
cd wear/watchos/RallyMateCore && swift test
cd ../../.. && ruby scripts/sync_watchos_target.rb
# poi apri apps/rallymate/ios/Runner.xcworkspace e seleziona Runner o RallyMateWatchApp

# 5. Backend
cd backend/supabase && supabase db push && supabase functions deploy

# 6. Landing Momentum
cd apps/padelandia-web && npm ci && npm test
```

## Sync watch ⇄ telefono

Contratto unico su tutte le piattaforme (eventi JSON idempotenti per
`eventId`, merge con `insertOrIgnore` → un re-sync completo non duplica):

| Percorso | Direzione | Payload |
|---|---|---|
| `/rallymate/start_match` | phone → watch | `{matchId, format, duoTeam?}` |
| `/rallymate/v2/start_match` | phone → watch v2 | Star Point, stesso payload con schema esplicito |
| `/rallymate/lifecycle` · `/rallymate/v2/lifecycle` | phone → watch | pausa/ripresa/fine + journal |
| `/rallymate/resumable` · `/rallymate/v2/resumable` | phone → watch | snapshot autorevoli separati per compatibilità |
| `/rallymate/events` | watch → phone | `{matchId, events[]}` |
| `/rallymate/request_state` | watch → phone | `{matchId}` |
| `/rallymate/state_response` | phone → watch | `{matchId, events[]}` |

`duoTeam` (`TEAM_A`/`TEAM_B`, opzionale) assegna il watch a un solo team in
Duo Mode: il watch mostra un solo pulsante "PUNTO NOSTRO" e l'undo è
team-scoped (annulla solo l'ultimo punto del proprio team).

Trasporti: WatchConnectivity (iOS, con coda `transferUserInfo` offline) e
Wearable Data Layer (Android, con store locale e flush al riaggancio).
Star Point usa esclusivamente i path v2 dopo una prova fresca della capability
`star_point_v1`; snapshot e lifecycle hanno una generazione autorevole monotona
per impedire che una consegna offline fuori ordine riapra una partita rimossa.
⚠️ Wear OS: `applicationId` del watch **deve** restare
`com.rallymate.rallymate` (uguale al telefono) e firmato con lo stesso
certificato, altrimenti il Data Layer non collega le app.

## Freemium (PRD 8)

| | Free | Plus €4,99 | Pro €8,99 | Coach €14,99 |
|---|---|---|---|---|
| Scoring, storico, 3 team, analytics base, FAQ regole, card base | ✅ | ✅ | ✅ | ✅ |
| Backup cloud, analytics avanzate, Wrapped illimitato, training premium, team ∞, **Duo Mode** | | ✅ | ✅ | ✅ |
| Pallino Assistant (LLM+fonti), difficoltà advanced, classifiche | | | ✅ | ✅ |
| Pacchetti, atleti, marketplace (+commissione 10-15%) | | | | ✅ |

Il gating è centralizzato in
`apps/rallymate/lib/domain/entitlements.dart`; l'acquisto va integrato con
RevenueCat nel solo punto `PaywallScreen._activate`.

## Duo Mode (Plus+)

Due team connessi segnano la stessa partita da due smartwatch, uno per team.

- **Collegamento**: il team premium crea la partita (Nuova partita →
  Modalità scoring → Duo Mode) e riceve un **codice a 6 caratteri** (scade
  in 2h); l'altro team entra con "Ho un codice" — anche da piano Free.
- **Scoring**: ogni telefono/watch segna SOLO i punti del proprio team
  (barriera anti-duplicazione); undo team-scoped, identico nei tre engine.
- **Compatibilità Star Point**: finché le RPC Duo non negoziano il protocollo
  di punteggio v2 di entrambi i telefoni, Star Point è bloccato in modo
  esplicito nel form, nel service e dal trigger Supabase. Golden point e
  vantaggi restano disponibili senza variazioni.
- **Sync**: locale-first. Push degli eventi propri su `duo_events`
  (idempotente per `eventId`, RLS autorizza solo il proprio team) + pull con
  polling 4s dalla schermata live; l'ordine autorevole è la `seq` del server
  e la sequenza locale viene riallineata a ogni pull (i due device
  convergono). Offline: coda locale (`cloudSynced=false`), sync al ritorno
  della rete e comunque a fine partita. Nessun realtime dedicato.
- **Storico**: la partita appare nello storico di entrambi con prospettiva
  "noi/loro" corretta (il guest è TEAM_B nella timeline canonica) e badge
  "⌚⌚ Duo Mode" nella scheda partita.
- **Gate**: `Entitlements.duoMode` (Plus+) in `domain/entitlements.dart`;
  server-side `has_duo_access()` in RLS. Test/admin senza acquisto:
  `profiles.premium_override=true` (o `account_role` admin, o build con
  `RALLYMATE_TEST_PREMIUM=true`) — nei log i tester compaiono come
  `[DUO][TEST-USER]`.
- Backend: `backend/supabase/migrations/0008_duo_mode.sql`
  (`duo_sessions`, `duo_events`, RPC `duo_create_session`/`duo_join_session`).
  Il contenimento Star Point è in
  `20260726223000_block_star_point_duo_without_protocol_negotiation.sql`.

## Account gratuito e profilo base

Login / registrazione / recupero password / logout vivono in
`apps/rallymate/lib/features/auth/auth_screen.dart` (route `/auth`);
la logica è in `CloudAuth` (`services/cloud/cloud_service.dart`):

- **Free**: sincronizza SOLO il profilo base (nome, nickname, mano, ruolo,
  livello, privacy). Al login su un nuovo device il profilo remoto viene
  ripristinato (pull) se quello locale è ancora il default; poi il push
  riallinea il server. Partite/statistiche restano locali.
- **Plus+**: backup completo (snapshot jsonb) separato dal sync base.
- **Logout**: chiude la sessione, scollega RevenueCat (`logOut`) e riallinea
  il piano locale allo store; i dati locali restano sul device.
- Errori GoTrue tradotti in italiano (`translateAuthError`), timeout su ogni
  chiamata di rete, esiti strutturati (`AuthResult`) — la conferma email non
  è più segnalata come errore.

L'onboarding (route `/onboarding`) parte automaticamente al primo avvio via
redirect del router (flag KV `onboarding_done`) e fa anche da editor profilo
(`/onboarding?edit=1` dal profilo).

## Social & matchmaking

Con account + profilo visibile il social usa il backend reale
(migration `0004_social_light.sql`): discovery giocatori, richieste
contatto/partita/team con RLS, inbox accetta/rifiuta. Senza account resta
un'anteprima etichettata DEMO. Il matching è deterministico e testato
(`lib/domain/social_matching.dart`): livello 40%, disponibilità 20%,
ruolo complementare 15%, stile 15%, affidabilità 10%. La posizione reale
non lascia mai il server: sulla mappa i marker usano posizioni
pseudo-casuali stabili derivate dall'id.

## Training per atleti

`lib/domain/training_insights.dart`: carico settimanale session-RPE
(minuti × sforzo percepito) con rapporto acuto:cronico (ACWR) e consigli di
dosaggio; focus settimanale guidato dai dati partita (tie-break e punti
decisivi hanno priorità sulle metriche generiche). Premium: sessione guidata
con timer per esercizio (`training_session_sheet.dart`). Ogni completamento
registra RPE + minuti effettivi. Seed contenuti versionato
(`training_seed_version` nel KV): gli aggiornamenti si aggiungono senza
toccare i dati esistenti.

## Dati salute (Pro)

Stesso canale `com.rallymate/health_connect` e stesso wire format su
entrambe le piattaforme: Android → Google Health Connect
(`HealthConnectBridge.kt`), iOS → Apple Salute/HealthKit
(`ios/Runner/HealthKitBridge.swift`, entitlement + usage description
inclusi). Solo lettura di aggregati: passi, kcal attive, minuti esercizio,
FC media. La finestra è sempre la giornata civile corrente nel fuso locale
(mezzanotte → adesso), non le ultime 24 ore; la UI aggiorna all'apertura, al
ritorno in foreground e ogni 5 minuti. Android usa l'Aggregate API di Health
Connect per rispettare priorità delle sorgenti ed evitare doppi conteggi.

## Stato verifiche

| Suite | Esito |
|---|---|
| rally_core (Dart) | 42/42 ✅ |
| App Flutter (analyze + test) | 0 issue, 24/24 ✅ |
| APK Android debug (con Supabase/RevenueCat/speech) | build ✅ |
| Wear OS (assemble + JVM test) | build ✅, 10/10 ✅ |
| watchOS SwiftPM | 20/20 ✅ |
| Companion watchOS + embedding iOS | simulatore e build firmata ✅ |

## Andare live

L'app funziona già al 100% offline. Per attivare cloud e abbonamenti resta
solo da impostare le credenziali (Supabase, RevenueCat): checklist
completa in **[docs/SETUP.md](docs/SETUP.md)**.

Compliance store e documenti legali (privacy IT/EN, ToS, guida
submission): **[docs/legal/](docs/legal/)** — leggere
`STORE_COMPLIANCE.md` prima di pubblicare.

Dettagli: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) ·
[docs/COSTS.md](docs/COSTS.md) ·
[docs/SETUP.md](docs/SETUP.md) ·
[backend/supabase/README.md](backend/supabase/README.md)
