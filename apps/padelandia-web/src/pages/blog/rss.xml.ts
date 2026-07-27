import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';
import { SITE_LANG, SITE_NAME, siteOrigin } from '@/lib/seo';

export const prerender = true;

/**
 * `/blog/rss.xml` — feed RSS 2.0 del blog, generato a mano per non aggiungere
 * dipendenze. Oltre ai lettori RSS, il feed è un canale di discovery per
 * crawler di ricerca e assistenti AI: segnala i nuovi articoli senza aspettare
 * la riscansione della sitemap.
 */

const escapeXml = (value: string): string =>
  value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

export const GET: APIRoute = async ({ site }) => {
  const origin = siteOrigin(site);
  const posts = (await getCollection('blog', ({ data }) => data.draft !== true))
    .sort((a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf());

  const items = posts
    .map((post) => {
      const url = `${origin}/blog/${post.id}/`;
      const category = post.data.category
        ? `\n      <category>${escapeXml(post.data.category)}</category>`
        : '';

      return `    <item>
      <title>${escapeXml(post.data.title)}</title>
      <link>${url}</link>
      <guid isPermaLink="true">${url}</guid>
      <description>${escapeXml(post.data.description)}</description>
      <pubDate>${post.data.pubDate.toUTCString()}</pubDate>${category}
    </item>`;
    })
    .join('\n');

  // lastBuildDate segue l'articolo più recente, non l'orario di build: così
  // il feed cambia solo quando cambia davvero il contenuto.
  const lastBuildDate = (posts[0]?.data.pubDate ?? new Date()).toUTCString();

  const body = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>Blog ${SITE_NAME}</title>
    <link>${origin}/blog/</link>
    <description>Guide e approfondimenti su padel, punteggio, smartwatch e allenamento.</description>
    <language>${SITE_LANG}</language>
    <lastBuildDate>${lastBuildDate}</lastBuildDate>
    <atom:link href="${origin}/blog/rss.xml" rel="self" type="application/rss+xml" />
${items}
  </channel>
</rss>
`;

  return new Response(body, {
    headers: {
      'Content-Type': 'application/rss+xml; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
};
