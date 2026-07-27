/**
 * Worker editoriale del blog Momentum.
 *
 * Due superfici:
 * - Endpoint GPT (/articles/drafts, /articles/publish, /health):
 *   autenticati con Bearer CHATGPT_ACTION_TOKEN; le bozze nascono con
 *   `draft: true` e la pubblicazione richiede conferma esplicita.
 * - Pannello admin (/api/*, /blog/*): login con password e cookie di
 *   sessione firmato; la UI statica in ./admin è servita dagli assets.
 *
 * Tutte le scritture passano dalla GitHub Contents API: ogni modifica
 * è un commit che fa ripartire il deploy del sito.
 */

import { json, type Env } from './env';
import { handleAdminRequest } from './admin';
import { decodeBase64, getGitHubFile, putGitHubFile } from './github';
import { buildMarkdown, slugify, type ArticleInput } from './markdown';

const MAX_REQUEST_BYTES = 200_000;
// Upload immagini: base64 di ~8 MB binari + overhead JSON.
const MAX_IMAGE_REQUEST_BYTES = 12_000_000;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const url = new URL(request.url);
      const isAdminRoute =
        url.pathname.startsWith('/api/') || url.pathname.startsWith('/blog/');

      const maxBytes =
        url.pathname === '/api/images'
          ? MAX_IMAGE_REQUEST_BYTES
          : MAX_REQUEST_BYTES;

      const declaredLength = Number(
        request.headers.get('content-length') ?? '0',
      );
      if (declaredLength > maxBytes) {
        return json({ error: 'Request too large' }, 413);
      }

      if (isAdminRoute) {
        return await handleAdminRequest(request, env);
      }

      if (!isAuthorized(request, env.CHATGPT_ACTION_TOKEN)) {
        return json({ error: 'Unauthorized' }, 401);
      }

      if (request.method === 'POST' && url.pathname === '/articles/drafts') {
        return await createDraft(request, env);
      }

      if (request.method === 'POST' && url.pathname === '/articles/publish') {
        return await publishArticle(request, env);
      }

      if (request.method === 'GET' && url.pathname === '/health') {
        return json({ status: 'ok' });
      }

      return json({ error: 'Not found' }, 404);
    } catch (error) {
      console.error(
        JSON.stringify({
          event: 'blog_publisher_error',
          message: error instanceof Error ? error.message : 'Unknown error',
        }),
      );

      return json({ error: 'Internal server error' }, 500);
    }
  },
} satisfies ExportedHandler<Env>;

async function createDraft(request: Request, env: Env): Promise<Response> {
  const input = (await request.json()) as Partial<ArticleInput>;

  if (
    !input.title?.trim() ||
    !input.description?.trim() ||
    !input.bodyMarkdown?.trim()
  ) {
    return json(
      { error: 'title, description and bodyMarkdown are required' },
      400,
    );
  }

  const slug = slugify(input.slug || input.title);
  if (!slug) {
    return json({ error: 'Invalid slug' }, 400);
  }

  const path = `${env.BLOG_CONTENT_DIR}/${slug}.md`;

  const existing = await getGitHubFile(env, path);
  if (existing) {
    return json(
      { error: 'An article with this slug already exists', slug, path },
      409,
    );
  }

  const markdown = buildMarkdown(input as ArticleInput, { draft: true });

  const result = await putGitHubFile({
    env,
    path,
    content: markdown,
    message: `content(blog): create draft ${slug}`,
  });

  return json(
    {
      success: true,
      status: 'draft',
      slug,
      path,
      fileUrl: result.content?.html_url,
      commitUrl: result.commit?.html_url,
    },
    201,
  );
}

async function publishArticle(request: Request, env: Env): Promise<Response> {
  const input = (await request.json()) as {
    slug?: string;
    confirmPublish?: boolean;
  };

  if (input.confirmPublish !== true) {
    return json({ error: 'Explicit publication confirmation required' }, 400);
  }

  const slug = slugify(input.slug ?? '');
  if (!slug) {
    return json({ error: 'Invalid slug' }, 400);
  }

  const path = `${env.BLOG_CONTENT_DIR}/${slug}.md`;
  const existing = await getGitHubFile(env, path);
  if (!existing) {
    return json({ error: 'Article not found' }, 404);
  }

  const currentMarkdown = decodeBase64(existing.content);

  if (!/^draft:\s*true\s*$/m.test(currentMarkdown)) {
    return json(
      { error: 'Article is already published or has invalid frontmatter' },
      409,
    );
  }

  const now = new Date().toISOString();

  const publishedMarkdown = currentMarkdown
    .replace(/^draft:\s*true\s*$/m, 'draft: false')
    .replace(/^updatedDate:.*$/m, `updatedDate: ${JSON.stringify(now)}`);

  const result = await putGitHubFile({
    env,
    path,
    content: publishedMarkdown,
    sha: existing.sha,
    message: `content(blog): publish ${slug}`,
  });

  return json({
    success: true,
    status: 'published',
    slug,
    path,
    fileUrl: result.content?.html_url,
    commitUrl: result.commit?.html_url,
  });
}

function isAuthorized(request: Request, expectedToken: string): boolean {
  const authorization = request.headers.get('authorization') ?? '';

  const receivedToken = authorization.startsWith('Bearer ')
    ? authorization.slice(7)
    : '';

  const received = new TextEncoder().encode(receivedToken);
  const expected = new TextEncoder().encode(expectedToken);

  if (received.byteLength !== expected.byteLength) {
    return false;
  }

  return crypto.subtle.timingSafeEqual(received, expected);
}
