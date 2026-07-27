import { readFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { loadEnv } from 'vite';

/**
 * Ping IndexNow dopo il deploy: notifica in tempo reale Bing (che alimenta
 * anche ChatGPT search e Copilot), Yandex, Naver e Seznam. Google non aderisce
 * a IndexNow: per Google fa fede la sitemap in Search Console.
 *
 * La chiave è pubblica per protocollo: il file `public/<key>.txt` servito dal
 * sito È la prova di proprietà (https://www.indexnow.org/documentation).
 */
const INDEXNOW_KEY = '36a01584206de4a65c76f83af92d2a7b';

const root = process.cwd();
const env = loadEnv(process.env.NODE_ENV ?? 'production', root, '');
const origin = (
  env.PUBLIC_SITE_URL?.trim() || 'https://playmomentum.it'
).replace(/\/+$/, '');
const host = new URL(origin).hostname;

// La sitemap della build è la fonte unica delle pagine indicizzabili:
// niente elenchi manuali da tenere allineati.
const sitemap = await readFile(
  path.join(root, 'dist', 'sitemap-0.xml'),
  'utf8',
);
const urlList = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(
  ([, url]) => url,
);

if (!urlList.length) {
  console.error('IndexNow: nessun URL trovato nella sitemap, ping annullato.');
  process.exit(1);
}

const response = await fetch('https://api.indexnow.org/indexnow', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json; charset=utf-8' },
  body: JSON.stringify({
    host,
    key: INDEXNOW_KEY,
    keyLocation: `${origin}/${INDEXNOW_KEY}.txt`,
    urlList,
  }),
});

// 200 = ok, 202 = accettato con verifica chiave differita: entrambi validi.
if (response.status === 200 || response.status === 202) {
  console.log(
    `IndexNow: ${urlList.length} URL notificati (HTTP ${response.status}).`,
  );
} else {
  console.error(
    `IndexNow: risposta inattesa HTTP ${response.status} — ${await response.text()}`,
  );
  process.exit(1);
}
