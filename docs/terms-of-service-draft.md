# Termini di servizio — stato e azioni per la pubblicazione

**Il testo completo esiste già** e NON va duplicato qui:

- [`docs/legal/TERMS_OF_SERVICE.md`](legal/TERMS_OF_SERVICE.md)

## Gap da chiudere prima della submission

- [ ] Compilare eventuali placeholder (titolare/fornitore del servizio, foro competente) nel testo esistente.
- [x] **Pagina web implementata** (audit 2026-07-26): `https://playmomentum.it/termini/` renderizza `docs/legal/TERMS_OF_SERVICE.md` (componente `LegalPage.astro`). Resta `noindex` con avviso bozza finché nel markdown ci sono placeholder.
- [ ] **Deploy del sito** `apps/padelandia-web` in produzione.
- [ ] Passare `RALLYMATE_TERMS_URL=https://playmomentum.it/termini/` alla build store, così l'app lo mostra accanto alla privacy policy.
- [ ] Valutare una versione inglese se il listing EN viene pubblicato (consigliato, non obbligatorio per Play).

## Clausole minime verificate come presenti/da verificare

| Clausola | Necessaria perché | Stato |
|---|---|---|
| Abbonamenti: rinnovo automatico, gestione/annullamento via Google Play | Play Billing policy (trasparenza sottoscrizioni) | Verificare testo esistente |
| Nessun claim medico; insight salute a solo scopo informativo | Coerenza con dichiarazione Health apps | Verificare testo esistente |
| Regole UGC: contenuti vietati, segnalazione, sospensione account | Policy UGC di Google Play | Verificare testo esistente |
| Assistente AI: risposte informative, possibili errori, no consulenza professionale | Policy AI-generated content | Verificare testo esistente |
| Limitazioni di responsabilità e legge applicabile | Standard | Verificare testo esistente |

Se una clausola manca nel testo esistente, aggiungerla in `docs/legal/TERMS_OF_SERVICE.md` prima della pubblicazione.
