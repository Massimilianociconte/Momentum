# Padelandia Padel Knowledge Base

Ultimo aggiornamento: 2026-07-06

Questa knowledge base alimenta Rules Assistant Free, Pallino Assistant,
FAQ statiche, risposte smartwatch, training, confronti attrezzatura e futuri
contenuti coach/analytics. Ogni record deve restare collegato a una fonte:
nessuna regola o scheda tecnica va pubblicata senza URL e livello di
affidabilita.

## Stato implementato

- Migration: `backend/supabase/migrations/0007_padel_knowledge_base.sql`
- Seed iniziale: 18 fonti, 16 cluster, 24 topic, 8 FAQ Free, 8 regole
  strutturate, 3 court feature, 3 ball type, 5 racket type, 4 racket model,
  3 confronti racchette, 4 topic tecnici, 4 topic tattici, 6 training, 10
  citazioni assistant.
- Edge Function: `backend/supabase/functions/assistant/index.ts`
  carica `knowledge_topics`, `rule_faqs_v2`, fonti e tag; se le tabelle non
  sono ancora deployate degrada sulle FAQ legacy.
- Embedding: predisposto con tabella `knowledge_embeddings` senza imporre
  `pgvector`; in produzione si puo migrare a `vector` quando il progetto e'
  pronto.

## Mappa argomenti

| Area | Contenuti seed | Uso app |
|---|---|---|
| Regole ufficiali | servizio, let, palla in gioco, punto perso, risposta corretta, fuori campo | Free FAQ, Premium RAG, watch quick answer |
| Punteggio | game, golden point, formati base | match, watch, onboarding regole |
| Campo | dimensioni, rete, vetri, griglie, accessi, superfici, indoor/outdoor | FAQ, training, mappa e contenuti principianti |
| Palline | specifiche FIP, confronto con tennis, alta quota, comportamento indicativo | FAQ Free, consigli Premium |
| Racchette | specifiche regolamentari, forme, bilanciamento, materiali, modelli | confronti Premium, profilo attrezzatura |
| Tecnica | volee, lob, bandeja, vibora | training, post-match, analytics |
| Tattica e ruoli | lato destro, lato sinistro, comunicazione, punti decisivi | matchmaking, training, assistant |
| Training | routine volee, lob, bandeja, servizio, comunicazione, punti decisivi | sezione Training e piani personalizzati |

## Tassonomia cluster

| Cluster | Priorita MVP | Free | Premium | Watch | Fonte ufficiale richiesta |
|---|---:|---|---|---|---|
| `official_rules` | 1 | si | si | si | si |
| `scoring_formats` | 1 | si | si | si | si |
| `ambiguous_situations` | 1 | si | si | si | si |
| `court_surfaces` | 2 | si | si | si | si |
| `balls` | 2 | si | si | si | si per standard |
| `rackets` | 2 | si | si | si | solo per limiti regolamentari |
| `racket_materials` | 3 | no | si | no | no |
| `equipment_comparisons` | 3 | no | si | no | no |
| `technique` | 2 | si | si | si | no |
| `tactics` | 2 | si | si | si | no |
| `roles` | 2 | si | si | si | no |
| `training` | 2 | si | si | si | no |
| `beginner_advice` | 1 | si | si | si | no |
| `advanced_advice` | 4 | no | si | no | no |
| `smartwatch_faq` | 1 | si | si | si | si quando regola |
| `match_quick_faq` | 1 | si | si | si | si quando regola |

## Schema database

Tabelle sorgenti e tassonomia:

- `knowledge_sources`: URL, tipo fonte, affidabilita 1-5, access date,
  review cadence.
- `knowledge_versions`: snapshot versionato della KB.
- `knowledge_clusters`, `knowledge_tags`, `knowledge_topic_tags`: tassonomia.
- `knowledge_topics`: record principale con breve, esteso, watch summary,
  Free/Premium, rich blocks JSON sicuri, stato pubblicazione.
- `knowledge_topic_sources`: collegamento many-to-many tra topic e fonti.
- `assistant_citations`: citazioni/parafrasi tracciabili per risposte.

Tabelle verticali:

- `padel_rules`, `rule_faqs_v2`
- `court_features`, `ball_types`
- `equipment_categories`, `racket_types`, `racket_models`,
  `racket_comparisons`
- `technique_topics`, `tactical_topics`, `training_knowledge`
- `knowledge_embeddings`

RLS: tutte le tabelle hanno RLS attivo. Il client legge solo contenuti
pubblicati; non esistono policy client per scrittura. Le modifiche KB devono
passare da migration, SQL editor/admin o backend service role.

## Ranking fonti

Affidabilita 5:

- FIP Rules of Padel: https://www.padelfip.com/wp-content/uploads/2025/12/FIP_Rules-of-Padel.pdf
- FIP Documents: https://www.padelfip.com/documents/
- FIP Balls: https://www.padelfip.com/wp-content/uploads/2024/04/Balls.pdf
- FIP Game Ball Certification Process: https://www.padelfip.com/wp-content/uploads/2024/04/Game-Ball-Certification-Process.pdf

Affidabilita 4:

- LTA Padel Rules: https://www.ltapadel.org.uk/play/how-to-get-started-playing-padel/rules/
- LTA Padel FAQs: https://www.ltapadel.org.uk/play/padel-faqs/
- LTA Court Construction Guidance 2025: https://www.lta.org.uk/siteassets/padel/lta-padel-court-construction-guidance-note-2025.pdf
- LTA Beginner Skills: https://www.ltapadel.org.uk/play/how-to-get-started-playing-padel/skills-for-beginners/
- Pagine prodotto ufficiali Babolat, NOX, HEAD, Wilson per dati dei modelli.

Affidabilita 3:

- Wilson/Decathlon/HEAD guide editoriali su racchette e colpi.
- The Padel School per contenuti coach su ruoli e tecnica.

Regola: se una fonte coach/produttore contraddice FIP o una federazione per
una regola, vince sempre la fonte ufficiale.

## Free e Premium

Free:

- FAQ regolamento e punteggio.
- Risposte brevi validate.
- Regole principali.
- Palline base.
- Racchetta principianti in forma indicativa.
- Training base: volee, lob, servizio, comunicazione.
- Watch summaries.
- Nessuna chiamata LLM esterna.

Premium:

- RAG su tutta la KB.
- Risposte piu contestuali con distinzione tra regola, interpretazione tecnica
  e consiglio pratico.
- Confronti racchette deterministici.
- Training collegato ad analytics e ruolo.
- Punti decisivi, ruoli, attrezzatura e tecnica avanzata.
- Ricerca online controllata futura, solo con fonti tracciate.

## Formato risposta assistant

I topic usano blocchi JSON tipizzati in `answer_blocks`, ad esempio:

```json
[
  {"type": "title", "text": "Servizio"},
  {"type": "short_answer", "text": "Servi sotto mano dopo rimbalzo."},
  {"type": "attention", "text": "Rete piu box corretto: let."}
]
```

Il renderer deve accettare solo tipi noti: `title`, `short_answer`,
`step`, `tip`, `attention`, `example`, `source`, `cta`, `faq`.
Niente HTML libero. Markdown solo lato LLM e sanitizzato dalla UI.

## Esempi chatbot

Domanda Free: "Se il servizio tocca la rete si ripete?"

Risposta watch: "Nastro + box corretto = let: ripeti il servizio. Se non
entra nel box corretto e' fallo. Fonte: FIP."

Risposta mobile Premium: "Regola ufficiale: se il servizio tocca la rete ma
cade correttamente nel box e non genera fallo, si ripete. Consiglio pratico:
chiamate subito let e non continuate lo scambio in dubbio. Fonte: FIP."

Domanda Premium: "Meglio rotonda o diamante se sono principiante?"

Risposta: "Per iniziare, la KB favorisce racchetta rotonda/controllo: sweet
spot piu ampio, piu maneggevolezza e meno richiesta tecnica. La diamante e'
piu orientata potenza ma meno tollerante. Questo e' consiglio tecnico, non
regola ufficiale."

## Aggiornamento periodico

- FIP Rules: prima di ogni release importante e almeno annualmente.
- FIP Balls/approved balls: trimestralmente.
- Federazioni nazionali: trimestralmente.
- Produttori racchette: stagionale, per nuovi modelli.
- Coach/editoriali: annualmente o quando entrano nuovi programmi training.
- Ogni record nuovo deve avere `knowledge_topic_sources` e almeno un tag.

## Prossimi step

1. Applicare la migration su Supabase.
2. Deployare `assistant`.
3. Creare un job admin per calcolare embedding e popolare
   `knowledge_embeddings`.
4. Aggiungere pannello interno/admin per revisionare fonti, conflitti e stato
   `needs_review`.
5. Estendere dataset modelli racchette solo da pagine produttore ufficiali.
