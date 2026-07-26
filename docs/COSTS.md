# Strategia costi e margini (PRD 9.4 + obiettivo: "deve costarmi pochissimo")

## Principio

Il costo marginale di un utente **free deve essere ≈ 0€**: tutto locale
(scoring, storico, analytics, FAQ, card, allenamenti base). Si paga
infrastruttura solo per chi paga l'abbonamento.

## Costi fissi mensili stimati (fino a ~10k utenti)

| Voce | Piano | Costo/mese |
|---|---|---|
| Supabase | Free tier → Pro quando serve | 0€ → 25$ |
| Edge functions (recap/assistant/checkout) | incluse Supabase | 0€ |
| Cloudflare R2 (immagini card) | pay-per-use, 10GB free | ~0€ |
| RevenueCat | free < 2.5k$ MRR | 0€ |
| Apple Developer + Play Console | | 99$/anno + 25$ una tantum |
| **Totale avvio** | | **< 15€/mese** |

## Costo marginale per utente PAGANTE

| Voce | Stima |
|---|---|
| Backup Plus (snapshot jsonb, 1 riga/device) | ~centesimi/anno |
| Recap pubblici (HTML 8KB + cache CDN 24h) | trascurabile |
| Duo Mode (Plus+): polling 4s ×2 telefoni solo a schermo live aperto, ~200 righe `duo_events`/partita, niente realtime | trascurabile |
| Assistant Pro: 20 domande/g × ~30% utilizzo reale | vedi sotto |

### Assistant Pro (l'unica voce che può sfuggire) — contromisure attive

1. Solo piani Pro/Coach (8,99€+) → il ricavo copre il costo per design.
2. **Cache condivisa 30gg** sull'hash della domanda: le domande da
   regolamento sono ripetitive → hit rate atteso alto, costo zero.
3. **FAQ-first**: knowledge base iniettata con prompt caching Anthropic
   (input KB riusato, non ripagato pieno a ogni chiamata).
4. **Routing modelli**: Haiku (~5-10× più economico) per regole; Sonnet
   solo per tattica/post-partita.
5. **Limiti hard**: 20/giorno, 5 live/partita → worst case per utente Pro
   ≈ 600 domande/mese; realistico (cache+uso reale) **0,30–1,50€/mese**
   contro 8,99€ di ricavo → margine > 80% anche nel caso pessimo.
6. Telemetria `cost_estimate_microusd` per accorgersi subito delle derive.

## Ricavi

| Fonte | Prezzo | Netto post-store (~15-30%) |
|---|---|---|
| Plus | 4,99€/m | ~3,50–4,25€ |
| Pro | 8,99€/m | ~6,30–7,65€ |
| Coach | 14,99€/m | ~10,50–12,75€ |
| Commissione pacchetti coach | 15% digitali / 10% 1:1 | es. 49€ → 7,35€ |

La commissione coach è legata a valore reale (assegnazione schede,
tracking, report, badge, protezione pagamento — PRD I4): il coach che
vende fuori app perde le funzioni, non viene "punito".

## Regole d'oro per mantenere il margine

1. Mai LLM nel free tier (la FAQ locale copre il 90% delle domande).
2. Mai video/AI video nell'MVP (PRD 6.2).
3. Backup = snapshot compresso, non sync riga-per-riga.
4. Immagini card compresse lato client prima dell'upload.
5. Ogni nuova feature cloud risponde prima alla domanda: "chi la paga?"
