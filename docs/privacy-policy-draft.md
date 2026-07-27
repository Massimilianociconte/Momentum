# Privacy policy — stato e azioni per la pubblicazione

**Il testo completo esiste già** e NON va duplicato qui:

- Italiano (prevalente): [`docs/legal/PRIVACY_POLICY.md`](legal/PRIVACY_POLICY.md) — v1.5, 21 luglio 2026
- Inglese: [`docs/legal/PRIVACY_POLICY_EN.md`](legal/PRIVACY_POLICY_EN.md) — v1.5

Entrambe coprono già: GDPR (artt. 13-14), principio local-first, dati cloud opzionali, Health Connect/HealthKit, RevenueCat, FCM, assistente AI, retention, diritti dell'interessato, cancellazione account.

## Gap da chiudere prima della submission (bloccanti per la policy URL)

- [ ] **Titolare del trattamento**: compilare i placeholder `[DA COMPLETARE]` in entrambe le versioni (nome/ragione sociale, sede, P.IVA/C.F.).
- [x] **Pagine web implementate** (audit 2026-07-26): `https://playmomentum.it/privacy/` (IT), `https://playmomentum.it/privacy-en/` (EN) e `https://playmomentum.it/termini/` renderizzano direttamente i markdown di `docs/legal/` (componente `LegalPage.astro`). Restano `noindex` e mostrano l'avviso bozza finché nei markdown ci sono placeholder; l'avviso sparisce da solo quando il titolare è compilato.
- [ ] **Deploy del sito** `apps/padelandia-web` sull'hosting di produzione (dominio `playmomentum.it`).
- [ ] Passare `RALLYMATE_PRIVACY_URL=https://playmomentum.it/privacy/` alla build (`tool/rallymate build-appbundle`) così l'app lo mostra in "Privacy e dati".
- [ ] Inserire lo stesso URL in Play Console → Store listing → Privacy policy e nel form Health apps.

## Verifiche di coerenza fatte nell'audit (2026-07-26)

| Affermazione in policy | Riscontro nel codice | Esito |
|---|---|---|
| Dati salute local-first, mai venduti/condivisi | HC read-only, aggregati, max 7 giorni; assistente senza dati salute | ✅ Coerente |
| Backup cloud opzionale cifrato (premium) | `premium_backup_v2` + RLS | ✅ Coerente |
| Cancellazione account in-app e via web | `auth_screen.dart` + edge function `delete-account` | ✅ Coerente |
| Notifiche solo opt-in | FCM auto-init disattivato, `POST_NOTIFICATIONS` runtime | ✅ Coerente |
| Nessuna pubblicità, nessun tracker | Nessun SDK ads/analytics nel client | ✅ Coerente |

Se in futuro cambia la raccolta dati (nuovi permessi, nuovi SDK), aggiornare **prima** la policy pubblicata e il Data Safety form, poi rilasciare l'app.
