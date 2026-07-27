import sitemap from '@astrojs/sitemap';
import { defineConfig } from 'astro/config';
import { loadEnv } from 'vite';

/**
 * Dominio canonico confermato per Momentum. `PUBLIC_SITE_URL` può
 * sovrascriverlo in una build di staging, ma il default mantiene canonical,
 * Open Graph, sitemap, robots e llms.txt coerenti anche senza `.env`.
 */
const DEFAULT_SITE_URL = 'https://playmomentum.it';

const PRIORITIES = [
  { match: /^\/$/, priority: 1, changefreq: 'weekly' },
  { match: /^\/supporto\/$/, priority: 0.8, changefreq: 'weekly' },
  // Pagina pilastro: è il contenuto su cui il sito può competere davvero.
  { match: /^\/regole-padel\/$/, priority: 0.9, changefreq: 'monthly' },
  { match: /^\/blog\/$/, priority: 0.7, changefreq: 'weekly' },
  { match: /^\/blog\/.+/, priority: 0.6, changefreq: 'monthly' },
  { match: /^\/download\/$/, priority: 0.8, changefreq: 'weekly' },
  { match: /^\/elimina-account\/$/, priority: 0.4, changefreq: 'yearly' },
];

// Astro valuta il config prima di caricare `.env`: Vite è la fonte unica
// per variabili da file locale, shell e provider di hosting.
const env = loadEnv(process.env.NODE_ENV ?? 'production', process.cwd(), '');
const site = (env.PUBLIC_SITE_URL?.trim() || DEFAULT_SITE_URL).replace(/\/+$/, '');

/**
 * Pagine deliberatamente `noindex`: restano fuori dalla sitemap.
 * `elimina-account` diventa indicizzabile solo quando esiste un recapito di
 * supporto pubblico, quindi segue la stessa condizione del meta robots.
 */
const supportReady = Boolean(env.PUBLIC_SUPPORT_EMAIL?.trim());
const excluded = supportReady
  ? /\/(privacy|privacy-en|termini|cookie)\/?$/
  : /\/(privacy|privacy-en|termini|cookie|elimina-account)\/?$/;

export default defineConfig({
  site,
  integrations: [
    sitemap({
      filter: (page) => !excluded.test(new URL(page).pathname),
      i18n: {
        defaultLocale: 'it',
        locales: { it: 'it-IT' },
      },
      serialize(item) {
        const { pathname } = new URL(item.url);
        const rule = PRIORITIES.find((entry) => entry.match.test(pathname));

        // `lastmod` viene omesso finché non esiste una data editoriale
        // affidabile: la data di build non è un segnale di aggiornamento.
        return {
          ...item,
          changefreq: rule?.changefreq ?? 'monthly',
          priority: rule?.priority ?? 0.6,
        };
      },
    }),
  ],
  image: {
    responsiveStyles: true,
  },
  build: {
    inlineStylesheets: 'auto',
  },
  vite: {
    build: {
      cssMinify: 'lightningcss',
    },
  },
});
