import { access, readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { loadEnv } from 'vite';

const root = process.cwd();
const dist = path.join(root, 'dist');
const env = loadEnv(process.env.NODE_ENV ?? 'production', root, '');
const origin = (
  env.PUBLIC_SITE_URL?.trim() || 'https://padelandia.app'
).replace(/\/+$/, '');
const failures = [];

const walk = async (directory) => {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(
    entries.map(async (entry) => {
      const target = path.join(directory, entry.name);
      return entry.isDirectory() ? walk(target) : [target];
    }),
  );
  return files.flat();
};

const exists = async (file) => {
  try {
    await access(file);
    return true;
  } catch {
    return false;
  }
};

const routeFile = (pathname) => {
  const relative = decodeURIComponent(pathname).replace(/^\/+/, '');
  if (!relative) return path.join(dist, 'index.html');
  if (relative.endsWith('/')) return path.join(dist, relative, 'index.html');
  if (path.extname(relative)) return path.join(dist, relative);
  return path.join(dist, relative, 'index.html');
};

const htmlFiles = (await walk(dist)).filter((file) => file.endsWith('.html'));

for (const file of htmlFiles) {
  const html = await readFile(file, 'utf8');
  const label = path.relative(dist, file);

  const canonical = html.match(/<link\s+rel="canonical"\s+href="([^"]+)"/)?.[1];
  if (!canonical?.startsWith(`${origin}/`)) {
    failures.push(`${label}: canonical assente o con origin incoerente`);
  }

  const schemas = [
    ...html.matchAll(
      /<script[^>]+type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/g,
    ),
  ];
  if (!schemas.length) failures.push(`${label}: JSON-LD assente`);
  for (const [, json] of schemas) {
    try {
      JSON.parse(json);
    } catch (error) {
      failures.push(`${label}: JSON-LD non valido (${error.message})`);
    }
  }

  const links = [
    ...html.matchAll(/<a\b[^>]*\bhref="([^"]+)"[^>]*>/g),
  ].map((match) => match[1]);

  for (const href of links) {
    if (/^(?:https?:|mailto:|tel:)/.test(href)) continue;

    const target = new URL(href, canonical || `${origin}/`);
    // Un frammento puro appartiene sempre al documento corrente: questo
    // include 404.html, che non corrisponde al normale mapping /route/index.
    const targetFile = href.startsWith('#') ? file : routeFile(target.pathname);
    if (!(await exists(targetFile))) {
      failures.push(`${label}: link interno senza destinazione ${href}`);
      continue;
    }

    if (!target.hash || !targetFile.endsWith('.html')) continue;
    const targetHtml = await readFile(targetFile, 'utf8');
    const id = decodeURIComponent(target.hash.slice(1));
    const escaped = id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    if (!new RegExp(`\\bid="${escaped}"`).test(targetHtml)) {
      failures.push(`${label}: frammento interno inesistente ${href}`);
    }
  }
}

const required = [
  'index.html',
  'supporto/index.html',
  'robots.txt',
  'sitemap-index.xml',
  'llms.txt',
  'llms-full.txt',
];

for (const relative of required) {
  if (!(await exists(path.join(dist, relative)))) {
    failures.push(`output richiesto assente: ${relative}`);
  }
}

const sitemapFiles = (await walk(dist)).filter((file) =>
  /sitemap.*\.xml$/.test(path.basename(file)),
);
for (const file of sitemapFiles) {
  const xml = await readFile(file, 'utf8');
  if (xml.includes('<lastmod>')) {
    failures.push(
      `${path.basename(file)}: lastmod artificiale presente senza data editoriale`,
    );
  }
}

const robots = await readFile(path.join(dist, 'robots.txt'), 'utf8');
if (!robots.includes(`Sitemap: ${origin}/sitemap-index.xml`)) {
  failures.push('robots.txt: sitemap con origin incoerente');
}

if (failures.length) {
  console.error(failures.map((failure) => `- ${failure}`).join('\n'));
  process.exit(1);
}

console.log(
  `Build validato: ${htmlFiles.length} pagine HTML, JSON-LD e link interni coerenti.`,
);
