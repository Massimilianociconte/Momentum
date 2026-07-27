# Permessi Health Connect — Momentum

Dettaglio tecnico dei permessi Health Connect dichiarati e usati. Fonte: `apps/momentum/android/app/src/main/AndroidManifest.xml` + `HealthConnectBridge.kt` (audit 2026-07-26).

## Permessi dichiarati (tutti READ, nessun WRITE)

| Permesso manifest | Record | Uso nel codice | Scopo utente |
|---|---|---|---|
| `android.permission.health.READ_STEPS` | `StepsRecord` | Aggregato giornaliero, max 7 giorni | Carico di attività quotidiano |
| `android.permission.health.READ_ACTIVE_CALORIES_BURNED` | `ActiveCaloriesBurnedRecord` | Aggregato giornaliero | Dispendio energetico attivo |
| `android.permission.health.READ_HEART_RATE` | `HeartRateRecord` | Aggregati (medie/max) | Intensità sforzo nei match |
| `android.permission.health.READ_EXERCISE` | `ExerciseSessionRecord` | Elenco sessioni recenti | Riconoscere allenamenti/match |
| `android.permission.health.READ_HEART_RATE_VARIABILITY` | `HeartRateVariabilityRmssdRecord` | Aggregato | Indicatore recupero (readiness) |
| `android.permission.health.READ_SLEEP` | `SleepSessionRecord` | Durata sessioni sonno | Indicatore recupero |

Verifica di coerenza: 6 permessi dichiarati = 6 `HealthPermission.getReadPermission(...)` richiesti in `HealthConnectBridge.kt` (righe 41–49). Nessun permesso dichiarato e non usato, nessun permesso usato e non dichiarato.

## Vincoli implementativi (evidenza)

- **Sola lettura**: nessuna chiamata di scrittura verso Health Connect.
- **Solo aggregati**: le query usano l'API aggregate; nessun campione grezzo persistito.
- **Finestra massima 7 giorni**: hard-cap nel bridge nativo.
- **Nessuna trasmissione**: i valori restano nel client; l'assistente AI non li riceve (contesto minimizzato server-side); backup solo cifrato e opt-in (premium).
- **Degradazione**: se Health Connect è assente (`isProviderAvailable` false) o i permessi sono revocati, le sezioni insight si nascondono senza crash.

## Flusso rationale (obbligo policy — implementato durante l'audit)

1. Manifest: intent-filter `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE` su `MainActivity` + activity-alias `ViewPermissionUsageActivity` (`android.intent.action.VIEW_PERMISSION_USAGE`, protetta da `android.permission.START_VIEW_PERMISSION_USAGE`).
2. `MainActivity.kt`: `isHealthRationaleIntent()` intercetta entrambe le action in `configureFlutterEngine` (cold start) e `onNewIntent` (warm start) → `healthConnectBridge.onRationaleIntent()`.
3. `HealthConnectBridge.kt`: flag `pendingRationale` + push `showRationale` sul channel `com.rallymate/health_connect`; il Flutter side espone `rationaleRequests` stream e `consumeRationaleRequest()`.
4. `app.dart`: naviga a `/privacy` (schermata "Privacy e dati" con sezione SALUTE E FITNESS) rispettando l'onboarding.

Test manuale consigliato: da Health Connect → Momentum → "Informativa sulla privacy" deve aprire l'app sulla schermata Privacy e dati (sia ad app chiusa che aperta).

## Se in futuro si aggiungono permessi

1. Aggiungere il permesso al manifest E al set richiesto nel bridge.
2. Aggiornare: `privacy_screen.dart` (informativa), `health-app-declaration.md`, `data-safety-mapping.md`, privacy policy pubblicata, form Health apps in Console.
3. I permessi Health Connect "restricted" (es. background read) richiedono approvazione dedicata di Google.
