# Architettura Padelandia

## Vista d'insieme

```
┌────────────────┐   WatchConnectivity   ┌─────────────────┐
│  Apple Watch   │◄─────────────────────►│                 │
│  SwiftUI       │                       │   App Flutter    │      Supabase
│  PadelandiaCore │                       │   iOS + Android  │◄────► (solo premium:
└────────────────┘                       │                 │       backup, recap,
┌────────────────┐    Data Layer API     │  rally_core     │       assistant, coach)
│  Galaxy/WearOS │◄─────────────────────►│  Drift (SQLite) │
│  Compose       │                       │  Riverpod       │
│  engine Kotlin │                       └─────────────────┘
└────────────────┘
```

## 1. Event sourcing del punteggio (decisione centrale)

**Perché**: PRD Rischio 1 (scoring impreciso) + acceptance criteria
("l'undo deve funzionare sempre", "il punteggio deve essere ricostruibile
dagli eventi", "partita recuperabile se watch e telefono perdono la
connessione").

**Come**:
- Il log `MatchEvent[]` è l'unica fonte di verità; lo stato è derivato dal
  replay integrale a ogni mutazione (O(n) su ≲300 eventi: microsecondi,
  ampiamente dentro il requisito "punto registrato < 1s").
- `UNDO` è un evento: in replay annulla l'ultima azione undoabile
  (punto o correzione manuale). Undo oltre confini di game/set/match è
  corretto *per costruzione*, non gestito a mano.
- Gli eventi derivati (GAME/SET/SIDE_CHANGE/MATCH_COMPLETED) vengono
  scritti nel log per audit/analytics ma **ignorati nel replay**: nessun
  rischio di doppia applicazione.
- Sync idempotente: `eventId` univoci + `insertOrIgnore` ⇒ un re-sync
  completo del log non duplica mai nulla; i due device convergono.

**Tre port, un contratto**: Dart (`packages/rally_core`), Kotlin
(`wear/wearos/.../ScoringEngine.kt`), Swift
(`wear/watchos/PadelandiaCore`). Stessa semantica, stesso JSON, stessa
suite di test (golden point, vantaggi, TB 7-6 con 2 di scarto, super TB,
rotazione servizio 1-2-2 nel TB, cambio campo ogni 6 punti nel TB e nei
game dispari, free play, undo, round-trip JSON). Qualunque modifica alle
regole va replicata nei tre engine **e nei tre test**.

## 2. Regole padel implementate

- Punteggio 0/15/30/40; sul 40-40 **golden point** (default FIP) o
  vantaggi secondo formato.
- Set a 6 game con 2 di scarto; 6-6 → tie-break a 7 (2 di scarto),
  registrato 7-6 con punteggio TB conservato.
- Formati: golden BO3, vantaggi BO3, super tie-break a 10 al posto del 3°
  set, set secco, allenamento libero (solo conteggio punti), custom.
- Servizio: alternanza per game; nel TB 1-2-2-2 con derivazione del
  battitore corrente; il set successivo riparte dal team che non ha
  servito per primo nel TB.
- Cambio campo: game dispari, ogni 6 punti nel TB, a fine set
  (`sideChangePending` nello stato + evento SIDE_CHANGE).

## 3. App Flutter (apps/rallymate)

- **Persistenza**: Drift/SQLite locale (offline-first, PRD 5.1). Tabelle:
  players, teams, matches (header) + match_event_rows (log), trainings,
  training_logs, key_values. Il `MatchSummary` è calcolato alla chiusura e
  cachato in `matches.summary_json` → le analytics aggregate non
  rileggono mai i log evento.
- **Stato**: Riverpod. `LiveMatchController` incapsula l'engine: ogni
  azione persiste subito i nuovi eventi (crash-safe), poi aggiorna la UI e
  finalizza il summary al `MATCH_COMPLETED`.
- **Navigazione**: go_router con shell a 5 tab (Home, Partite, Analisi,
  Training, Profilo) + route full-screen (setup, live, dettaglio, wrapped,
  team, regole, paywall).
- **Feature → PRD**: Home dashboard settimanale (B), setup partita con
  formati/tag/difficoltà (C), scoring due-pulsanti + Blind Mode + undo +
  correzione manuale + haptics (D), mascotte Rally con FAQ locale e gate
  "non ho abbastanza certezza" (E2), analytics base/premium con momentum
  painter e clutch (F), Wrapped card 4:5 renderizzata via RepaintBoundary
  e condivisa con share_plus (G), allenamenti free/premium per ruolo (H),
  paywall 4 piani (8).
- **Entitlements**: un solo file (`domain/entitlements.dart`) decide ogni
  gate; `PremiumGate` widget uniforma i teaser. RevenueCat si integra in
  un solo punto.

## 4. Watch app

Native (PRD 9.2), standalone-first: la partita si può segnare senza
telefono e sincronizzare dopo.

- **Wear OS**: Compose for Wear OS; store locale SharedPreferences con
  flag `synced` per evento; `PhoneListenerService` riceve `start_match` /
  `state_response` anche ad app chiusa; Ambient Mode + Ongoing Activity
  per Always On, Health Services `ExerciseClient` durante la partita,
  `PassiveListenerService` opzionale ed event-driven per proporre l'avvio
  quando Health Services espone un esercizio esterno, senza auto-apertura,
  vibrazioni semantiche (breve = punto, doppia = undo, lunga = game/set —
  PRD D1).
- **Samsung Galaxy Watch**: coperto dallo stesso modulo Wear OS, usando
  Android Health Services come API ufficiale e portabile. Il Samsung Health
  Sensor SDK resta un modulo opzionale futuro solo per sensori raw/proprietari:
  ha scope limitato a Galaxy Watch4+ Wear OS Powered by Samsung, richiede package e
  firma registrati e non deve diventare dipendenza del percorso MVP multi-watch.
- **watchOS**: companion SwiftUI incorporata nel target iOS tramite
  `scripts/sync_watchos_target.rb`; WatchConnectivity usa `sendMessage` se
  raggiungibile e `transferUserInfo` altrimenti, con coda persistente anche
  sul telefono. Haptics native, vista Always On dedicata tramite
  `isLuminanceReduced`, HKWorkoutSession/HKLiveWorkoutBuilder durante la
  partita, `StartWorkoutIntent` per avvio esplicito Siri/Action Button e
  recupero ufficiale della sessione dopo un crash. La spec XcodeGen
  `project.yml` è soltanto un supporto per build isolate.
- **Garmin**: modulo separato `wear/garmin-connectiq` per Connect IQ /
  Monkey C. Il contratto eventi comune vive in
  `wear/shared/watch_module_protocol.md`; la sync usa i Connect IQ Mobile SDK
  ufficiali iOS/Android, poi il gateway autenticato e idempotente. Un match
  avviato da Padelandia possiede una sessione FIT Padel/Tennis; attività Garmin
  esterne restano intatte e forzano il solo scoring.
- **Fitbit OS**: modulo nativo `wear/fitbit-os`, con binari distinti OS 4/5,
  scoring offline, companion, pairing monouso e comandi server durevoli. È un
  percorso legacy/manuale: le app terze non sono installabili nell'EEA.
- **Fitbit Air / Google Health**: modulo `wear/fitbit-google-health`. Fitbit
  Air e screenless device non possono ospitare UI live; sono sorgenti dati
  opt-in Pro via Google Health OAuth, token cifrati e rollup giornalieri.
- **Samsung Tizen**: nessun binario nuovo, perche Samsung ha terminato nuove
  pubblicazioni e aggiornamenti. Il catalogo mostra una guida di migrazione a
  Galaxy Watch4+ con Wear OS.
- **Blind Mode** (PRD D2, feature distintiva): schermo nero diviso in due
  aree, tap = punto, double-tap = undo, long-press = esci; conferme solo
  aptiche.

## 5. Backend minimo (backend/supabase)

Vedi `backend/supabase/README.md`. Scelte chiave: free tier a costo ~zero
(nessun dato partita in cloud), backup premium come snapshot jsonb
(1 riga/device, non riga-per-evento), recap pubblici serviti da una edge
function con cache CDN, assistant LLM con pipeline RAG→cache→DeepSeek e limiti
hard, commissioni coach calcolate
server-side con anti-replay sulla ricevuta store.

## 5b. Duo Mode (premium)

Due team connessi segnano la stessa partita da due smartwatch, uno per
team. Principi:

- **Stesso event sourcing**: nessun motore nuovo. La partita condivisa è
  una normale timeline `MatchEvent` con matchId comune; ogni evento porta
  attribuzione (`sourceUserId`, `sourceTeamId`, `duo`).
- **Barriera anti-duplicazione**: ogni device (telefono e watch) genera
  SOLO punti del proprio team; l'undo è team-scoped (`undo(team:)` nei tre
  engine), così i log interlacciati in ordini diversi convergono allo
  stesso punteggio.
- **Sync a costo minimo**: niente realtime dedicato. Push degli eventi
  propri su `duo_events` (insert idempotente per eventId, la RLS autorizza
  solo il proprio team) + pull con polling 4s dalla schermata live.
  L'ordine autorevole è la `seq` server: dopo ogni pull la sequenza locale
  viene riallineata (`realignDuoOrder`) e i due telefoni convergono.
  Offline: coda locale (`cloudSynced=false`), sync al ritorno della rete e
  comunque a fine partita.
- **Collegamento team**: codice partita a 6 caratteri con scadenza 2h
  (RPC `duo_create_session`/`duo_join_session`, migration 0008); il gate
  premium è la RLS (`has_duo_access`: piano Plus+, `premium_override`
  tester o admin). Chi entra col codice può essere anche Free: paga chi
  crea la sessione.
- **Prospettiva storico**: timeline canonica A/B; il guest è TEAM_B e il
  suo summary locale viene specchiato ("noi/loro" corretto per entrambi).

## 6. Cosa NON c'è (deliberatamente, PRD 6.2)

Prenotazione campi, commenti, video/AI video, riconoscimento vocale
continuo, tornei complessi, club dashboard. Garmin/Fitbit hanno ora moduli
separati di integrazione, ma richiedono ancora account sviluppatore, device
target reali, chiavi OAuth/SDK e review specifiche prima della distribuzione.

## 7. Prossimi passi suggeriti

1. Integrazione RevenueCat (paywall) + webhook → `set_plan`.
2. Upload immagine Wrapped su storage + `wrapped_cards` (link pubblico
   già pronto lato backend).
3. Client Supabase nell'app (auth + backup Plus).
4. Configurare credenziali provider e completare l'accettazione Garmin/Fitbit/
   Google Health su device fisici e console ufficiali.
5. Beta chiusa in campo (Fase 1 roadmap): validare scoring reale e KPI
   "partite tracciate/settimana".
