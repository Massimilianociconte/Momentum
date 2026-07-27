# Momentum — Pausa e ripresa cross-device · Report tecnico

**Data:** 2026-07-25
**Ambito:** iPhone (Flutter + bridge nativo), Apple Watch, Wear OS
**Correlato:** `WORKOUT_SESSION_OWNERSHIP_REMEDIATION_2026-07-25.md` (proprietà
unica della sessione allenamento; qui se ne usa la state machine per i segmenti)

---

## 1. Causa precisa del problema

Una partita sospesa su iPhone **non arrivava mai al Watch**. Tre difetti
concatenati.

### 1.1 L'evento di pausa non veniva mai inviato

`WatchSyncService.sendMatchLifecycle()` esisteva ma **non era chiamato da
nessuna parte** (dead code). Il controller live usava un proprio
`MethodChannel` grezzo:

```dart
// prima — live_match_controller.dart
static const _watchChannel = MethodChannel('com.rallymate/watch');
Future<void> _hintCompanionLifecycle(String action) async {
  await _watchChannel.invokeMethod<bool>('matchLifecycle', {
    'matchId': arg, 'action': action,           // ← solo id e azione
  });
}
```

### 1.2 Il Watch non conosceva quel path

`PhoneSync.handle()` su watchOS instradava `context`,
`workout_detection_preferences`, `ping`, `test_point` e `start_match`. Il path
`/rallymate/lifecycle` **cadeva nel `guard` finale** e veniva scartato con
`ok: false`. Anche se fosse arrivato, il payload non conteneva né formato né
journal: il Watch non avrebbe potuto ricostruire il 4–1.

### 1.3 Nessun concetto di "partita riprendibile"

Il Watch conosceva solo `activeMatchId` (una) e `lastIncompleteMatchId` (una,
solo locale). Non esisteva un elenco di partite `PAUSED`, né uno stato
sincronizzato, né una versione con cui risolvere i conflitti.

### 1.4 Difetti aggiuntivi trovati durante il lavoro (corretti)

| # | Difetto | Effetto |
|---|---|---|
| a | `updateApplicationContext` era chiamato con payload diversi da tre punti del bridge | WatchConnectivity mantiene **un solo** application context: ogni chiamata cancellava la precedente (le preferenze workout cancellavano l'ultimo `startMatch`) |
| b | `LocalMatchStore.saveMatch()` scriveva sempre `active_match_id` | ricevere l'aggiornamento di un'**altra** partita dirottava la partita attiva sul Watch |
| c | il Watch non leggeva mai `session.receivedApplicationContext` all'attivazione | uno snapshot consegnato mentre l'app era chiusa non veniva applicato al riavvio |
| d | i segmenti salute non venivano persistiti se `resetToHome()` correva prima della fine asincrona del workout | il segmento chiuso spariva dal riepilogo |
| e | nessun limite di dimensione sul payload durabile | un journal lungo avrebbe fatto fallire la consegna in silenzio |

---

## 2. File modificati

### iPhone (Flutter + nativo)

| File | Modifica |
|---|---|
| `lib/services/watch_sync.dart` | `publishResumableMatches()`, `sendMatchLifecycle()` con journal/format/versione/chiave di idempotenza, `_summaryFor()`; ripubblicazione all'avvio, alla riconnessione e dopo il merge di eventi dal Watch |
| `lib/features/live/live_match_controller.dart` | pausa/ripresa/completamento passano dal servizio reale invece del MethodChannel grezzo |
| `lib/data/repositories/repositories.dart` | `resumableMatches()` — query delle partite `IN_PROGRESS` + `PAUSED` |
| `ios/Runner/Watch/RallyMateWatchBridge.swift` | `publishResumableMatches` (application context), lifecycle durabile con journal, **envelope** del context, limite 24 kB sul journal durabile |
| `android/app/src/main/kotlin/.../MainActivity.kt` | `publishResumableMatches` (Data Item), lifecycle durabile (Data Item + messaggio live), stesso limite |

### Apple Watch

| File | Modifica |
|---|---|
| `ResumableMatch.swift` | **nuovo** — `WatchMatchStatus`, `WatchResumableMatch`, `WatchResumableSnapshot` con le regole di merge |
| `PhoneSync.swift` | path `resumable`/`lifecycle`/`context_bundle`, `WatchSyncDecoding`, lettura di `receivedApplicationContext` all'attivazione |
| `LocalMatchStore.swift` | snapshot persistente, versione per partita, chiavi di idempotenza, `knownMatchIds()`, `saveJournal()` che non tocca la partita attiva |
| `WatchMatchViewModel.swift` | `resumableMatches`, `applyResumableSnapshot`, `applyMatchLifecycle`, `resumeMatch(_:recordingMode:)`, `publishLocalStatus`, `localSummary` |
| `WatchViews.swift` | elenco partite da riprendere in home, schermata di conferma con scelta registrazione, banner "già terminata altrove" |
| `WorkoutRecordingPolicy.swift` | `WatchWorkoutSegment` ora ha `segmentId`, `provider`, `externalId` |
| `WorkoutSessionManager.swift` | metadato `HKMetadataKeyWorkoutBrandName`, cattura dell'UUID del workout salvato |

### Wear OS

| File | Modifica |
|---|---|
| `ResumableMatch.kt` | **nuovo** — stesso modello e stesse regole di merge in Kotlin |
| `PhoneSync.kt` (`SyncPaths`, `LocalMatchStore`) | path `RESUMABLE`/`LIFECYCLE`, snapshot, versione, idempotenza, `saveJournal()` |
| `PhoneListenerService.kt` | gestione Data Item `resumable` e `lifecycle` (+ messaggio live), broadcast alla UI |
| `MatchViewModel.kt` | elenco riprendibili, `resumeMatch`, `publishLocalStatus`, `localSummary` |
| `MainActivity.kt` | elenco in home con punteggio e data, messaggio di blocco |

### Test

`WatchResumableSyncTests.swift` (**nuovo**, 12 test) · `ResumableMatchTest.kt`
(**nuovo**, 8 test).

---

## 3. Modifiche al modello dati

`MatchStatus` (`CREATED`/`IN_PROGRESS`/`PAUSED`/`COMPLETED`/`ABANDONED`) era già
persistito nella tabella `matches` del telefono: **non serviva alcuna
migrazione**. Il modello mancante era quello condiviso con i wearable.

```
WatchResumableMatch / WearResumableMatch
  matchId, status, stateVersion, updatedAtMs, pausedAtMs,
  teamLabel, scoreLine, setsLabel, gamesLabel, format,
  sourceDevice, eventCount, journalAvailable

WatchResumableSnapshot / WearResumableSnapshot
  stateVersion, lastUpdatedAtMs, activeMatchId, matches[]
```

**`stateVersion` = numero di eventi nel journal.** Ogni dispositivo ricava lo
stesso numero dagli stessi eventi: nessun confronto di orologi tra device, e la
versione cresce in modo monotono a ogni punto, undo, pausa o ripresa.

Segmento salute (esteso):

```
WatchWorkoutSegment
  segmentId (UUID)   ← nuovo
  provider           ← nuovo ("APPLE_HEALTHKIT")
  externalId         ← nuovo (UUID del workout HealthKit)
  startedAt, endedAt, saved, endReason
```

Una partita RallyMate resta **una sola partita** anche se attraversa più
giorni; ogni ripresa apre un **nuovo segmento** con il proprio id. La copertura
è calcolata unendo i segmenti (mai sommandoli due volte).

---

## 4. Modifiche WatchConnectivity / Data Layer

Tre canali con ruoli distinti, come documentato da Apple.

| Canale | API iOS | API Wear OS | Contenuto |
|---|---|---|---|
| **Stato più recente** | `updateApplicationContext` | Data Item `/rallymate/resumable` | snapshot delle partite riprendibili (`activeMatch`, `pausedMatches`, `stateVersion`, `lastUpdatedAt`) |
| **Eventi affidabili** | `transferUserInfo` | Data Item `/rallymate/lifecycle` + messaggio | `MATCH_CREATED/PAUSED/RESUMED/COMPLETED/SCORE_EDITED` **con il journal completo** |
| **Immediato** | `sendMessage` | `MessageClient` | solo quando l'altro dispositivo è raggiungibile; il fallimento non perde nulla perché la copia durabile è già in coda |

**Envelope del context.** WatchConnectivity mantiene un solo application
context per sessione. Il bridge ora accumula i payload per chiave
(`startMatch`, `resumable`, `context`, `workoutDetectionPreferences`) e
ritrasmette l'intero envelope `/rallymate/context_bundle`; il Watch lo apre e
smista ogni payload. Prima ogni nuovo context cancellava il precedente.

**Limite di dimensione.** Un journal oltre 24 kB **non viene troncato** (un
journal parziale ricostruirebbe un punteggio sbagliato): viene omesso, il
payload porta `journalTruncated`, e il Watch lo richiede con `requestState`
quando il telefono è raggiungibile.

---

## 5. Strategia di riconciliazione

Regole deterministiche, identiche su watchOS e Wear OS, verificate dai test:

1. **Un evento è applicato una sola volta.** Gli `eventId` sono UUID; il merge
   dei journal è per id. I payload lifecycle hanno una `idempotencyKey`; se
   manca, se ne deriva una stabile (`matchId#action#stateVersion`). Le chiavi
   applicate sono persistite (ultime 64).
2. **`COMPLETED`/`ABANDONED` prevalgono** su `PAUSED` e `IN_PROGRESS`, sempre,
   anche con versione più bassa.
3. **Una versione più recente non viene mai sovrascritta da una precedente.**
4. **A parità di versione** vince la voce aggiornata più di recente.
5. **Il punteggio si ricostruisce dagli eventi**, mai da un campo cached: il
   replay è la fonte di verità su tutte le piattaforme.
6. **Il Watch diventa autorevole offline.** Riprende, continua a segnare e
   accoda; alla riconnessione il telefono fa merge idempotente, ricalcola lo
   stato e **ripubblica lo snapshot**, così i due dispositivi convergono.
7. **Se la partita è già chiusa altrove**, la ripresa è rifiutata con
   *"Questa partita è già stata terminata su un altro dispositivo."*
8. **Se il journal non è ancora arrivato**, la ripresa è rifiutata con un
   messaggio esplicito e il Watch lo richiede — non riparte mai da 0–0.

---

## 6. Gestione dei segmenti salute

Alla ripresa il Watch **richiede di nuovo** il proprietario della
registrazione, con tre opzioni (Momentum / app esterna / nessuna). Ogni
sessione apre un segmento distinto: la ripresa passa `userInitiated: true` alla
state machine, che è l'unico modo di uscire da uno stato terminale.

```
Match RallyMate mt_aw_1c9…
├── Segmento 4f1e… : 25 lug 19:02 → 19:47 · APPLE_HEALTHKIT · salvato · HK 9C2A…
└── Segmento b73a… : 26 lug 18:10 → 19:00 · APPLE_HEALTHKIT · salvato · HK 51DE…
```

Il riepilogo aggrega i segmenti unendo gli intervalli sovrapposti, quindi non
esiste doppio conteggio; una copertura sotto il 90% resta etichettata
**parziale** con i minuti reali.

---

## 7. Metadati HealthKit utilizzati

```swift
configuration.activityType = .tennis        // nessun tipo padel negli SDK
configuration.locationType  = .unknown

try? await builder.addMetadata([
    HKMetadataKeyWorkoutBrandName: "Momentum",
])
```

- **`.tennis`**: nessun tipo padel esiste in `HKWorkoutActivityType`
  (verificato sugli header del watchOS 26.5 SDK). `.other` non è più usato.
- **`HKMetadataKeyWorkoutBrandName = "Momentum"`**: il tipo atteso è
  `NSString`, ed è aggiunto al builder prima della finalizzazione.
- **`HKMetadataKeyIndoorWorkout`: non impostato.** I campi da padel sono
  indoor o outdoor a seconda del club e l'app non lo sa: dichiararlo sarebbe
  un'informazione inventata. Va aggiunto solo se in futuro l'utente lo indica.
- **`CFBundleDisplayName`**: già `Momentum` sia su
  `wear/watchos/MomentumWatchApp/Info.plist` sia su `ios/Runner/Info.plist`
  (verificato, nessuna modifica necessaria). HealthKit associa la sorgente al
  nome localizzato dell'app.
- L'UUID del workout salvato viene catturato in `externalId` sul segmento.

---

## 8. Screenshot dell'app Fitness

**Non disponibili.** Non ho un Apple Watch né un iPhone reali collegati a questa
sessione, e l'app Fitness non è ispezionabile dal simulatore in modo
rappresentativo. Serve una verifica manuale su hardware, da fare così:

1. partita reale con `RALLYMATE_MANAGED`;
2. Salute → Sfoglia → Attività → l'allenamento, e Fitness → Attività;
3. annotare **come** il sistema presenta tipo, brand e sorgente.

Il risultato realistico, come indicato nel prompt, è una riga tipo
`Tennis` con `Sorgente: Momentum`, oppure una presentazione che usa il
workout brand. **L'app non può forzare il titolo**: la resa finale è decisa
dal sistema. Nessuna promessa diversa è stata scritta nella UI.

---

## 9. Test effettuati

| Suite | Comando | Esito |
|---|---|---|
| Apple Watch | `swift test` | **83 test, 0 failure** (erano 71) |
| iPhone + Watch app | `xcodebuild -scheme Runner -destination 'generic/platform=iOS Simulator'` | **BUILD SUCCEEDED** |
| Flutter | `flutter test` | **139 test, 0 failure** |
| Flutter | `flutter analyze` | **No issues found** |
| Android | `flutter build apk --debug` | **APK costruito** |
| Wear OS | `./gradlew testDebugUnitTest assembleDebug` | **52 test, 0 failure** (erano 44) |

Copertura della matrice richiesta:

| Test obbligatorio | Copertura |
|---|---|
| Partita sospesa su iPhone e ripresa da Apple Watch | `testMatchPausedOnPhoneAppearsAndResumesOnWatch` (verifica 4–1, formato, `MATCH_RESUMED`) |
| Partita sospesa sul Watch e ripresa da iPhone | `testWatchOwnedPauseIsListedWithoutAnyPhoneContact` + `reconcileFromEventLog` lato telefono |
| Ripresa senza connessione | `testMatchPausedOnPhoneAppearsAndResumesOnWatch` (sync offline, coda pendente > 0) |
| Più partite sospese | `testSeveralPausedMatchesAreAllOfferedAndTheRightOneResumes` |
| Partita già completata altrove | `testResumeIsRefusedWhenTheMatchWasCompletedElsewhere`, `completed always wins over paused` |
| Eventi pendenti durante il riavvio del Watch | `testWatchOwnedPauseIsListedWithoutAnyPhoneContact`, `testOfflineFinishSurvivesRelaunchAndRemainsQueued` |
| App mobile chiusa / WatchConnectivity non raggiungibile | canale durabile + `testResumeIsRefusedWhenTheJournalNeverArrived` |
| Modifica simultanea su telefono e Watch | `testStaleLifecycleNeverOverwritesNewerLocalState`, `testHigherStateVersionWinsAndOlderNeverOverwrites` |
| Ripresa in una giornata successiva | `testResumeInALaterSessionOpensANewHealthSegment` |
| Nuova sessione HealthKit sullo stesso match | idem (2 segmenti, id distinti, provider valorizzato) |
| Workout salvato come `.tennis` | configurazione verificata sugli header SDK; **da confermare su hardware** |
| Metadato brand `"Momentum"` | `addMetadata` presente e compilato; **da confermare su hardware** |
| Visualizzazione reale nell'app Fitness | **non eseguibile qui** (vedi §8) |
| Funzionamento equivalente su Wear OS | `ResumableMatchTest` (8 test) + UI e listener allineati |

---

## 10. Limitazioni residue

1. **Nessuna verifica su hardware.** Tutto è compilazione e test automatici.
   Restano da provare su dispositivi reali: la consegna effettiva di
   `transferUserInfo` con app sospesa, la resa in Fitness, e la ripresa in una
   giornata successiva.
2. **Journal oltre 24 kB.** In quel caso la ripresa offline non è possibile: il
   Watch mostra "non ancora sincronizzata" finché il telefono non è
   raggiungibile. Una soluzione completa richiederebbe uno snapshot compatto
   dello stato invece del journal integrale.
3. **Il conflitto irrisolvibile non ha ancora una UI di revisione sul telefono.**
   Le regole deterministiche coprono i casi previsti e nessun evento viene mai
   cancellato, ma la schermata di revisione manuale richiesta al punto 5 del
   prompt non è stata realizzata.
4. **Garmin e Fitbit non ricevono ancora lo snapshot.** Il modello di dominio è
   pronto e condiviso, ma i due trasporti (Connect IQ / companion Fitbit) non
   sono stati estesi in questo intervento.
5. **`stateVersion` = lunghezza del journal** presuppone che gli eventi non
   vengano mai eliminati. È coerente con il modello event-sourced attuale
   (l'undo è un evento aggiuntivo), ma va tenuto presente se in futuro si
   introducesse una compattazione.
6. **La ripubblicazione dello snapshot rilegge e rigioca fino a 12 journal.**
   Con molte partite aperte e log lunghi l'operazione è misurabile sull'isolate
   principale; oggi è limitata a 12 righe.
7. **Warning preesistente non risolto:** `RallyMateSync.mc:221` (variabile
   locale inutilizzata) continua a far fallire `scripts/build.sh` di Garmin, che
   tratta i warning come errori.

---

## 11. Riferimenti alla documentazione ufficiale

- Transferring data with Watch Connectivity — https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity
- `WCSession.updateApplicationContext(_:)` — https://developer.apple.com/documentation/watchconnectivity/wcsession/updateapplicationcontext(_:)
- `WCSession.transferUserInfo(_:)` — https://developer.apple.com/documentation/watchconnectivity/wcsession/transferuserinfo(_:)
- `WCSession.receivedApplicationContext` — https://developer.apple.com/documentation/watchconnectivity/wcsession/receivedapplicationcontext
- `HKMetadataKeyWorkoutBrandName` — https://developer.apple.com/documentation/healthkit/hkmetadatakeyworkoutbrandname
- `HKWorkoutActivityType` — https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype
- `HKWorkoutBuilder.addMetadata(_:)` — https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/addmetadata(_:)
- Wear OS Data Layer API — https://developer.android.com/training/wearables/data/data-layer
- `DataClient` / Data Items — https://developer.android.com/training/wearables/data/data-items
- `MessageClient` — https://developer.android.com/training/wearables/data/messages
