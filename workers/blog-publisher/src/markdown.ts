/**
 * Costruzione e parsing del Markdown con frontmatter compatibile con
 * lo schema della collection `blog` in
 * apps/momentum-web/src/content.config.ts.
 */

export type ArticleInput = {
  title: string;
  description: string;
  bodyMarkdown: string;

  slug?: string;
  author?: string;
  category?: string;
  tags?: string[];

  seoTitle?: string;
  featuredImage?: string;
  featuredImageAlt?: string;
};

export type BuildOptions = {
  draft: boolean;
  /** Data di prima pubblicazione (YYYY-MM-DD); default oggi. */
  pubDate?: string;
  /** Timestamp ultima modifica ISO; default adesso. */
  updatedDate?: string;
};

/**
 * I valori passano da JSON.stringify: JSON è un sottoinsieme di YAML,
 * quindi l'escaping è sicuro.
 */
export function buildMarkdown(
  input: ArticleInput,
  options: BuildOptions,
): string {
  const now = new Date();
  const tags = Array.from(
    new Set((input.tags ?? []).map((tag) => tag.trim()).filter(Boolean)),
  );

  const frontmatter = [
    '---',
    `title: ${JSON.stringify(input.title.trim())}`,
    `description: ${JSON.stringify(input.description.trim())}`,
    `pubDate: ${JSON.stringify(options.pubDate || now.toISOString().slice(0, 10))}`,
    `updatedDate: ${JSON.stringify(options.updatedDate || now.toISOString())}`,
    `draft: ${options.draft}`,
    `author: ${JSON.stringify(input.author?.trim() || 'Momentum')}`,
    `tags: ${JSON.stringify(tags)}`,
  ];

  if (input.category?.trim()) {
    frontmatter.push(`category: ${JSON.stringify(input.category.trim())}`);
  }

  if (input.seoTitle?.trim()) {
    frontmatter.push(`seoTitle: ${JSON.stringify(input.seoTitle.trim())}`);
  }

  if (input.featuredImage?.trim()) {
    frontmatter.push(
      `featuredImage: ${JSON.stringify(input.featuredImage.trim())}`,
    );
  }

  if (input.featuredImageAlt?.trim()) {
    frontmatter.push(
      `featuredImageAlt: ${JSON.stringify(input.featuredImageAlt.trim())}`,
    );
  }

  return [...frontmatter, '---', '', input.bodyMarkdown.trim(), ''].join('\n');
}

export type ParsedArticle = {
  frontmatter: Record<string, unknown>;
  bodyMarkdown: string;
};

/**
 * Parser tollerante del frontmatter piatto `chiave: valore` generato da
 * buildMarkdown (o scritto a mano con valori semplici). I valori JSON
 * (stringhe quotate, array, booleani, numeri) vengono decodificati; il
 * resto rimane stringa grezza.
 */
export function parseFrontmatter(markdown: string): ParsedArticle {
  const match = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/.exec(markdown);

  if (!match) {
    return { frontmatter: {}, bodyMarkdown: markdown.trim() };
  }

  const frontmatter: Record<string, unknown> = {};

  const source = match[1] ?? '';

  for (const line of source.split(/\r?\n/)) {
    const pair = /^([A-Za-z][A-Za-z0-9_]*):\s*(.*)$/.exec(line);
    if (!pair) {
      continue;
    }

    const key = pair[1];
    const raw = (pair[2] ?? '').trim();
    if (!key) {
      continue;
    }

    if (raw === '') {
      frontmatter[key] = '';
      continue;
    }

    if (raw === 'true' || raw === 'false') {
      frontmatter[key] = raw === 'true';
      continue;
    }

    try {
      frontmatter[key] = JSON.parse(raw);
    } catch {
      frontmatter[key] = raw;
    }
  }

  return {
    frontmatter,
    bodyMarkdown: markdown.slice(match[0].length).trim(),
  };
}

export function slugify(value: string): string {
  return value
    .normalize('NFKD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 100);
}
