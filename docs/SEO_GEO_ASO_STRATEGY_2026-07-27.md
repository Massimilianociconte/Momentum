# SEO, GEO e ASO — analisi e piano (27 luglio 2026)

Analisi della landing `playmomentum.it` e della scheda store, con le
ottimizzazioni applicate e quelle da fare. Ogni raccomandazione è legata a
una fonte ufficiale o a una SERP osservata, non a buone pratiche generiche.

## 0. Cosa non ho potuto misurare

Il connettore Ahrefs di questo workspace risponde `Insufficient plan` su
tutti gli endpoint keyword (volumi, difficoltà, CPC, SERP overview). **Non
esistono in questo documento volumi di ricerca stimati**: le priorità sono
costruite su SERP reali osservate il 27/07/2026 e sulla composizione dei
risultati, non su numeri che non ho potuto verificare.

L'unico dato Ahrefs disponibile è gratuito e vale la pena leggerlo:

> **playmomentum.it — Domain Rating 0**

Zero backlink di rilievo. È il vincolo che governa tutto il resto: sulle
query commerciali la concorrenza ha domini con anni di storia, quindi la
strategia realistica non è "posizionarsi su app padel" ma **occupare le
query informative dove il contenuto vale più del dominio**.

## 1. Stato reale dell'indicizzazione

`site:playmomentum.it` restituisce **una sola pagina**: la home. Sitemap,
robots e canonical sono corretti; il sito è semplicemente troppo giovane.

| Elemento | Stato |
|---|---|
| Sitemap | ✅ `/sitemap-index.xml`, 5 URL, priorità differenziate |
| robots.txt | ✅ include i crawler generativi, Content-Signal, sitemap |
| Canonical / hreflang | ✅ apex, `it-IT` + `x-default` |
| Schema | ✅ grafo `@graph` con Organization, WebSite, WebPage, MobileApplication, HowTo, FAQPage |
| IndexNow | ✅ già in `npm run deploy` |
| Header sicurezza | ✅ CSP, HSTS, nosniff |
| Pagine indicizzate | ❌ **1 su 5** |

Non c'è un problema tecnico da risolvere: c'è un problema di **superficie
di contenuto**. Cinque pagine non danno a Google motivi per tornare.

## 2. GEO: cosa dice davvero Google

Il sito investe su `llms.txt` e `llms-full.txt`. La guida ufficiale
[Optimizing your website for generative AI features](https://developers.google.com/search/docs/fundamentals/ai-optimization-guide)
è esplicita:

> "You don't need to create new machine readable files" like llms.txt files —
> "Google Search ignores them."

Gary Illyes e John Mueller lo hanno confermato più volte in pubblico. Google
aggiunge che **non serve scrivere in modo speciale per l'AI**, che non serve
spezzettare i contenuti e che `structured data isn't required for generative
AI search`. Ciò che conta:

1. la pagina deve essere **indicizzata e mostrabile con uno snippet**;
2. contenuto **crawlabile**, non dipendente da JS;
3. **valore unico**, non parafrasi di ciò che esiste già.

**Decisione presa.** `llms.txt` resta (altri assistenti possono usarlo, il
costo è nullo) ma **non è più trattato come leva di crescita**, e ora è
servito con `X-Robots-Tag: noindex` come Google consiglia, per non
alimentare l'indice con una pagina di testo duplicata.

La vera leva GEO coincide con la SEO fatta bene: risposta diretta nella
prima frase, titoli in forma di domanda, fonte citabile. È esattamente ciò
che fa la nuova pagina regolamento.

## 3. SERP osservate e dove si può vincere

### 3.1 «app per segnare punti padel» — query commerciale

Composizione della prima pagina: **schede store (Google Play, App Store) ai
posti 1, 6, 10**, poi siti di prodotto concorrenti (padel.watch,
padelscore.eu, padelem.com, padoo.app, referi.io) e un thread Reddit.

Due conseguenze operative:

- **L'ASO è SEO.** La scheda Play è essa stessa un documento indicizzato da
  Google. Il testo della scheda va scritto anche per la ricerca web, non
  solo per la ricerca interna allo store.
- Competere qui con un dominio DR 0 e senza app pubblicata è fuori
  portata nel breve. Questa query si conquista **dopo** la pubblicazione,
  attraverso la scheda store.

Concorrenti diretti identificati: Padel Watch, PADEL'EM, Padoo, Referi,
Padel Speaker, SetPoint, Padl, Tabellone segnapunti padel.

### 3.2 «punteggio padel come funziona» — query informativa

Occupata da blog di brand (Babolat, Wilson), media di settore
(padelmagazine.it, zonadepadel, giocopadel) e rivenditori
(tiendapadelpoint). **Nessuno cita il numero di regola. Nessuno dichiara
l'edizione del regolamento.**

### 3.3 «star point padel regolamento 2026» — la vera occasione

Occupata da notizie e social: padelnuestro, padelmagazine, mrpadelpaddle,
supertennis, Instagram, TikTok, un post LinkedIn della FIP. Sono **annunci**
della novità, non spiegazioni operative del funzionamento.

È la posizione migliore del progetto, per tre motivi che si sommano:

1. la regola è **nuova**, quindi nessuno ha ancora consolidato autorità;
2. il progetto ha un dataset di 36 voci **verificate sul PDF ufficiale** con
   numero di regola ed edizione;
3. l'app **implementa** lo Star Point — è l'unico caso in cui il contenuto
   e il prodotto dimostrano la stessa competenza.

## 4. Cosa ho applicato

### 4.1 Nuovo hub `/regole-padel/`

Pagina pilastro generata dal dataset di `rally_core`, non riscritta a mano:

- **36 regole** in 5 sezioni, ognuna con risposta diretta e **numero di
  regola** (es. «Regola 14.1(b)»);
- edizione e data di ultima verifica dichiarate in testa;
- `Article` con `citation` verso i PDF ufficiali FIP + `FAQPage` con 36
  coppie domanda/risposta, dove **la citazione entra nel testo della
  risposta strutturata**: un assistente che riusa il blocco si porta dietro
  il riferimento normativo;
- ancore stabili per ogni voce (`#walls_own_side`), indice sticky,
  `scroll-margin-top` perché il link diretto non finisca sotto l'indice;
- link interni verso home e guida introduttiva.

La fonte unica resta `packages/rally_core/lib/src/rules/rules_data.dart`:
`dart run tool/generate_web_rules.dart` rigenera il JSON del sito. Una
regola aggiunta al dataset senza sezione **fa fallire la generazione**,
così non può sparire in silenzio dalla pagina.

### 4.2 Architettura e link interni

- `/regole-padel/` in navigazione principale, in due blocchi del footer e
  in `llms.txt`;
- priorità sitemap 0.9 (sopra supporto e download);
- la sezione regole del centro supporto ora rimanda all'hub, per evitare
  che due pagine competano sulla stessa intenzione.

### 4.3 Blog: architettura riusabile

Tre aggiunte che valgono per ogni articolo futuro, non solo per quelli
scritti oggi:

- **campo `faq` nel frontmatter** → blocco domande in coda all'articolo
  **più schema `FAQPage`**. È la forma che i motori generativi estraggono
  meglio: domanda esplicita, risposta autoconclusiva che regge anche
  staccata dalla pagina;
- **articoli correlati** per categoria e tag, selezione deterministica
  (nessun random) così la struttura di link interni resta stabile fra le
  build. Un articolo senza link in uscita è un vicolo cieco per il crawler;
- link contestuali verso l'hub da home, blog e supporto: il pilastro deve
  accumulare autorità interna, non stare isolato in navigazione.

### 4.4 Primo articolo sulla query migliore

`/blog/star-point-padel/` — spiegazione operativa dello Star Point:
sequenza completa parità/vantaggi, game di esempio punto per punto, tabella
di confronto fra le tre opzioni della Regola 1, chi sceglie il lato e cosa
non si può fare, regola del doppio misto, 6 FAQ con schema.

La SERP su questa query contiene solo annunci: nessuno spiega **come si
gioca** lo Star Point. L'articolo linka le ancore dell'hub e viceversa.

### 4.5 GEO

- `llms.txt` e `llms-full.txt` serviti con `X-Robots-Tag: noindex`.

### 4.6 ASO — correzione di conformità

Le schede Play in italiano, inglese e spagnolo dichiaravano
«Supporto anche per Apple Watch, **Garmin e Fitbit**». Il sito pubblico
dichiara l'opposto: quelle integrazioni «non vengono promesse come
disponibili al lancio». Una scheda che promette una compatibilità assente
ricade nella policy **Misrepresentation** di Google Play, oltre a produrre
recensioni negative il giorno del lancio. Claim rimosso nelle tre lingue,
con nota che spiega a quale condizione può rientrare.

## 5. Cosa resta da fare, in ordine di ritorno

### Priorità 1 — contenuto sulle query dove si può vincere

Il blog ha **due articoli**, uno dei quali bozza. È il collo di bottiglia.
Piano editoriale derivato dalle SERP osservate, non da volumi stimati:

| Articolo | Query servita | Perché può posizionarsi |
|---|---|---|
| ~~Star Point: come funziona, esempi punto per punto~~ ✅ pubblicato | star point padel, nuove regole padel 2026 | SERP di sole notizie, nessuna spiegazione operativa |
| Golden point vs Star Point vs vantaggi | differenza golden point star point | confronto assente, il prodotto implementa tutti e tre |
| Cambio campo nel padel: quando si cambia davvero | cambio campo padel | errore diffuso (anche l'app lo aveva); risposta con Regola 5 alla mano |
| Le nuove regole FIP 2026 | regolamento padel 2026 | pagina di riferimento aggiornabile ogni edizione |
| Tie-break e super tie-break: tutti i formati | tie break padel | i formati alternativi (mini-set, TB a 7) non sono spiegati da nessuno |

Ogni articolo deve linkare l'ancora corrispondente dell'hub e viceversa.

**Non ho creato pagine di categoria o tag.** Con due articoli
genererebbero pagine sottili, che è un danno, non un guadagno. Vanno
introdotte quando il blog supera circa dieci articoli.

### Priorità 2 — backlink

DR 0 è il vero tetto. La pagina regolamento è l'unico asset linkabile del
sito: circoli, scuole padel e federazioni regionali linkano volentieri una
pagina di regolamento aggiornata e citabile. Questa è attività manuale, non
tecnica.

### Priorità 3 — al lancio dell'app

- Popolare `PUBLIC_APP_STORE_URL` e `PUBLIC_PLAY_STORE_URL`: fanno
  comparire `installUrl` e `sameAs` nello schema `MobileApplication` e
  collegano il sito alle schede store, che già posizionano da sole.
- ~~Aggiungere «star point» ai metadati store~~ ✅ **applicato**: entra nel
  campo keyword Apple in tutte e tre le lingue (al posto di «sport», troppo
  generico, e di «watch», che rischiava il richiamo al marchio Apple Watch)
  e nella descrizione completa Play, che Google indicizza.
- Aggiungere `sameAs` all'`Organization` con i profili social e le schede
  store **reali**: è il segnale con cui un assistente risolve l'entità
  «Momentum» e la distingue da omonimi. Oggi non esiste alcun profilo, e
  inventarne uno nello schema sarebbe una dichiarazione falsa.
- Verificare in Search Console il **report Generative AI performance**, che
  è l'unica misura attendibile della visibilità nelle risposte AI: i tool
  di terze parti che dichiarano metriche interne di Google non le hanno.

## 6. Riferimenti

- Google Search Central — [Optimizing your website for generative AI features](https://developers.google.com/search/docs/fundamentals/ai-optimization-guide)
- Apple — [Creating your product page](https://developer.apple.com/app-store/product-page/) (nome e sottotitolo 30 caratteri, keyword 100 caratteri separate da virgole senza spazi)
- Google Play Console Help — [Best practices for your store listing](https://support.google.com/googleplay/android-developer/answer/13393723) (titolo 30, descrizione breve 80, descrizione completa 4.000; vietati claim su classifiche, premi e prezzi)
- FIP — [Rules of Padel, revisione 01.01.2026](https://www.padelfip.com/wp-content/uploads/2025/12/FIP_Rules-of-Padel.pdf)
