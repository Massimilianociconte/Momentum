# Padelandia — Intercettazione Sessioni Workout & Undo Multi-passo · Report Tecnico

**Data:** 2026-07-20
**Ambito:** companion Apple Watch (watchOS) e Wear OS · associazione dati salute · pulsante Undo
**Stato:** completato e verificato (build + test)

---

## 1. Sintesi esecutiva

L'app intercetta l'attività fisica di una partita di padel avviando/associando una
sessione workout sul companion. Il bug storico era su **watchOS**: l'avvio della
partita creava **incondizionatamente** un `HKWorkoutSession`, e poiché HealthKit
ammette **un solo proprietario di sessione workout alla volta**, questo
**interrompeva la sessione già avviata** da Apple Fitness/altre app registrata in
Salute.

La correzione adotta un'architettura **ibrida**: Padelandia recupera prima una
propria sessione eventualmente sopravvissuta a un crash; se rileva un workout di
**un'altra app** entra in **osservazione passiva read-only** (legge FC/calorie
senza possedere una sessione, quindi senza interromperla); solo se non c'è alcun
conflitto avvia una nuova sessione. Su **Wear OS** questa disciplina era già
presente (controllo di `ExerciseTrackedStatus`) ed è stata confermata.

In parallelo è stato chiuso un gap UI sull'**Undo**: il motore di scoring è
event-sourced e sa già annullare punti oltre i confini di game/set (e persino
riaprire una partita completata), ma la **schermata di partita completata** non
esponeva alcun pulsante di annullamento su nessuna delle due companion. Ora
entrambe mostrano "Annulla ultimo punto" quando l'annullamento è possibile.

---

## 2. Comportamento precedente (bug)

### 2.1 Apple Watch (watchOS)
- `WatchWorkoutSessionManager.start(matchId:)` creava **sempre** un
  `HKWorkoutSession` + `HKLiveWorkoutBuilder`.
- HealthKit consente un solo owner di workout attivo: avviare la sessione
  Padelandia **terminava/soppiantava** una sessione esterna già in corso
  (es. allenamento "Padel/Tennis" avviato da Apple Fitness).
- Nessun rilevamento di sessioni esterne, nessun recupero della propria
  sessione dopo un crash → rischio di sessione orfana o dato di partita senza
  metriche.

### 2.2 Wear OS
- La logica corretta era **già presente** (`MatchWorkoutService.startWorkout()`
  interrogava `getCurrentExerciseInfoAsync()`), quindi non produceva il
  conflitto osservato su watchOS. Confermato in analisi.

---

## 3. Correzione applicata

### 3.1 Apple Watch — architettura ibrida
File: `wear/watchos/PadelandiaCore/Sources/PadelandiaWatchKit/WorkoutSessionManager.swift`

Nuovo flusso in `start(matchId:)`:
1. **`recoverOwnSession()`** — `recoverActiveWorkoutSession` per riagganciare una
   sessione Padelandia sopravvissuta a un riavvio/crash (nessun doppione).
2. **`isExternalWorkoutActive()`** — `HKSampleQuery` sul workout più recente per
   capire se un'altra app possiede una sessione attiva.
   - Se **sì** → **`startPassiveObservation()`**: registra `HKObserverQuery` per
     `heartRate` e `activeEnergyBurned` + `HKStatisticsQuery`, con background
     delivery per la FC, **senza** aprire una sessione concorrente. Stato UI:
     "Partita attiva (osservazione)".
   - Se **no** → avvia normalmente una nuova `HKWorkoutSession`.
3. **`end()`** distingue i due casi: se in osservazione passiva chiama
   `stopPassiveObservation()` (non tocca la sessione altrui); altrimenti chiude
   la propria sessione.
4. `resetSession()` azzera anche `passiveObservation`.

Tutto entro `#if os(watchOS) && canImport(HealthKit)`, usando **solo API
ufficiali** HealthKit/watchOS.

### 3.2 Wear OS — confermato (nessuna modifica funzionale al workout)
File: `wear/wearos/app/src/main/java/com/rallymate/wear/MatchWorkoutService.kt`
- `OTHER_APP_IN_PROGRESS` → `stopWithoutEndingExercise()` (non ruba la sessione).
- `OWNED_EXERCISE_IN_PROGRESS` → riaggancia la callback.
- `UNKNOWN` → `stopWithoutEndingExercise()`.
- Nuova sessione **solo** in assenza di conflitto.
- `WorkoutDetection.kt`: prompt opt-in non intrusivo, disattivato se c'è già una
  partita Padelandia o se lo stato non è `OTHER_APP_IN_PROGRESS`.

### 3.3 Associazione dati salute (lato telefono)
File: `apps/rallymate/lib/services/match_health_sync.dart`
- **Local-first**: la partita resta la fonte di verità locale.
- Dopo la fine, importa gli aggregati OS nella finestra della partita (±5 min).
- Associa solo metriche reali non vuote, con **confidenza onesta**
  (HIGH = link automatico; MEDIUM = memorizzata senza hard-link; bassa = scartata).
- **Deduplica** via content-hash; non inventa mai `sharedMatchId`.
- `hubProvider` ∈ { `APPLE_HEALTH`, `HEALTH_CONNECT` }.

---

## 4. Comportamento attuale

| Scenario | Apple Watch | Wear OS |
|---|---|---|
| Nessun workout esterno | Avvia nuova sessione | Avvia nuovo exercise |
| Workout esterno attivo | **Osservazione passiva** (read-only, non interrompe) | `stopWithoutEndingExercise` (non interrompe) |
| Sessione propria dopo crash | Recuperata (`recoverActiveWorkoutSession`) | Riaggancio callback |
| Permessi negati/revocati | Partita continua senza metriche | Partita continua senza metriche |
| Fine partita | Chiude solo la **propria** sessione | Chiude solo il **proprio** exercise |

**Requisiti soddisfatti:** nessuna interruzione/sovrascrittura di sessioni OS o di
altre app; nessun doppione; distinzione netta tra sessioni app-started e
user-started; funzionamento senza permessi; minimizzazione dati (solo metriche
essenziali associate localmente); esclusivamente API ufficiali.

---

## 5. Undo multi-passo (game/set) e riapertura partita

### 5.1 Modello
Il motore di scoring è **event-sourced** su tutte le piattaforme (Dart/Kotlin/
Swift/Monkey C/JS): il log eventi è la fonte di verità, lo stato deriva dal replay.
`undo` appende un evento `UNDO` e ricalcola. Gli eventi derivati
(`GAME_COMPLETED`, `SET_COMPLETED`, `MATCH_COMPLETED`) sono **ignorati** nel replay:
per questo l'annullamento **attraversa i confini di game/set** per costruzione, e
`canUndo` resta `true` finché esiste un `POINT`/`SCORE_EDITED` non annullato.

Coperto da test esistenti: `testUndoAcrossGameBoundary`, `testUndoReopensCompletedMatch`
(Swift) e "late synced undo reopens a completed match" (Dart).

### 5.2 Gap UI trovato e corretto
Durante una partita in corso il pulsante Undo era già presente e gated solo da
`canUndo && !paused` (sia scoring standard sia rapido). **Mancava** però nella
schermata di **partita completata**: se un punto errato assegnava il game/set
**finale** chiudendo il match, l'utente finiva sulla schermata di riepilogo
**priva di Undo**, pur potendo il motore riaprire la partita.

Correzione (entrambe le companion): la schermata di fine partita ora mostra
**"Annulla ultimo punto"** quando `canUndo` è vero. L'annullamento riapre la
partita (lo stato torna non-completed e la UI ripristina la view di scoring).
In Duo Mode l'undo resta **team-scoped**.

- watchOS: `WatchViews.swift` → `MatchDoneView`
- Wear OS: `MainActivity.kt` → `MatchDoneScreen`

---

## 6. Fix collaterali (lato telefono) inclusi in questo ciclo

| # | Problema | File | Correzione |
|---|---|---|---|
| 1 | Reconciliation perde eventi auth concorrenti (no re-arm) | `cloud_service.dart` | Flag `_reconciliationDirty` + split `reconcileCurrentSession`/`_reconcileInner`: se arriva un evento durante l'esecuzione, ri-esegue al termine |
| 2 | `RevenueCat logIn` saltato se fallisce il sync profilo | `cloud_service.dart` | `PurchasesService.logIn(uid)` reso indipendente dall'upsert profilo (try/catch separato) |
| 3 | Export backup non transazionale (torn snapshot) | `cloud_service.dart` | `_exportLocalDb()` avvolto in `_db.transaction()` |
| 4 | Coda Garmin: head-of-line blocking | `wearable_provider_service.dart` | `commit` per-entry in try/catch: un batch fallito non blocca i successivi |
| 5 | Comparatore causal-order: misordering cross-device | `wearable_cloud_sync.dart` | Confronto di `sequence` solo tra eventi dello **stesso** `deviceId`, poi timestamp, poi `eventId` |

(Il punto "Navigator.pop dentro setState" rientrava nel #5 ed è coperto dalla stessa correzione lato reconciliation/stato.)

---

## 7. Flussi separati Apple Watch vs Wear OS

**Apple Watch**
`start` → recover own → detect external (`HKSampleQuery`) → [passive `HKObserverQuery`/`HKStatisticsQuery`] oppure [nuova `HKWorkoutSession`+`HKLiveWorkoutBuilder`] → live FC/calorie → `end` differenziato → associazione lato telefono via HealthKit.

**Wear OS**
`startWorkout` → `getCurrentExerciseInfoAsync` → branch su `ExerciseTrackedStatus` → [nuovo `ExerciseClient` exercise] oppure [reattach] oppure [`stopWithoutEndingExercise`] → metriche via Health Services → associazione via Health Connect.

---

## 8. Test eseguiti e risultati

| Suite | Comando | Risultato |
|---|---|---|
| watchOS PadelandiaCore + WatchKit (host) | `swift test` | **41 test, 0 failure** |
| watchOS compilazione target-reale | `xcodebuild -scheme PadelandiaWatchKit -sdk watchsimulator26.5` | **BUILD SUCCEEDED** (compila il codice `#if os(watchOS)`) |
| Wear OS | `./gradlew :app:compileDebugKotlin :app:testDebugUnitTest` (JBR Android Studio) | **BUILD SUCCESSFUL** |
| Flutter app (ciclo precedente) | `flutter test` | 131 test passati |
| rally_core (ciclo precedente) | `dart test` | 84 test passati |

> Nota: `swift test` gira su host macOS e non compila i rami `#if os(watchOS)`;
> per questo la compilazione del codice HealthKit/UI è stata verificata con
> `xcodebuild` sul SDK watchOS Simulator.

---

## 9. Limiti imposti dalle API OS

- **HealthKit (watchOS):** un solo owner di workout attivo per volta → in caso di
  sessione esterna si può solo **osservare** (read-only), non "prendere in
  prestito" la sessione altrui. La FC live in osservazione dipende dalla cadenza
  di `HKObserverQuery`/background delivery, non da un builder proprietario.
- **Health Services (Wear OS):** analogamente un solo owner di exercise; con
  `OTHER_APP_IN_PROGRESS` non si può avviare un exercise proprio senza terminare
  l'altro, quindi si evita del tutto.
- **Permessi:** revocabili in qualsiasi momento; l'app resta pienamente
  funzionale per lo scoring anche senza dati salute.
- **Associazione:** aggregati OS disponibili con latenza; l'associazione avviene
  a fine partita con finestra temporale e confidenza, senza inventare identificatori.

---

## 10. Problemi residui / follow-up consigliati

- **Osservazione passiva watchOS:** la granularità della FC in modalità passiva è
  inferiore a quella di un builder proprietario (dipende dagli observer query);
  accettabile perché la priorità è non interrompere la sessione altrui.
- **Test end-to-end su device fisico:** i controlli automatici coprono
  compilazione e unit test; consigliata una verifica manuale su Apple Watch reale
  con Apple Fitness attivo e su Wear OS con altra app di fitness attiva.
- **Undo su partita completata:** verificato a livello di motore e di UI/build;
  consigliato uno smoke test manuale del percorso "set finale errato → Annulla →
  ripresa scoring" su entrambe le companion.
