# Momentum — Proprietà unica della sessione allenamento · Report tecnico

**Data:** 2026-07-25
**Ambito:** Apple Watch (watchOS/HealthKit), Wear OS (Health Services), Garmin
(Connect IQ ActivityRecording), Fitbit OS (exercise API)
**Sostituisce:** `WORKOUT_INTERCEPTION_AND_UNDO_REMEDIATION_2026-07-20.md` per la
parte workout (l'approccio "ibrido / osservazione passiva" lì descritto è stato
rimosso: era la causa di parte dei sintomi qui analizzati).

---

## 1. Causa precisa del problema

Tre difetti indipendenti che, combinati, producono esattamente i sintomi
riportati (segmento ~5 min, allenamento Fitness ~22 min, nessuna sessione lunga
quanto la partita).

### 1.1 Riarmo della sessione a ogni punto (causa primaria)

`WatchMatchViewModel.point()` chiamava `startWorkoutIfNeeded()` **a ogni punto
segnato**. La guardia era `workoutMetrics.active == false`.

```swift
// prima
public func point(_ team: TeamId, blind: Bool = false) {
    ...
    startWorkoutIfNeeded()          // <— a ogni tap
    let result = engine.addPoint(...)
```

Conseguenza: appena la sessione RallyMate smetteva di essere `active`, **il
punto successivo ne apriva una nuova**. Poiché watchOS ammette una sola
`HKWorkoutSession` attiva, ogni nuova sessione RallyMate terminava quella
dell'app Allenamento, che a sua volta — riavviata dall'utente o dal sistema —
terminava quella di RallyMate. Da qui il ping-pong e i frammenti di durata
arbitraria (5 min lato Momentum, 22 min lato Fitness) su una partita di 90.

### 1.2 Segmento scartato invece che finalizzato

```swift
// prima
public func workoutSession(_ s: HKWorkoutSession, didFailWithError error: Error) {
    Task { @MainActor in
        resetSession(active: false, status: "Workout interrotto: ...")  // builder = nil
    }
}
```

La documentazione Apple garantisce che `workoutSession(_:didFailWithError:)` è
consegnato **prima** del cambio di stato corrispondente. Azzerando `builder`
nella callback di errore, la successiva transizione `.ended` trovava
`builder == nil` e **non chiamava mai** `endCollection` + `finishWorkout`: il
tempo già registrato veniva perso, e `metrics.active` tornava `false`,
riattivando il difetto 1.1. Inoltre l'errore era trattato come errore generico,
non come la condizione prevista `errorAnotherWorkoutSessionStarted`.

### 1.3 Rilevamento "workout esterno" strutturalmente inaffidabile

`isExternalWorkoutActive()` interrogava `HKSampleQuery` sul tipo `HKWorkout` per
inferire se un'altra app stesse registrando. Un workout **in corso non è ancora
un campione `HKWorkout`**: viene scritto in Salute solo alla finalizzazione.
L'euristica dava quindi falsi negativi sistematici, e RallyMate apriva la
sessione interrompendo quella dell'utente.

### 1.4 Difetti minori confermati nell'audit

| Punto auditato | Esito |
|---|---|
| `HKWorkoutConfiguration.activityType` | era `.other` — perde la classificazione racchetta |
| `prepare()` | mai chiamato (corretto: nessun countdown), ma non documentato |
| stato `.stopped` | non gestito nel delegate → sessione mai chiusa in quel ramo |
| finalizzazione | non idempotente, nessun watchdog se `.ended` non arriva |
| doppio tap su avvio | nessuna serializzazione: due `start()` concorrenti possibili |
| callback delegate duplicate | nessuna guardia di identità sessione |
| persistenza | solo un booleano `workout_active_<matchId>`: nessun ID/stato/segmenti |
| background delivery | `enableBackgroundDelivery(.hourly)` per la FC in modalità passiva, mai disabilitata in tutti i rami |
| scelta utente | inesistente: il proprietario della registrazione era deciso da un'euristica |

---

## 2. Flusso precedente e flusso corretto

### 2.1 Precedente

```
Nuova partita ──▶ start() ──▶ euristica HKSampleQuery
                                 ├─ (falso negativo) ──▶ crea HKWorkoutSession ──▶ uccide la sessione Allenamento
                                 └─ (positivo) ──▶ osservazione passiva (query FC/calorie)

ogni PUNTO ──▶ startWorkoutIfNeeded() ──▶ se !active ──▶ nuova sessione ──▶ (loop)

didFailWithError ──▶ resetSession()      // builder perso, nessun salvataggio
didChangeTo(.ended) ──▶ finishWorkout()  // mai raggiunto dopo un errore
```

### 2.2 Corretto

```
Nuova partita ──▶ l'utente sceglie il proprietario (3 opzioni)
        │
        ├─ RALLYMATE_MANAGED ──▶ requestStart() [unico gate]
        │        ├─ recoverActiveWorkoutSession()  (adotta la propria sessione sopravvissuta)
        │        ├─ HKWorkoutSession(.tennis) + HKLiveWorkoutBuilder
        │        └─ startActivity + beginCollection ──▶ RUNNING
        │
        ├─ EXTERNAL_MANAGED ──▶ nessuna sessione. Solo scoring.
        │                        Il workout arriva dopo da Salute (import lato iPhone).
        └─ DISABLED ──▶ nessuna sessione, nessun dato salute.

ogni PUNTO ──▶ solo scoring. Nessun contatto con il lifecycle della registrazione.

Fine partita ──▶ end() ──▶ session.end() ──▶ .ended ──▶ finalize() [idempotente]
                                            └─ watchdog 8 s se il delegate non arriva

errorAnotherWorkoutSessionStarted ──▶ PREEMPTED ──▶ chiude e SALVA il segmento svolto
                                              ──▶ stato EXTERNAL_OWNED (terminale)
                                              ──▶ avviso all'utente, partita invariata
                                              ──▶ nessun riavvio automatico
                                              ──▶ riavvio solo dopo tap esplicito "Riavvia"
```

---

## 3. File modificati

### Apple Watch

| File | Modifica |
|---|---|
| `wear/watchos/RallyMateCore/Sources/RallyMateWatchKit/WorkoutRecordingPolicy.swift` | **nuovo** — state machine pura, modalità, segmenti, qualità dati |
| `wear/watchos/RallyMateCore/Sources/RallyMateWatchKit/WorkoutRecordingLog.swift` | **nuovo** — log strutturato privacy-safe (`os.Logger`) |
| `wear/watchos/RallyMateCore/Sources/RallyMateWatchKit/WorkoutSessionManager.swift` | riscritto: `.tennis`, gate unico, finalizzazione idempotente, watchdog, rimozione osservazione passiva ed euristica |
| `wear/watchos/RallyMateCore/Sources/RallyMateWatchKit/WatchMatchViewModel.swift` | rimosso il riarmo per punto; modalità congelata per partita; persistenza segmenti/stato; `restartHealthRecording()` |
| `wear/watchos/RallyMateCore/Sources/RallyMateWatchKit/LocalMatchStore.swift` | preferenza default + per-partita, segmenti, stato registrazione |
| `wear/watchos/RallyMateCore/Sources/RallyMateWatchKit/WatchViews.swift` | sezione "Registrazione allenamento", banner di interruzione, riga qualità dati |
| `wear/watchos/RallyMateWatchApp/RallyMateWatchApp.swift` | recovery di sistema: ripristina segmenti prima di riagganciare la sessione |
| `wear/watchos/RallyMateCore/Tests/RallyMateWatchKitTests/WorkoutRecordingPolicyTests.swift` | **nuovo** — 22 test |
| `wear/watchos/RallyMateCore/Tests/RallyMateWatchKitTests/WatchWorkoutOwnershipTests.swift` | **nuovo** — 8 test end-to-end sul view model |
| `apps/rallymate/ios/Runner.xcodeproj` | rigenerato con `scripts/sync_watchos_target.rb` (nuovi sorgenti nel target watch) |

### Wear OS

| File | Modifica |
|---|---|
| `wear/wearos/app/src/main/java/com/rallymate/wear/WorkoutRecordingPolicy.kt` | **nuovo** — stessa state machine in Kotlin |
| `wear/wearos/app/src/main/java/com/rallymate/wear/MatchWorkoutService.kt` | riscritto sul gate unico; `OTHER_APP_IN_PROGRESS`/`UNKNOWN` come condizione prevista e terminale; stop idempotente |
| `wear/wearos/app/src/main/java/com/rallymate/wear/MatchViewModel.kt` | rimosso il riarmo per punto; modalità per partita; qualità dati |
| `wear/wearos/app/src/main/java/com/rallymate/wear/PhoneSync.kt` (`LocalMatchStore`) | preferenza default + per-partita (con lettura del flag legacy), segmenti, stato |
| `wear/wearos/app/src/main/java/com/rallymate/wear/MainActivity.kt` | selettore a 3 opzioni + nota di esclusività, riga qualità nel riepilogo |
| `wear/wearos/app/src/test/java/com/rallymate/wear/WorkoutRecordingPolicyTest.kt` | **nuovo** — 15 test |

### Garmin

| File | Modifica |
|---|---|
| `wear/garmin-connectiq/source/RallyMateActivitySession.mc` | `RallyMateRecordingPolicy` (gate puro), modalità persistita, stato di proprietà terminale, `startForMatchWithConsent` |
| `wear/garmin-connectiq/source/RallyMateDelegate.mc` | voce di menu "Registrazione allenamento" + sottomenu a 3 opzioni |
| `wear/garmin-connectiq/resources/strings/strings.xml`, `resources-ita/strings/strings.xml` | 5 nuove stringhe EN/IT |
| `wear/garmin-connectiq/source/RallyMateTests.mc` | +4 test Run No Evil |

### Fitbit OS

| File | Modifica |
|---|---|
| `wear/fitbit-os/common/workout_recording.js` | **nuovo** — stessa policy in JS puro |
| `wear/fitbit-os/app/exercise_owner.js` | **nuovo** — wrapper difensivo sull'API `exercise` (feature detection + permesso) |
| `wear/fitbit-os/app/index.js` | modalità per partita, apertura/chiusura singola, pausa/ripresa, riepilogo qualità |
| `wear/fitbit-os/resources/index.view` | selettore registrazione + nota + riga salute nel riepilogo |
| `wear/fitbit-os/package.json` | aggiunto il permesso `access_exercise` |
| `wear/fitbit-os/test/workout_recording.test.mjs` | **nuovo** — 12 test |

**Non modificato (verificato e già corretto):** `apps/rallymate/lib/services/match_health_sync.dart`
importa gli aggregati OS nella finestra della partita (±5 min) con confidenza
onesta (`windowMetricsOnly` → MEDIUM, nessun hard-link falso). È esattamente il
percorso previsto per la modalità `EXTERNAL_MANAGED`.

---

## 4. Nuova state machine

Un solo proprietario per partita. Tipo valore puro, senza dipendenze HealthKit,
quindi interamente testabile sull'host.

```
                 requestStart()            [UNICO gate che può creare una sessione]
                       │
   mode = DISABLED ────┴──▶ DISABLED (terminale)
   mode = EXTERNAL  ──────▶ EXTERNAL_OWNED (terminale)
   mode = RALLYMATE
        │
        ├─ stato possiede già la sessione ──▶ rifiuto DUPLICATE_START_IGNORED
        ├─ stato terminale && !userInitiated ──▶ rifiuto AUTO_RESTART_SUPPRESSED
        └─ altrimenti
                │
             PREPARING ─┬─ startAccepted ─────────▶ RUNNING ⇄ PAUSED
                        ├─ startBlocked ──────────▶ IDLE   (riprovabile: nulla creato)
                        ├─ authorizationDenied ───▶ FAILED
                        ├─ healthUnavailable ─────▶ FAILED
                        ├─ creationFailed ────────▶ FAILED
                        ├─ recovered ─────────────▶ RUNNING | PAUSED
                        └─ preempted ─────────────▶ FINALIZING

   RUNNING/PAUSED ─┬─ stopRequested ─▶ STOPPING ─▶ sessionEnded ─▶ FINALIZING
                   ├─ preempted ────────────────────────────────▶ FINALIZING
                   └─ sessionFailed ────────────────────────────▶ FINALIZING

   FINALIZING ─┬─ finalizeSucceeded ─▶ SAVED            (o EXTERNAL_OWNED se preempted)
               └─ finalizeFailed ────▶ FAILED           (o EXTERNAL_OWNED se preempted)
```

Invarianti garantite dai test:

- `acceptedStarts == 1` per una partita normale, qualunque sia il numero di punti.
- Un evento duplicato (callback ridondante del delegate) restituisce `nil`: nessuna
  transizione, nessun secondo segmento.
- Da uno stato terminale si esce **solo** con `userInitiated = true`.
- I segmenti sovrapposti vengono **fusi**, mai sommati due volte; sono ritagliati
  sulla finestra `[match.startTime, match.endTime]`.

### Modalità utente

| Modalità | Effetto |
|---|---|
| `RALLYMATE_MANAGED` | Momentum crea e chiude l'unica sessione HealthKit |
| `EXTERNAL_MANAGED` | Nessuna sessione. Solo scoring; il workout viene associato dopo tramite Apple Health |
| `DISABLED` | Nessuna registrazione salute |

La preferenza è persistente e **modificabile per ogni nuova partita**; una volta
avviata la partita, il proprietario è **congelato** (cambiare il default non
sposta la proprietà di una registrazione in corso).

### Integrità durata e dati

- `match.startTime`/`match.endTime` derivano dagli eventi `MATCH_STARTED` /
  `MATCH_COMPLETED` dello scoring engine, **distinti** dai tempi HealthKit ma
  usati come finestra di riferimento per la copertura.
- Il passaggio in background **non emette alcun evento** di registrazione: l'unico
  modo di uscire da `RUNNING` è uno stop esplicito, un errore o una preemption.
- Finalizzazione idempotente (`finalizeInFlight` + guardie di stato) e watchdog di
  8 s se il delegate `.ended` non arriva.
- La qualità dati è calcolata e mostrata:
  `complete` (1 segmento salvato, copertura ≥ 90%), `partial`, `external`,
  `none`, `pending`. Una registrazione di 5 min su una partita di 90 è sempre
  `partial`, mai presentata come durata della partita.

---

## 5. Gestione degli errori HealthKit

| Errore | Trattamento |
|---|---|
| `errorAnotherWorkoutSessionStarted` (8) | **condizione prevista**: chiude e finalizza il segmento svolto, stato `EXTERNAL_OWNED`, messaggio chiaro, partita e scoring invariati, nessun loop di riavvio. Nuovo segmento solo su richiesta esplicita |
| `errorBackgroundWorkoutSessionNotAllowed` (14) | nessuna sessione creata → stato riportato a `IDLE`, riprovabile al ritorno in foreground (non è un riavvio: nessun segmento duplicato) |
| `errorAuthorizationDenied` / `errorRequiredAuthorizationDenied` / revoca in corsa | `FAILED`; lo scoring continua. Se c'era un segmento aperto viene finalizzato |
| `errorHealthDataUnavailable` | `FAILED`, messaggio dedicato, scoring invariato |
| Altri errori di `HKWorkoutSession.init` | `FAILED` con codice HealthKit registrato |
| `beginCollection` fallita | sessione mantenuta, stato "senza metriche live", scoring invariato |
| `endCollection`/`finishWorkout` fallite | `FAILED` (o `EXTERNAL_OWNED` se preempted); il segmento resta marcato **non salvato** e la qualità lo riflette |

Ogni transizione produce una riga di log strutturata con **stato precedente,
nuovo stato, motivo, timestamp e codice errore HealthKit**, e un token opaco
non reversibile al posto del match id. Nessun valore di frequenza cardiaca,
caloria, identificativo account o nome team viene loggato.

```
1700000300 m3f2a91c4 running->finalizing PREEMPTED_BY_OTHER_APP hk=8
```

---

## 6. Modifiche UI

**Apple Watch**

- Schermata *Nuova partita*: nuova sezione **REGISTRAZIONE ALLENAMENTO** accanto a
  formato/ruolo/team, con le tre opzioni e la nota
  *"Non avviare due allenamenti insieme: watchOS ne tiene attivo uno solo."*
  Ogni opzione ha un sottotitolo che spiega cosa comporta.
- Header punteggio: l'indicatore workout mostra il **proprietario** della
  registrazione quando non è attiva (ambra se un'altra app l'ha presa).
- Banner di interruzione con "Ho capito" e "Riavvia" (quest'ultimo solo quando è
  legittimo), che avvisa che i dati salute della partita sono parziali.
- Riepilogo fine partita: riga **qualità e completezza** con minuti registrati su
  minuti di partita e numero di segmenti.

**Wear OS** — selettore a 3 opzioni + nota nella schermata Nuova partita; riga
qualità nel riepilogo.

**Garmin** — voce di menu *Registrazione allenamento* con sottomenu a 3 opzioni e
toast *"Una sola attività alla volta"* (EN/IT).

**Fitbit OS** — pulsante ciclico *Registrazione* nel pannello di avvio + nota;
riga salute nella schermata di fine partita.

---

## 7. Test eseguiti

Tutti i comandi eseguiti su questa macchina, esito riportato senza aggiustamenti.

| Suite | Comando | Esito |
|---|---|---|
| Apple Watch — unit | `swift test` (`wear/watchos/RallyMateCore`) | **71 test, 0 failure** (erano 41 prima: +30) |
| Apple Watch — compilazione watchOS | `xcodebuild -scheme RallyMateWatchKit -destination 'generic/platform=watchOS'` | **BUILD SUCCEEDED**, 0 warning |
| Apple Watch — app target Debug | `xcodebuild -scheme RallyMateWatchApp -destination 'generic/platform=watchOS Simulator'` | **BUILD SUCCEEDED** |
| Apple Watch — app target Release device | `xcodebuild -scheme RallyMateWatchApp -configuration Release -destination 'generic/platform=watchOS'` | **BUILD SUCCEEDED** |
| Wear OS — unit | `./gradlew testDebugUnitTest` | **44 test, 0 failure** (erano 29: +15) |
| Wear OS — APK | `./gradlew assembleDebug` | **BUILD SUCCESSFUL** |
| Garmin — app | `scripts/build.sh venu3` | compilazione **BUILD SUCCESSFUL** |
| Garmin — binario test | `monkeyc -f test.jungle -t -d venu3` | **BUILD SUCCESSFUL** (`RallyMate-venu3-tests.prg`) |
| Fitbit — unit | `npm test` | **42 test, 0 failure** (erano 30: +12) |
| Fitbit — build | `npm run build` | build completata per Versa 3 e Sense |

Scenari coperti dai test automatici (matrice obbligatoria):

| Scenario richiesto | Copertura |
|---|---|
| Partita 90 min gestita solo da Momentum | `testNinetyMinuteMatchProducesOneSavedSegment`, `testFullMatchOpensAndClosesExactlyOneRecording` |
| Allenamento Apple già attivo prima dell'avvio | `testPreemptionAtStartLeavesNoSegmentAndNoRetryLoop`, `testExternalModeNeverCreatesASession` |
| Allenamento Apple avviato dopo Momentum | `testPreemptionMidMatchSavesPartialSegmentWithoutRestart`, `testPreemptionKeepsMatchAliveAndSuppressesAutomaticRestart` |
| App Watch in background / ritorno al quadrante | `testBackgroundAndWatchFaceDoNotCloseTheRecording`, `testBackgroundBlockedStartStaysRetryable`, e le transizioni `prepareForBackground`/`prepareForInactive` dentro `testFullMatchOpensAndClosesExactlyOneRecording` |
| Perdita connessione iPhone | `testPhoneDisconnectionDoesNotAffectTheRecording` |
| Chiusura forzata | `testRecoveredSessionContinuesTheSameSegment`, `testRecoveryDuringStartAdoptsInsteadOfCreatingASecondSession`, `testSegmentsAndStateArePersistedForIdempotentFinalisation` |
| Permessi negati o revocati | `testDeniedAuthorizationFailsClosedWithoutRestartLoop`, `testAuthorizationRevokedMidMatchSavesWhatWasCollected`, `testHealthKitUnavailableKeepsScoringAlive` |
| Pausa e ripresa | `testPauseAndResumeKeepASingleSegment` |
| Fine partita dal Watch | `testFinishAfterSaveDoesNotReopenTheRecording` |
| Doppio tap sul comando di avvio | `testDoubleTapOnStartCreatesOneSessionOnly` |
| Callback delegate duplicate | `testDuplicateDelegateCallbacksAreIdempotent` |
| Salvataggio e sync post-partita | `testSegmentsAndStateArePersistedForIdempotentFinalisation`, `testOfflineFinishSurvivesRelaunchAndRemainsQueued` (preesistente) |

Gli stessi scenari sono replicati su Wear OS (`WorkoutRecordingPolicyTest`),
Garmin (4 test Run No Evil sul gate) e Fitbit (`workout_recording.test.mjs`).

---

## 8. Durate realmente registrate

**Nessuna partita reale è stata giocata per questa verifica.** Le durate qui
sotto vengono dai test deterministici, che simulano la timeline con timestamp
espliciti; non sono misure raccolte su hardware.

| Scenario simulato | Durata partita | Durata registrata | Segmenti | Etichetta |
|---|---|---|---|---|
| Partita gestita da Momentum, 40 punti, background e wrist-down | 90 min | 90 min | 1 salvato | Dati salute completi |
| Allenamento Apple avviato al minuto 5 | 90 min | 5 min | 1 salvato | **Dati salute parziali** (copertura 5,6%) |
| Allenamento Apple già attivo all'avvio | 90 min | 0 min | 0 | Registrato da app esterna |
| Preemption al 5' + riavvio esplicito al 20' | 90 min | 75 min | 2 salvati | **Dati salute parziali**, 2 segmenti |
| Permessi revocati al 40' | 90 min | 40 min | 1 salvato | **Dati salute parziali** |
| Crash e recovery al 30' | 90 min | 90 min | 1 salvato | Dati salute completi |
| Segmenti sovrapposti 0–30 e 20–50 | 90 min | 50 min (fusi) | — | mai 60 min |
| Modalità esterna / disattivata | 90 min | 0 min | 0 | Esterna / Nessun dato |

Il caso storico "5 min + 22 min su 90" non è più producibile in modo silenzioso:
con la nuova macchina a stati esiste **un solo segmento** salvo consenso
esplicito, e qualunque copertura sotto il 90% è etichettata *parziale* con i
minuti reali in chiaro.

---

## 9. Limitazioni residue

1. **Nessuna validazione su hardware.** Tutte le verifiche sono compilazioni e
   test automatici su host. Servono ancora: una partita reale ~90 min su Apple
   Watch, una con Allenamento Apple avviato a metà, e il riavvio forzato dell'app.
   I test Garmin Run No Evil compilano ma la loro **esecuzione richiede il
   simulatore Connect IQ interattivo**, non eseguito qui.
2. **Nessun tipo padel negli SDK.** Verificato sul `WatchOS26.5.sdk` locale:
   `HKWorkoutActivityType` non ha padel; `paddleSports` è documentato come
   *"Canoeing, Kayaking, Outrigger, Stand Up Paddle Board"*. Si usa `.tennis`.
   Stessa situazione su Health Services (`ExerciseType.TENNIS`; `PADDLING` è
   acquatico) e su Fitbit (`"tennis"`). Su Garmin resta
   `SPORT_TENNIS` + `SUB_SPORT_PADEL` quando il prodotto lo espone.
3. **`locationType` resta `.unknown`.** I campi da padel sono indoor o outdoor a
   seconda del club; dichiarare `.indoor` falserebbe le assunzioni del sistema.
4. **Modalità esterna: nessuna metrica live.** L'osservazione passiva (query
   `HKObserverQuery` su FC/calorie) è stata rimossa perché costosa in batteria e
   perché la sessione altrui non è leggibile in tempo reale in modo affidabile.
   I dati arrivano dopo la partita dall'import di Apple Health / Health Connect
   già presente lato iPhone.
5. **Fitbit: capacità nuova, permesso nuovo.** Prima Momentum su Fitbit non
   registrava nulla. Ora può farlo, e questo richiede il permesso
   `access_exercise`: va comunicato in fase di aggiornamento store. Il wrapper è
   difensivo (feature detection + permesso) e degrada a solo-scoring.
6. **Wear OS: ownership solo tramite stato persistito.** Il servizio e il view
   model condividono lo stato via `SharedPreferences`; non c'è un canale in-process.
   È sufficiente perché il servizio riverifica sempre con
   `getCurrentExerciseInfoAsync()` prima di avviare.
7. **Garmin: nessun evento "attività avviata".** Connect IQ non espone un evento
   in background per l'avvio di un'attività di terze parti, quindi il conflitto
   è rilevabile solo quando l'app è in primo piano (limite di piattaforma già
   documentato nel README Garmin).
8. **Warning preesistente non risolto:** `RallyMateSync.mc:221` — variabile
   locale `pending` non usata. È fuori ambito ma fa fallire `scripts/build.sh`,
   che tratta i warning come errori (la compilazione in sé riesce).

---

## 10. Riferimenti alla documentazione ufficiale

Fonti consultate. Per le API Apple la verifica finale è stata fatta sugli header
del **watchOS 26.5 SDK installato** (`HKWorkoutSession.h`, `HKDefines.h`,
`HKWorkout.h`, `HKLiveWorkoutBuilder.h`, `HKHealthStore.h`), che sono la fonte
autorevole su ciò che il build può effettivamente usare.

**Apple / HealthKit**
- `HKWorkoutSession` — https://developer.apple.com/documentation/healthkit/hkworkoutsession
- `HKWorkoutSessionState.ended` — https://developer.apple.com/documentation/healthkit/hkworkoutsessionstate/ended
- Running workout sessions — https://developer.apple.com/documentation/healthkit/running-workout-sessions
- `HKWorkoutActivityType` — https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype
- `HKError.Code` (`errorAnotherWorkoutSessionStarted`, `errorBackgroundWorkoutSessionNotAllowed`) — https://developer.apple.com/documentation/healthkit/hkerror/code
- `HKLiveWorkoutBuilder` — https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder
- `HKHealthStore.recoverActiveWorkoutSession(completion:)` — https://developer.apple.com/documentation/healthkit/hkhealthstore/recoveractiveworkoutsession(completion:)

Dagli header, i due fatti che governano il progetto:
- `workoutSession(_:didFailWithError:)` — *"this method is always called before
  workoutSession:didChangeToState:fromState:date:"*.
- `stopActivity` / `end` — *"Once a workout session is stopped, it cannot be
  reused to start a new workout session."*

**Google / Wear OS Health Services**
- Health Services on Wear OS — https://developer.android.com/health-and-fitness/guides/health-services
- `ExerciseClient` — https://developer.android.com/reference/androidx/health/services/client/ExerciseClient
- `ExerciseTrackedStatus` — https://developer.android.com/reference/androidx/health/services/client/data/ExerciseTrackedStatus
- `ExerciseType` — https://developer.android.com/reference/androidx/health/services/client/data/ExerciseType
- Ongoing Activity — https://developer.android.com/training/wearables/ongoing-activity

Costanti verificate direttamente nell'AAR `androidx.health:health-services-client:1.1.0-rc02`:
`TENNIS`, `TABLE_TENNIS`, `PADDLING`, `RACQUETBALL`, `SQUASH`, `BADMINTON` —
nessun padel; `ExerciseTrackedStatus`: `NO_EXERCISE_IN_PROGRESS`,
`OWNED_EXERCISE_IN_PROGRESS`, `OTHER_APP_IN_PROGRESS`, `UNKNOWN`.

**Garmin / Connect IQ**
- `Toybox.ActivityRecording` — https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityRecording.html
- `Toybox.Activity` (`timerState`) — https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity.html
- Core Topics · Recording activities — https://developer.garmin.com/connect-iq/core-topics/recording-sessions/

**Fitbit OS**
- Exercise API — https://dev.fitbit.com/build/reference/device-api/exercise/
- Permessi (`access_exercise`, `access_heart_rate`) — https://dev.fitbit.com/build/guides/permissions/

Il valore `access_exercise` è stato verificato nell'SDK installato
(`@fitbit/sdk` → `ProjectConfiguration.d.ts`).
