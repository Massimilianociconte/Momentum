# Momentum web

Landing mobile-first, hub supporto e base editoriale SEO/GEO di Momentum.
È un progetto Astro statico separato dal runtime Flutter.

## Avvio locale

```bash
npm install
npm run assets:optimize
npm run dev
```

## Build

```bash
npm run build
```

Il dominio canonico di default è `https://playmomentum.it`. Per una build di
staging si può copiare `.env.example` in `.env` e sovrascrivere
`PUBLIC_SITE_URL`. Le URL store vengono accettate solo se HTTPS e appartenenti
a `apps.apple.com` o `play.google.com`; in loro assenza la UI mostra
correttamente “In arrivo” senza creare link fittizi. Senza recapito di supporto
il form non viene mostrato e le pagine legali incomplete restano protette.

## Deploy

- Base directory: `apps/padelandia-web`
- Build command: `npm ci && npm run assets:optimize && npm run build`
- Publish directory: `dist`

Le pagine privacy e termini sono deliberatamente `noindex` finché i documenti
legali in `docs/legal` non vengono completati con titolare, indirizzo e dominio.

## SEO, dati strutturati e contenuti AI

Canonical, Open Graph, sitemap, breadcrumb e JSON-LD condividono lo stesso
origin. Il nodo `MobileApplication` non inventa prezzo, offerte, rating o
recensioni: finché i listing non sono pubblici viene usato come metadata
semantico, non come promessa di rich result Google.

Le FAQ e il file `llms.txt` restano utili come contenuto strutturato e formato
portabile per sistemi che li consumano. Non sono descritti come scorciatoie di
ranking: Google richiede soprattutto pagine indicizzabili, contenuto utile,
testo visibile, fonti coerenti e una buona esperienza di pagina.

## Immagini e performance

Hero e tableau prodotto usano art direction reale: sorgenti generate
separatamente per desktop e mobile, trasformate in AVIF/WebP responsive durante
la build. La hero è eager con priorità alta; tableau e Pallino sono lazy.
Testare PageSpeed sul build pubblicato, non sul server `astro dev`, che include
toolbar e moduli HMR estranei alla produzione.

Sul provider di hosting impostare `Cache-Control: public, max-age=31536000,
immutable` per `/_astro/*`, mantenendo invece l’HTML con cache breve e
revalidation.
