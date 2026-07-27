# Flusso cancellazione account — Momentum

Documentazione del flusso richiesto dalla policy Google Play "Account deletion" (obbligatoria per app che consentono la creazione di account). Audit 2026-07-26.

## 1. Cancellazione in-app

Percorso: **Profilo → sezione account → "Elimina account"** (`auth_screen.dart`).

1. Primo dialogo di conferma con spiegazione delle conseguenze (perdita match cloud, squadre, abbonamenti da gestire su Google Play).
2. Secondo passaggio: l'utente deve digitare **"ELIMINA"** per confermare (protezione da tap accidentale).
3. Il client chiama la edge function `delete-account` con il JWT dell'utente.
4. Al successo: sessione locale invalidata, ritorno allo stato anonimo.

## 2. Cancellazione via web (URL per Play Console)

URL da dichiarare in Play Console → App content → Data deletion:

```
<SUPABASE_URL>/functions/v1/delete-account
```

- **GET**: pagina HTML con istruzioni (come cancellare in-app o via richiesta autenticata) — soddisfa il requisito "risorsa web scopribile".
- **POST** (con Bearer JWT utente): esegue la cancellazione effettiva.

## 3. Cosa viene cancellato (lato server, edge function `delete-account`)

| Dato | Azione |
|---|---|
| Utente Supabase Auth | Eliminato (admin API) |
| Profilo, match, statistiche, social (team, gruppi, amicizie) | Eliminati via cascade/cleanup |
| Avatar in storage | Eliminati |
| Token push (`push_devices`) | Eliminati |
| Integrazioni health provider (Fitbit/Google/Garmin) | Revocate ed eliminate |
| Backup premium | Eliminati |
| Messaggi assistente | Eliminati/anonimizzati secondo retention |

I dati residui transienti sono coperti dai retention job (`20260713031500_transient_data_retention.sql`, `20260715133000_push_notification_retention.sql`).

## 4. Abbonamenti

La cancellazione dell'account **non** annulla l'abbonamento Google Play (è gestito da Google). Il dialogo in-app avvisa l'utente di annullare l'abbonamento da Play Store → Abbonamenti. RevenueCat smette di associare l'entitlement all'utente eliminato.

## 5. Dichiarazioni Play Console

- [ ] Data deletion → "Fornisci un URL": inserire l'URL sopra (con il dominio Supabase di produzione).
- [ ] Spuntare anche "gli utenti possono eliminare l'account dall'app".
- [ ] In Data Safety, marcare tutti i dati come cancellabili.

## 6. Test di verifica pre-submission

1. Creare account di prova → popolare match/avatar → eliminare in-app → verificare che login fallisca e i dati siano assenti da DB/storage.
2. GET dell'URL da browser anonimo → la pagina istruzioni deve rispondere 200 senza autenticazione.
