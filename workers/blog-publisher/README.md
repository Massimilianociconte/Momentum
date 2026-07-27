# Momentum Blog Publisher

Worker Cloudflare che fa da ponte tra un GPT personalizzato di ChatGPT e il
blog Astro di [playmomentum.it](https://playmomentum.it), e che ospita il
pannello admin del blog su [admin.playmomentum.it](https://admin.playmomentum.it).

```text
GPT privato (ChatGPT, anche da smartphone)
   │  Bearer CHATGPT_ACTION_TOKEN
   ▼
momentum-blog-publisher (questo Worker)
   │  GITHUB_TOKEN (secret, mai visto da ChatGPT)
   ▼
GitHub Contents API → commit in apps/momentum-web/src/content/blog/
   │  push su main
   ▼
GitHub Actions (deploy-web.yml) → astro build → wrangler deploy
   ▼
Articolo online (solo se draft: false)
```

Il GPT conosce **solo** `CHATGPT_ACTION_TOKEN`. Il token GitHub resta un
secret del Worker.

## Endpoint

| Metodo | Path                | Effetto                                                        |
| ------ | ------------------- | -------------------------------------------------------------- |
| POST   | `/articles/drafts`  | Crea un nuovo articolo con `draft: true` (409 se lo slug esiste) |
| POST   | `/articles/publish` | Cambia `draft: true` in `draft: false` (richiede `confirmPublish: true`) |
| GET    | `/health`           | Verifica autenticazione e disponibilità                         |

Tutti gli endpoint richiedono `Authorization: Bearer <CHATGPT_ACTION_TOKEN>`.

## Pannello admin (admin.playmomentum.it)

Mini-CMS personale servito dagli static assets del Worker (`admin/`):
lista articoli, editor WYSIWYG (Toast UI), upload immagini con incolla,
toggle pubblica/bozza, eliminazione. Ogni azione è un commit GitHub, quindi
riusa la stessa pipeline di deploy del GPT.

- **Login**: password unica (`ADMIN_PASSWORD`), cookie di sessione firmato
  HMAC con `SESSION_SECRET` (HttpOnly, Secure, SameSite=Strict, 30 giorni).
- **API** sotto `/api/*` (login, articles CRUD, images, publish toggle);
  `GET /blog/*` fa da proxy delle immagini da GitHub così l'editor le
  mostra subito, prima del deploy del sito.
- **Immagini**: incollate o trascinate nell'editor → commit in
  `apps/momentum-web/public/blog/<slug>/` → inserite come
  `/blog/<slug>/<file>` (jpg, png, webp, max 8 MB).

Secret aggiuntivi del pannello:

```bash
npx wrangler secret put ADMIN_PASSWORD   # la password che userai per entrare
openssl rand -hex 32
npx wrangler secret put SESSION_SECRET   # chiave di firma dei cookie
```

## Setup

### 1. Configura owner e repository

In `wrangler.jsonc` sostituisci i placeholder di `GITHUB_OWNER` e
`GITHUB_REPO` con l'owner e il nome reali del repository GitHub.

### 2. Crea il fine-grained PAT GitHub

Su GitHub: Settings → Developer settings → Personal access tokens →
Fine-grained tokens. Requisiti:

- accesso **solo** a questo repository;
- permesso **Contents: Read and write**;
- nessun altro permesso.

Poi salvalo come secret del Worker:

```bash
cd workers/blog-publisher
npx wrangler secret put GITHUB_TOKEN
```

### 3. Genera il token per ChatGPT

```bash
openssl rand -hex 32
npx wrangler secret put CHATGPT_ACTION_TOKEN
```

Conserva il valore: andrà anche nel campo API Key del GPT.

### 4. Test locale

```bash
cp .dev.vars.example .dev.vars   # poi inserisci i valori reali
npm install
npm run dev
```

```bash
curl -X POST http://localhost:8787/articles/drafts \
  -H "Authorization: Bearer token-locale-di-prova" \
  -H "Content-Type: application/json" \
  --data '{
    "title": "Come funziona il punteggio nel padel",
    "description": "Guida completa e semplice al punteggio del padel.",
    "bodyMarkdown": "## Il punteggio base\n\nNel padel il punteggio segue...",
    "category": "Regolamento",
    "tags": ["padel", "regolamento", "punteggio"]
  }'
```

Nota: anche in locale il Worker scrive davvero su GitHub se `GITHUB_TOKEN`
è un PAT valido. Con un token finto le chiamate falliscono con 500 dopo il
log `github_write_failed` (utile per provare solo auth e validazione).

### 5. Deploy

```bash
npm run deploy
```

L'URL sarà simile a `https://momentum-blog-publisher.<account>.workers.dev`.
Verifica:

```bash
curl https://momentum-blog-publisher.<account>.workers.dev/health \
  -H "Authorization: Bearer IL-TOKEN-CHATGPT"
```

Il workflow `.github/workflows/deploy-web.yml` rideploya il Worker a ogni
push su `main` che tocca `workers/blog-publisher/` (servono i secrets GitHub
`CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID`).

## Configurare il GPT personalizzato

Su chatgpt.com: Esplora GPT → Crea → Configura → Azioni → Crea nuova azione.

1. Autenticazione: **API Key**, tipo **Bearer**, valore `CHATGPT_ACTION_TOKEN`
   (mai il token GitHub).
2. Schema: incolla `openapi.yaml` sostituendo l'URL in `servers` con quello
   reale del Worker.
3. Istruzioni del GPT:

```text
Sei l'editor ufficiale del blog Momentum (playmomentum.it), dedicato a
padel, punteggio, smartwatch, statistiche e allenamento.

Quando l'utente richiede un articolo:

1. Produci titolo, seoTitle, meta description, categoria, tag e contenuto Markdown in italiano.
2. Non inserire frontmatter YAML nel bodyMarkdown.
3. Non inserire un H1 nel corpo: il titolo è già mostrato dal layout Astro.
4. Usa H2 e H3 con gerarchia coerente.
5. Prima chiama sempre createArticleDraft.
6. Non chiamare mai publishArticle senza una conferma esplicita dell'utente.
7. Frasi come "scrivi", "prepara" o "crea" non sono conferme di pubblicazione.
8. Pubblica solamente quando l'utente dice esplicitamente "pubblica ora", "mettilo online" o una formula equivalente inequivocabile.
9. Dopo ogni operazione restituisci lo slug, il percorso GitHub e il collegamento al commit.
10. Non modificare o eliminare altri file del repository.

Qualità dei contenuti (SEO + GEO):

11. Ogni articolo deve essere estremamente valido: accurato, verificabile, con esperienza e competenza reali (E-E-A-T), mai contenuto generico di riempimento.
12. Ottimizza per la ricerca tradizionale (SEO) e per i motori generativi come Google AI Search, ChatGPT e Perplexity (GEO): apri ogni sezione con la risposta diretta alla domanda implicita (answer-first), poi approfondisci.
13. Scegli una keyword principale e usala nel titolo, nello slug, nella meta description e in almeno un H2; integra keyword correlate in modo naturale, senza keyword stuffing.
14. La meta description deve avere massimo 160 caratteri, contenere la keyword principale e invogliare al clic.
15. Formula gli H2 come domande reali degli utenti quando ha senso e chiudi l'articolo con una sezione FAQ (3-5 domande brevi con risposte dirette): è il formato più citato dai motori generativi.
16. Usa elenchi puntati, tabelle e dati concreti (numeri, regole ufficiali, esempi pratici): i contenuti strutturati e citabili vengono ripresi più spesso nelle risposte AI.
17. Dove pertinente, suggerisci collegamenti interni ad altre pagine del sito (es. /blog/, /supporto/, /download/) e cita fonti autorevoli.

Immagini:

18. Quando arricchiscono davvero l'articolo, genera immagini (copertina ed eventuali illustrazioni delle sezioni chiave): stile pulito e moderno, coerente con il brand Momentum (sport, padel, dati), senza testo sovrapposto e senza loghi di terzi.
19. Le immagini generate non possono essere caricate automaticamente nel repository: mostrale all'utente in chat e digli di salvarle e incollarle nell'articolo tramite il pannello admin (admin.playmomentum.it), che le carica come /blog/<slug>/<file>.
20. Compila featuredImage solo con un path o URL stabile confermato dall'utente (es. /blog/<slug>/copertina.jpg) e fornisci sempre un featuredImageAlt descrittivo con la keyword principale; se l'immagine non è ancora stata caricata, lascia featuredImage vuoto e segnalalo all'utente.
```

## Flusso operativo

1. «Crea un articolo sulle cinque statistiche più utili nel padel» → il GPT
   chiama `createArticleDraft` → commit con `draft: true` → il sito viene
   ricostruito ma l'articolo resta invisibile.
2. Controlli la bozza (file su GitHub o `npm run dev` del sito).
3. «Ho controllato, pubblicalo ora» → il GPT chiama `publishArticle` con
   `confirmPublish: true` → `draft: false` → nuovo commit → l'articolo va
   online su `/blog/<slug>/`.

## Note di sicurezza

- Confronto token in tempo costante (`crypto.subtle.timingSafeEqual`).
- Il Worker scrive solo dentro `BLOG_CONTENT_DIR`: lo slug è normalizzato
  (`[a-z0-9-]`, max 100 caratteri) e il path è encodato, quindi non sono
  possibili path traversal o modifiche ad altri file.
- Le bozze non sovrascrivono mai file esistenti (409 su slug duplicato);
  la pubblicazione usa lo SHA corrente del file per evitare race.
- Body limitato a 200 KB; errori interni non rivelano dettagli al client.
