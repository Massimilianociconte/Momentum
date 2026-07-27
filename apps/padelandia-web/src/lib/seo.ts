/**
 * Helper condivisi per URL assoluti e frammenti JSON-LD.
 *
 * `Astro.site` è sempre valorizzato (astro.config.mjs ha un dominio di
 * default), quindi canonical, Open Graph, sitemap e llms.txt non dipendono più
 * dalla presenza di un file `.env` in fase di build.
 */

export const SITE_NAME = 'Momentum';
export const SITE_LOCALE = 'it-IT';
export const SITE_LANG = 'it';
export const DEFAULT_SITE_URL = 'https://playmomentum.it';

export const siteOrigin = (site?: URL): string =>
  (site?.href ?? `${DEFAULT_SITE_URL}/`).replace(/\/+$/, '');

export const absoluteUrl = (path: string, site?: URL): string =>
  new URL(path, `${siteOrigin(site)}/`).toString();

export interface Crumb {
  readonly name: string;
  readonly path: string;
}

export const organizationSchema = (site?: URL) => {
  // L'email compare nel grafo solo quando la casella di supporto è attiva:
  // un contactPoint vuoto o fittizio danneggerebbe l'E-E-A-T invece di aiutarlo.
  const supportEmail = import.meta.env.PUBLIC_SUPPORT_EMAIL?.trim();

  return {
    '@type': 'Organization',
    '@id': `${siteOrigin(site)}/#organization`,
    name: SITE_NAME,
    url: `${siteOrigin(site)}/`,
    logo: {
      '@type': 'ImageObject',
      url: absoluteUrl('/icon-512.png', site),
      width: 512,
      height: 512,
    },
    description:
      'Momentum sviluppa un’app per il padel che unisce segnapunti offline-first, companion per smartwatch e analisi descrittive delle partite.',
    ...(supportEmail
      ? {
          email: supportEmail,
          contactPoint: {
            '@type': 'ContactPoint',
            contactType: 'customer support',
            email: supportEmail,
            availableLanguage: ['Italian', 'English'],
          },
        }
      : {}),
  };
};

export const websiteSchema = (site?: URL) => ({
  '@type': 'WebSite',
  '@id': `${siteOrigin(site)}/#website`,
  url: `${siteOrigin(site)}/`,
  name: SITE_NAME,
  inLanguage: SITE_LOCALE,
  publisher: { '@id': `${siteOrigin(site)}/#organization` },
});

export const webPageSchema = (
  site: URL | undefined,
  { path, name, description }: { path: string; name: string; description: string },
) => ({
  '@type': 'WebPage',
  '@id': `${absoluteUrl(path, site)}#webpage`,
  url: absoluteUrl(path, site),
  name,
  description,
  inLanguage: SITE_LOCALE,
  isPartOf: { '@id': `${siteOrigin(site)}/#website` },
});

export const blogPostingSchema = (
  site: URL | undefined,
  {
    path,
    headline,
    description,
    datePublished,
    dateModified,
    author,
    image,
  }: {
    path: string;
    headline: string;
    description: string;
    datePublished: string;
    dateModified?: string;
    author: string;
    image?: string;
  },
) => ({
  '@type': 'BlogPosting',
  '@id': `${absoluteUrl(path, site)}#article`,
  mainEntityOfPage: { '@id': `${absoluteUrl(path, site)}#webpage` },
  headline,
  description,
  inLanguage: SITE_LOCALE,
  datePublished,
  ...(dateModified ? { dateModified } : {}),
  // Gli articoli firmati "Momentum" puntano all'Organization già nel grafo;
  // una firma diversa diventa una Person dedicata.
  author:
    author === SITE_NAME
      ? { '@id': `${siteOrigin(site)}/#organization` }
      : { '@type': 'Person', name: author },
  publisher: { '@id': `${siteOrigin(site)}/#organization` },
  ...(image ? { image: absoluteUrl(image, site) } : {}),
});

export const breadcrumbSchema = (site: URL | undefined, trail: readonly Crumb[]) => ({
  '@type': 'BreadcrumbList',
  '@id': `${absoluteUrl(trail.at(-1)?.path ?? '/', site)}#breadcrumb`,
  itemListElement: trail.map((crumb, index) => ({
    '@type': 'ListItem',
    position: index + 1,
    name: crumb.name,
    item: absoluteUrl(crumb.path, site),
  })),
});
