# Deploy di playmomentum.it su Cloudflare (piano Free)

Guida operativa per pubblicare `apps/padelandia-web` (Astro, sito statico) su
**Cloudflare Workers static assets** — gratuito, CDN globale, TLS automatico —
con il dominio `playmomentum.it` acquistato su Aruba.

## Architettura

- **Build**: `astro build` → `dist/` (HTML statico, zero server).
- **Hosting**: Worker "assets-only" (`wrangler.jsonc` in `apps/padelandia-web`):
  nessun codice server, solo asset statici serviti dalla CDN.
- **Header di sicurezza**: `public/_headers` (HSTS, CSP, nosniff, ecc.).
- **Redirect**: `public/_redirects` (www → apex 301).
- **404**: `dist/404.html` generata da Astro (`not_found_handling: 404-page`).

Il piano Free di Workers include 100.000 richieste/giorno; le richieste di
soli asset statici sono **gratuite e illimitate** (non contano nel limite).

## 1. Collegare il dominio Aruba a Cloudflare (una tantum)

Se hai già aggiunto `playmomentum.it` come zona nel dashboard Cloudflare,
salta al punto 4.

1. Dashboard Cloudflare → **Add a domain** → `playmomentum.it` → piano
   **Free**. Cloudflare mostra due nameserver dedicati (es.
   `ana.ns.cloudflare.com` e `bob.ns.cloudflare.com`).
2. Pannello Aruba (admin.aruba.it) → **Domini** → `playmomentum.it` →
   **Gestione DNS e Nameserver** → **Modifica nameserver** → scegli
   "Nameserver personalizzati" e inserisci i due nameserver indicati da
   Cloudflare. NON serve mantenere la "Gestione DNS" di Aruba.
3. Attendi la propagazione (da pochi minuti a 24 h; Aruba di norma < 2 h).
   La zona su Cloudflare passa a stato **Active** e arriva un'email di
   conferma.
4. Verifica: `dig NS playmomentum.it +short` deve restituire i nameserver
   Cloudflare.

> Nota: non creare manualmente record A/CNAME per il sito. I "custom domain"
> del Worker (già dichiarati in `wrangler.jsonc`) creano da soli i record DNS
> e il certificato TLS per `playmomentum.it` e `www.playmomentum.it`.

## 2. Autenticazione Wrangler (una tantum)

```bash
cd apps/padelandia-web
npm ci                 # installa anche wrangler (devDependency)
npx wrangler login     # apre il browser, autorizza l'account Cloudflare
npx wrangler whoami    # verifica account e permessi
```

## 3. Configurare l'email di supporto della build

Le pagine legali diventano indicizzabili e il modulo contatti si attiva solo
con l'email di supporto valorizzata:

```bash
cp .env.example .env
# imposta PUBLIC_SUPPORT_EMAIL=webnovis.info@gmail.com (o la casella scelta)
```

## 4. Deploy

```bash
cd apps/padelandia-web
npm run deploy         # = build + validazione + wrangler deploy
```

Il primo deploy chiede conferma per creare i custom domain
`playmomentum.it` e `www.playmomentum.it`: conferma e Cloudflare provvede a
DNS + certificato. Da quel momento il sito è live su
**https://playmomentum.it** (e https://www.playmomentum.it fa 301 sull'apex).

Verifiche post-deploy:

```bash
curl -sI https://playmomentum.it/ | head -20        # 200 + header sicurezza
curl -sI https://www.playmomentum.it/supporto/      # 301 -> apex
curl -s  https://playmomentum.it/robots.txt          # sitemap corretta
```

Pagine da controllare a mano: `/`, `/supporto/`, `/download/`, `/privacy/`,
`/termini/`, `/cookie/`, `/elimina-account/`, `/404` (URL inesistente).

> Gli APK preview linkati da `/download/` NON stanno nel sito (limite 25 MiB
> per asset di Workers): vivono su GitHub Releases del repo pubblico
> `Massimilianociconte/Momentum-releases`; `releases/latest/download/…`
> punta sempre all'ultima versione pubblicata.

## 5. Aggiornamenti successivi

Ogni modifica al sito si pubblica con lo stesso comando:

```bash
cd apps/padelandia-web && npm run deploy
```

`npm run deploy:dry` esegue una prova senza pubblicare. I rollback si fanno
dal dashboard: Workers & Pages → playmomentum-web → Deployments → Rollback.

## 6. Impostazioni consigliate nel dashboard (facoltative)

- **SSL/TLS → Overview**: modalità **Full (strict)** (default corretto per
  Workers).
- **SSL/TLS → Edge Certificates**: attiva **Always Use HTTPS**.
- **Speed → Optimization**: Brotli è attivo di default; non serve altro.
- **Email Routing** (gratuito): se vuoi caselle tipo `info@playmomentum.it`
  inoltrate a Gmail, attivalo da Email → Email Routing.

## 7. Riferimenti incrociati nel progetto

- URL canonico della build: `astro.config.mjs` → `DEFAULT_SITE_URL =
  'https://playmomentum.it'` (override con `PUBLIC_SITE_URL`).
- Supabase: `backend/supabase/config.toml` usa già `https://playmomentum.it`
  negli URL consentiti; dopo il primo deploy esegui anche il deploy delle
  edge functions e `supabase db push` (migrazione
  `20260727090000_domain_playmomentum_it.sql`).
- Store: usa `RALLYMATE_PRIVACY_URL=https://playmomentum.it/privacy/` e
  `RALLYMATE_TERMS_URL=https://playmomentum.it/termini/` nelle build.
