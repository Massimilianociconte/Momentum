# Dichiarazione "Health apps" Play Console — Momentum

Bozza per il form Play Console → App content → Health apps (obbligatorio per chi usa Health Connect).

## 1. Categoria di app salute

- [x] Fitness e benessere (coaching/insight su recupero e prontezza sportiva)
- [ ] Dispositivo medico / servizi clinici — NO
- [ ] Ricerca sulla salute umana — NO

L'app NON è un dispositivo medico e non fornisce diagnosi: gli insight sono benessere/fitness. Nessun claim medico nel listing o in-app.

## 2. Health Connect

| Campo del form | Risposta |
|---|---|
| Usa Health Connect? | Sì |
| Tipi di dati letti | Steps, Active calories burned, Heart rate, Exercise sessions, Heart rate variability (RMSSD), Sleep sessions — **solo lettura** |
| Tipi di dati scritti | Nessuno |
| Finalità | Fitness and wellness: mostrare all'utente insight su carico, recupero e prontezza in relazione ai match di padel |
| I dati lasciano il dispositivo? | No per impostazione predefinita. Solo backup cifrato opzionale attivato esplicitamente dall'utente (premium) |
| Vendita/pubblicità con dati salute? | No, mai |
| Uso per ML/AI? | No: l'assistente AI non riceve dati salute (contesto minimizzato lato server) |

## 3. Requisiti policy Health Connect verificati nel codice

| Requisito | Evidenza |
|---|---|
| Permessi minimi | 6 permessi READ dichiarati nel manifest = 6 usati in `HealthConnectBridge.kt` |
| Solo aggregati, finestra limitata | Query aggregate, range massimo 7 giorni (`HealthConnectBridge.kt`) |
| Rationale accessibile | Intent-filter `ACTION_SHOW_PERMISSIONS_RATIONALE` + alias `ViewPermissionUsageActivity` gestiti in `MainActivity.kt` → schermata "Privacy e dati" (`/privacy`) |
| Informativa in-app | Sezione "SALUTE E FITNESS" in `privacy_screen.dart` descrive tipi di dati, scopo e revoca |
| Revoca | L'utente può revocare da Health Connect in qualsiasi momento; l'app degrada senza errori |

## 4. Testo per il campo "descrizione dell'uso" (EN)

```
Momentum reads aggregated fitness data from Health Connect (steps,
active calories, heart rate, exercise sessions, HRV, sleep) over the last
7 days at most, read-only, to show the user recovery and readiness
insights related to their padel matches. Data is processed on-device and
is never sold, never used for advertising, and never shared with third
parties. An optional end-to-end encrypted backup can be enabled
explicitly by the user. The in-app privacy screen ("Privacy e dati")
explains the data use and is also shown as the Health Connect permission
rationale.
```

## 5. Azioni manuali residue

- [ ] Compilare il form Health apps con i valori sopra.
- [ ] Se Google richiede la Health Connect self-certification aggiuntiva, allegare l'URL della privacy policy (sezione salute inclusa nella bozza `privacy-policy-draft.md`).
