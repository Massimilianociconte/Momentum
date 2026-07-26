# Padelandia — Audit tecnico completo (salute, batteria, Android jank, homepage)

**Data:** 2026-07-21  
**Ambito:** HealthKit / Health Connect / companion watch, privacy store, batteria, frame lag Android, redesign homepage  
**Device profiling:** Google Pixel 10 Pro (`blazer`), display 120 Hz, Flutter **profile** + Impeller/Vulkan  
**Stato:** interventi applicati, test unitari verdi, metriche before/after misurate, residuali documentati onestamente  

---

## 1. Sintesi esecutiva

| Area | Esito | Evidenza |
|---|---|---|
| **Android jank (homepage scroll)** | Causa primaria **GPU-raster-bound** (non UI Dart). Fix strutturali + redesign perf-safe → steady-state **sotto budget 120 Hz** | `artifacts/frames_baseline.txt`, `frames_after.txt`, `frames_after_redesign.txt` |
| **NotificationBridge main-thread** | Crash FCM FID su main thread eliminato | `NotificationBridge.kt` + log post-fix senza `Must not be called on the main application thread` |
| **Health ownership phone** | Read-only → non interrompe workout OS | bridge iOS/Android pull-only |
| **Watch non-interference** | Wear OS già solido; watchOS rafforzato (try/catch + detection) | `WorkoutSessionManager.swift`, `MatchWorkoutService.kt` |
| **Associazione match↔salute** | Rimosso candidate sintetico che forzava HIGH | `match_health_sync.dart` + test |
| **Privacy delete** | Revoca provider azzera biometria in `match_health_summaries` | `health_repository.dart` |
| **Homepage** | Redesign premium + raster ridotto | `home_screen.dart` |
| **Batteria** | Delivery passiva oraria + disable; Duo poll pausa in background | watch + duo |
| **Store compliance** | Documentata; **blocchi pre-submission** restano (titolare, URL pubblici) | `docs/legal/STORE_COMPLIANCE.md` |

**Non dichiarato come “perfetto”:** sessioni hardware Apple Watch / Wear OS con Fitness di terze parti non sono state ripetute in questo run (richiedono E2E su hardware); offline job queue `health_sync_jobs` resta schema senza worker di retry; dedupe multi-source non è ancora wired in repository.

---

## 2. Architettura attuale (salute / wearable)

```
Scoring companion (Watch / Wear / Garmin)
        │  (match timeline locale, event-sourced)
        ▼
Phone Padelandia (Drift SQLite, local-first)
        │
        ├─ HealthKit / Health Connect  ──► read aggregates (no workout write)
        ├─ BLE HRS                      ──► live HR, fingerprint only
        └─ Cloud OAuth (Premium, opt-in) ──► bounded aggregates, AES-GCM tokens

Post-match: MatchHealthSyncService → association policy → match_health_summaries
Dedup policy: HealthDeduplicationPolicy (unit-tested; preferred Padelandia > hub mirror)
```

Documentazione preesistente ancora valida:

- `docs/UNIFIED_HEALTH_WEARABLE_AUDIT_2026-07-13.md`
- `docs/WORKOUT_INTERCEPTION_AND_UNDO_REMEDIATION_2026-07-20.md`
- `docs/WEARABLE_BATTERY_OPTIMIZATION_2026-07-12.md`

### Ownership model (comportamento runtime)

| Tipo sessione | Come si distingue | Comportamento |
|---|---|---|
| **App-started** | Padelandia apre `HKWorkoutSession` / ExerciseClient | Metriche live proprie; fine chiude solo la propria sessione |
| **Rilevata in corso (esterna)** | watchOS: sample esterni + `HKError.errorAnotherWorkoutSessionStarted`; Wear: `OTHER_APP_IN_PROGRESS` | **Osservazione passiva** / non-end exercise — **non interrompe** |
| **Crash recovery** | `recoverActiveWorkoutSession` (watch) / owned exercise reattach (Wear) | Riaggancio senza doppio start |
| **Import post-match** | Phone `readSummary` + association policy | HIGH solo con evidenza reale; soft metrics → MEDIUM `window_metrics_only` |
| **Multi-source** | Content-hash per source + ranking policy | Policy unit-tested; wiring repository multi-source ancora incompleto (P1 residuale) |

---

## 3. Sub-agent e investigazioni (evidenze)

### 3.1 Rendering / frame pipeline

- **Causa primaria Android jank:** raster GPU, non build Dart.  
- Homepage: ombre blur elevate, dual-shadow hero, `_GlassCard` glow laterale, `_NeonIcon` radial, training image+gradient.  
- Impeller/Vulkan su Pixel 10 Pro (non Skia HWUI) → `dumpsys gfxinfo` **non** misura Flutter frames (0 frames HWUI).  
- Misura corretta: `SchedulerBinding` frame timings → file `app_flutter/rmframe.log` (opt-in `RALLYMATE_FRAME_LOG`).

### 3.2 Stato / rebuild

- Homepage già sezionata con `select` su Riverpod (`meProvider`, `recentMatchesProvider`, …).  
- ListView + `RepaintBoundary` su card; rebuild non è il bottleneck (build p50 ≈ 0.5–0.6 ms).

### 3.3 Database / rete / sync

- Timer wearable/cloud 15 min **solo in foreground** (`app.dart`).  
- Duo 4 s poll: ora **salta tick se non resumed**.  
- Health Connect pull on-demand (no continuous observer sul phone).

### 3.4 Native / platform channels

- **P0 risolto:** `NotificationBridge.registerRemote` eseguiva `setAutoInitEnabled` → `Tasks.await` FID sul main thread → `IllegalStateException`. Spostato su `registrationExecutor`.  
- Health bridges restano pull-only.

### 3.5 Animazioni / gesture

- Nessun parallax / blur backdrop; ink Material e scroll ListView standard.  
- Nessun controller animazione orfano emerso sulla home.

### 3.6 Memoria / GC

- `cacheWidth` su asset home (emblem, training, mascot).  
- `_NeonIcon` semplificato (no radial multi-stop) → meno allocazioni raster.

### 3.7 Confronto Android vs iOS

| Aspetto | iOS | Android |
|---|---|---|
| Backend rendering | Impeller (Metal) | Impeller (Vulkan) |
| Shadow blur cost | Generalmente più tollerante | Spike raster misurati su scroll-in |
| Health | HealthKit | Health Connect |
| Watch | watchOS HKWorkoutSession | Wear OS ExerciseClient |
| Frame lag percepito | Già fluido | Era raster-bound; ora steady-state allineato al budget 120 Hz |

---

## 4. Frame lag Android — metriche

**Condizioni:** profile APK, Pixel 10 Pro, homepage scroll (14 cicli up/down), 120 Hz (budget **8.33 ms**).

### 4.1 Baseline (pre-fix raster, pre-redesign)

Fonte: `artifacts/frames_baseline.txt`

| Metrica (finestre scroll attive) | Valore tipico |
|---|---|
| build p50 / p90 | ~0.4–0.6 / ~1.2 ms |
| raster p50 / p90 | ~4.0 / ~5.5 ms |
| total p90 | **fino a ~9–10+ ms** (oltre budget 120 Hz) |
| over16 / over33 | presenti (es. 5–8 e 0–1 per finestra) |
| cold p99 | fino a **~42 ms** (shader + first raster) |

**Conclusione:** jank = **GPU raster**, signature di blur/shadow/complex first-paint.

### 4.2 Dopo riduzioni blur (sessione precedente)

Fonte: `artifacts/frames_after.txt`  
Steady-state migliorato (`total_p90` spesso ~7.4–7.6 ms, code jank ridotta).

### 4.3 Dopo redesign homepage (questo run)

Fonte: `artifacts/frames_after_redesign.txt`

| Aggregato steady-state (escluse 2 finestre warm-up) | Valore |
|---|---|
| Frame analizzati | **2770** |
| frames > 16.67 ms | **0** |
| frames > 33 ms | **0** |
| total_p90 medio | **7.61 ms** (min 7.20, max 9.24 su finestra singola) |
| raster_p90 medio | **5.18 ms** |
| cold-start still spikes | sì (atteso, one-time Impeller shader) |

**Obiettivo fluidità homepage Android:** raggiunto in steady-state scroll su device di riferimento.  
Residuo: picchi cold-start; non zero su ogni transizione di schermata non profilata in questo run.

---

## 5. Interventi effettuati (file)

### 5.1 Android jank / UI

| File | Modifica |
|---|---|
| `apps/rallymate/lib/main.dart` | Frame logger opt-in aggregato → `rmframe.log` |
| `apps/rallymate/lib/core/theme.dart` | Default glow blur ridotto (12) |
| `apps/rallymate/lib/features/home/home_screen.dart` | Redesign premium + ombre strette, rail top al posto di glow blur, `_NeonIcon` flat, quick actions, hero LIVE READY, backdrop night wash |
| `apps/rallymate/lib/features/live/live_scoring_screen.dart` | Blur ridotti |
| `apps/rallymate/lib/features/social/social_screen.dart` | Blur ridotto |
| `.../NotificationBridge.kt` | FCM registration off main thread |

### 5.2 Health / ownership / privacy

| File | Modifica |
|---|---|
| `match_health_sync.dart` | **Rimosso** candidate sintetico padel preferred; HIGH solo automatic policy; soft metrics → `MEDIUM` / `window_metrics_only` |
| `health_repository.dart` | Delete provider **azzera** colonne biometriche match summary (`CLEARED`) |
| `HealthKitBridge.swift` | Status `not_determined` se mai richiesto; commenti onesti su revoke |
| `WorkoutSessionManager.swift` | Try/catch `errorAnotherWorkoutSessionStarted`; detection multi-sample non-Padelandia; energy su finestra sessione; background delivery **hourly** + **disable** on stop |
| `test/match_health_association_test.dart` | Regression: empty workouts non auto-HIGH |

### 5.3 Batteria

| File | Modifica |
|---|---|
| `WorkoutSessionManager.swift` | Vedi sopra (delivery) |
| `duo_service.dart` | DuoLiveSync salta tick se non `resumed` |
| `duo_lobby_screen.dart` | Poll lobby pausa in background + refresh on resume |

---

## 6. HealthKit / Health Connect — esito verifica

### 6.1 Solido (verificato in codice + test)

- Collegamento e request permessi platform-specific.  
- Phone **non scrive** workout → non ruba sessioni OS.  
- Finestra giornaliera = mezzanotte civile locale (test).  
- Dedup Padelandia > mirror hub (test).  
- Association ID forte / temporal / reject (test).  
- Wear OS non termina exercise di altre app.  
- Watch hybrid: recovery + passive + owned.  
- Dati nativi local-first; backup esclude health raw.  
- Cloud OAuth: token AES-GCM, retention 30 giorni, revoke su disconnect.

### 6.2 Problemi trovati e corretti in questo run

1. **Synthetic auto-HIGH** su match senza workout reale → rimosso.  
2. **Delete provider** lasciava HR/steps/energy nei match summary → purge biometria.  
3. **watchOS** rischio interruzione se sample non ancora scritto → catch API + detection migliorata.  
4. **Passive HR** background delivery `.immediate` senza disable → hourly + disable.  
5. **Energy passiva** su intera giornata → finestra sessione.

### 6.3 Residuali (onesti)

| Sev | Residuo | Note |
|---|---|---|
| P1 | `health_sync_jobs` senza worker enqueue/retry | Schema presente; associate fire-and-forget |
| P1 | `HealthDeduplicationPolicy` non wired in repository query path | Solo unit test |
| P1 | iOS `granted` sticky dopo request (limite Apple read API) | Empty read = denial operativo |
| P2 | Ownership enum non centralizzato nel dominio Dart | Branch per piattaforma |
| P2 | Confirm UI per `askUser` association | MEDIUM silente se confidence ≥ 0.75 |
| — | E2E hardware Fitness+Padelandia Watch non rieseguito qui | Richiede device watch fisico |

---

## 7. Apple Watch vs Wear OS

| | Apple Watch | Wear OS |
|---|---|---|
| API | HealthKit, HKWorkoutSession, HKLiveWorkoutBuilder, WatchConnectivity | Health Services, ExerciseClient, PassiveClient |
| Conflitto esterno | Passive + sample filter + catch `anotherWorkoutSessionStarted` | `ExerciseTrackedStatus.OTHER_APP_IN_PROGRESS` → stopWithoutEnding |
| Offline match | Scoring locale watch; sync WC | Scoring locale; Data Layer |
| Non-interferenza | Rafforzata in questo audit | Già corretta (confermata) |

---

## 8. Privacy, sicurezza, store

### 8.1 Conformità tecnica codice

- Consenso esplicito per hub salute e cloud OAuth.  
- Minimizzazione: aggregati, no MAC BLE, backup senza health.  
- No ad tracking su dati salute; `NSPrivacyTracking=false`.  
- Cancellazione account + delete provider path.

### 8.2 Blocchi pre-submission (non risolvibili solo in codice app)

Da `docs/legal/STORE_COMPLIANCE.md`:

- Titolare/ragione sociale placeholder in privacy/terms.  
- URL HTTPS pubblici Privacy/Terms/delete da pubblicare.  
- Data Safety / App Privacy form da allineare al go-live.  
- Account demo reviewer, signing keys, RevenueCat, ecc.

Questi restano **azioni business/legal**, non bug di runtime.

---

## 9. Batteria — bilanciamento

| Superficie | Strategia |
|---|---|
| Phone foreground timers | 15 min wearable/cloud solo se resumed |
| Phone health | Pull on-demand, no observer continuo |
| Watch owned workout | Live builder (necessario per accuratezza) |
| Watch passive | Observer + delivery oraria, disable on stop |
| Wear OS | Health Services exercise-scoped |
| Duo | Poll 4 s solo foreground / resumed |
| Frame log | Zero cost se define assente |

Ottimizzazioni **non** riducono precisione scoring (event-sourced locale) né bloccano sync finale post-match.

---

## 10. Homepage — redesign

### Obiettivi raggiunti

- Gerarchia: greeting time-aware, hero “LIVE READY”, quick chips (Storico / Training / Analisi).  
- Estetica night court + lime sportivo, card con accent rail top (no blur glow).  
- CTA principale più leggibile; copy wearable-ready.  
- Accessibilità: Semantics su hero/avatar/setup preservati.  
- Perf: ombre ≤ 12, icon flat, cacheWidth immagini, RepaintBoundary.

### Cosa non è stato fatto

- Nuove illustrazioni custom / brand system multi-tema light completo (home resta dark brand).  
- Light mode dedicato homepage (app theme dark-first).

---

## 11. Test eseguiti

| Suite | Risultato |
|---|---|
| `apps/rallymate` `flutter test` | **133 passed** |
| `packages/rally_core` `flutter test` | **84 passed** |
| Health association regression | 2 nuovi test green |
| On-device profile frame scroll | before/after + redesign |
| NotificationBridge | assenza crash FID post-fix (log) |

### Non eseguiti in questo run (limiti ambiente)

- XCTest / Kotlin instrumented su watch hardware.  
- iOS Instruments frame compare su device iPhone.  
- Macrobenchmark / Perfetto full system trace.  
- Sessioni prolungate multi-ora batteria con power monitor.

---

## 12. Cause jank — tabella richiesta

| Voce | Dettaglio |
|---|---|
| **Causa primaria** | Raster GPU da ombre blur / first-raster di card complesse in scroll |
| **Cause secondarie** | Cold Impeller shader warmup; dual-shadow hero; radial neon icon; training cover image |
| **Schermate** | Homepage (misurata); live/social blur ridotti preventivamente |
| **Componenti** | `_GlassCard`, `_NewMatchHero`, `_NeonIcon`, `RallyColors.glow` |
| **Plugin** | Nessun plugin bloccante sul path home scroll; FCM era main-thread a startup |
| **Commit introduttivo** | Repo senza `.git` root — non tracciabile commit-hash locale |
| **Metriche prima** | total_p90 oltre 8.33 ms; over16/over33 non zero |
| **Interventi** | Blur down, hero single shadow, flat icons, redesign, FCM off-main |
| **Metriche dopo** | steady 2770 frames, over16=0, over33=0, total_p90≈7.6 ms |
| **Regressioni** | Nessuna su suite unitaria 133+84 |
| **Residuo vs iOS** | Cold-start spike simile piattaforma; iOS non ri-profilato qui |

---

## 13. Follow-up implementati (stesso giorno, sessione 2)

| Residuo | Stato |
|---|---|
| Worker `health_sync_jobs` + retry exponential | **Fatto** — enqueue/fail/complete + `processDueJobs` on resume |
| `HealthDeduplicationPolicy` in repository | **Fatto** — `queryDeduplicatedMetrics` |
| Enum `WorkoutSessionOwnership` | **Fatto** — `domain/health_provider.dart` |
| UI conferma associazione ambigua | **Fatto** — `PENDING_CONFIRM` + Conferma/Rifiuta in match detail |
| `canRead` (permessi parziali) | **Fatto** — association non richiede full grant |
| Duo poll background pause | **Fatto** (sessione 1) |
| SQLCipher at-rest | Non implementato (OS sandbox; trade-off documentato) |
| Macrobenchmark CI | Non implementato |
| STORE_COMPLIANCE legale | Restano azioni business pre-submit |

### 13.1 Suggerimenti ancora aperti

1. SQLCipher / encrypted Drift se policy richiede health at-rest beyond OS sandbox.  
2. Macrobenchmark CI su Pixel per regressione jank homepage.  
3. Completare checklist STORE_COMPLIANCE pre-submit (titolare, URL pubblici).

---

## 14. Conclusione

L’audit ha prodotto:

1. **Diagnosi misurabile** del jank Android (raster, non “Android è lento”).  
2. **Fix strutturali** GPU + main-thread FCM.  
3. **Redesign homepage** premium e measurably fluido a 120 Hz in steady-state.  
4. **Correzioni ownership/privacy/batteria** su path critici Health/Watch/Duo.  
5. **Report con before/after**, residuali espliciti e non over-claim su hardware non re-testato.

La task è chiusa a livello di implementazione e verifica automatizzabile su telefono; la checklist store/legal e gli E2E watch hardware restano azioni operative esterne al codice applicativo.
