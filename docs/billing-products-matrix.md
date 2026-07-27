# Matrice prodotti in-app — Momentum

Prodotti da configurare in Play Console → Monetizzazione → Abbonamenti e in RevenueCat. Gli ID sono **fissi nel codice** (RevenueCat offering/entitlement): non cambiarli senza aggiornare client e backend.

## Abbonamenti

| Product ID (Play) | Base plan | Entitlement RevenueCat | Piano app | Sblocca |
|---|---|---|---|---|
| `rallymate_plus_monthly` | mensile, rinnovo automatico | `plus` | Plus | Backup cloud, statistiche avanzate, quota assistente maggiorata |
| `rallymate_pro_monthly` | mensile, rinnovo automatico | `pro` | Pro | Tutto Plus + insight salute da provider cloud, funzioni premium wearable |
| `rallymate_coach_monthly` | mensile, rinnovo automatico | `coach` | Coach | Tutto Pro + area coach (atleti, gruppi allenamento) |

Prezzi: da definire in Console (multi-valuta automatica). Nessun prezzo hardcoded nel client (verificato: i prezzi arrivano da RevenueCat/Play).

## Flusso di verifica (audit 2026-07-26)

1. Client: `purchases_flutter` 9.x (Billing client 8.0.0 nel merged manifest) → acquisto via Google Play.
2. RevenueCat valida la ricevuta con Google e assegna l'entitlement.
3. Webhook `revenuecat-webhook` (Bearer secret + HMAC opzionale) → RPC `apply_revenuecat_plan_event` aggiorna il piano lato server con scadenza.
4. Gate server-side: `has_active_entitlement` (le feature premium cloud non si sbloccano dal solo client).
5. Bypass di test `RALLYMATE_TEST_PREMIUM`: neutralizzato nei build release (`!dart.vm.product`).

## Configurazione da fare in Console/RevenueCat

- [ ] Creare i 3 abbonamenti con gli ID esatti sopra (un base plan mensile ciascuno; ID base plan suggerito: `monthly`).
- [ ] Attivare gli abbonamenti in tutti i paesi target.
- [ ] RevenueCat: collegare service credentials Google + Real-time developer notifications (Pub/Sub).
- [ ] RevenueCat: verificare mapping prodotti → entitlement `plus`/`pro`/`coach` e offering di default.
- [ ] Impostare `REVENUECAT_ANDROID_KEY` (`goog_...`) nella build store e `REVENUECAT_WEBHOOK_SECRET` nei secrets Supabase.
- [ ] Test con license tester: acquisto, rinnovo (test clock), annullamento, restore su secondo device.

## Note policy

- Solo beni digitali → obbligo Play Billing rispettato (nessun pagamento alternativo nel client).
- I termini di rinnovo/annullamento devono comparire nella schermata Premium e nei ToS.
- Coach checkout via Stripe (edge function `coach-checkout`) riguarda **servizi del coach verso i suoi atleti** (beni/servizi fisici fuori app): la feature è attualmente disattivata fail-closed (`verifyReceipt()` = false) — vedi `known-risks.md`. Non pubblicizzarla nel listing finché non è attiva.
