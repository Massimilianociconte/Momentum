/**
 * API del pannello admin (/api/*) e proxy immagini (/blog/*).
 * Tutte le rotte tranne /api/login richiedono il cookie di sessione.
 * Ogni scrittura è un commit GitHub: il sito viene ricostruito dalla CI.
 */

import { json, type Env } from './env';
import {
  decodeBase64,
  deleteGitHubFile,
  getGitHubFile,
  GitHubConflictError,
  githubRequest,
  listGitHubDir,
  putGitHubBinaryFile,
  putGitHubFile,
} from './github';
import {
  buildMarkdown,
  parseFrontmatter,
  slugify,
  type ArticleInput,
} from './markdown';
import {
  clearSessionCookie,
  createSessionCookie,
  hasValidSession,
  timingSafeEqualString,
} from './session';

// Base64 di ~8 MB binari; le altre rotte restano sul limite globale.
const MAX_IMAGE_BASE64_CHARS = 11_200_000;

const IMAGE_CONTENT_TYPES: Record<string, string> = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
};

const SLUG_PATTERN = /^[a-z0-9][a-z0-9-]{0,99}$/;

export async function handleAdminRequest(
  request: Request,
  env: Env,
): Promise<Response> {
  const url = new URL(request.url);
  const { pathname } = url;

  if (request.method === 'POST' && pathname === '/api/login') {
    return login(request, env);
  }

  if (!(await hasValidSession(request, env.SESSION_SECRET))) {
    return json({ error: 'Unauthorized' }, 401);
  }

  if (request.method === 'POST' && pathname === '/api/logout') {
    return withCookie(json({ success: true }), clearSessionCookie());
  }

  if (request.method === 'GET' && pathname === '/api/session') {
    return json({ authenticated: true });
  }

  if (pathname === '/api/articles') {
    if (request.method === 'GET') {
      return listArticles(env);
    }
    if (request.method === 'POST') {
      return createArticle(request, env);
    }
  }

  const articleMatch = /^\/api\/articles\/([a-z0-9-]+)$/.exec(pathname);
  if (articleMatch) {
    const slug = articleMatch[1] ?? '';
    if (request.method === 'GET') {
      return getArticle(env, slug);
    }
    if (request.method === 'PUT') {
      return updateArticle(request, env, slug);
    }
    if (request.method === 'DELETE') {
      return deleteArticle(env, slug);
    }
  }

  const draftMatch = /^\/api\/articles\/([a-z0-9-]+)\/draft$/.exec(pathname);
  if (draftMatch && request.method === 'POST') {
    return setDraftState(request, env, draftMatch[1] ?? '');
  }

  if (request.method === 'POST' && pathname === '/api/images') {
    return uploadImage(request, env);
  }

  const imagesMatch = /^\/api\/images\/([a-z0-9-]+)$/.exec(pathname);
  if (imagesMatch && request.method === 'GET') {
    return listImages(env, imagesMatch[1] ?? '');
  }

  if (request.method === 'GET' && pathname.startsWith('/blog/')) {
    return proxyImage(env, pathname);
  }

  return json({ error: 'Not found' }, 404);
}

async function login(request: Request, env: Env): Promise<Response> {
  const input = (await request.json()) as { password?: string };
  const password = typeof input.password === 'string' ? input.password : '';

  if (!password || !timingSafeEqualString(password, env.ADMIN_PASSWORD)) {
    // Ritardo fisso: rende impraticabile il brute force da client remoti.
    await new Promise((resolve) => setTimeout(resolve, 500));
    return json({ error: 'Invalid password' }, 401);
  }

  return withCookie(
    json({ success: true }),
    await createSessionCookie(env.SESSION_SECRET),
  );
}

async function listArticles(env: Env): Promise<Response> {
  const entries = await listGitHubDir(env, env.BLOG_CONTENT_DIR);

  const files = (entries ?? []).filter(
    (entry) => entry.type === 'file' && /\.(md|mdx)$/.test(entry.name),
  );

  const articles = await Promise.all(
    files.map(async (entry) => {
      const slug = entry.name.replace(/\.(md|mdx)$/, '');
      const file = await getGitHubFile(env, entry.path);
      if (!file) {
        return null;
      }

      const { frontmatter } = parseFrontmatter(decodeBase64(file.content));

      return {
        slug,
        title: String(frontmatter.title ?? slug),
        description: String(frontmatter.description ?? ''),
        draft: frontmatter.draft !== false,
        pubDate: String(frontmatter.pubDate ?? ''),
        updatedDate: String(frontmatter.updatedDate ?? ''),
        category: String(frontmatter.category ?? ''),
      };
    }),
  );

  const sorted = articles
    .filter((article) => article !== null)
    .sort((a, b) => (a.pubDate < b.pubDate ? 1 : -1));

  return json({ articles: sorted });
}

async function getArticle(env: Env, slug: string): Promise<Response> {
  if (!SLUG_PATTERN.test(slug)) {
    return json({ error: 'Invalid slug' }, 400);
  }

  const file = await getGitHubFile(env, `${env.BLOG_CONTENT_DIR}/${slug}.md`);
  if (!file) {
    return json({ error: 'Article not found' }, 404);
  }

  const { frontmatter, bodyMarkdown } = parseFrontmatter(
    decodeBase64(file.content),
  );

  return json({ slug, sha: file.sha, frontmatter, bodyMarkdown });
}

async function createArticle(request: Request, env: Env): Promise<Response> {
  const input = (await request.json()) as Partial<ArticleInput>;

  if (!input.title?.trim() || !input.description?.trim()) {
    return json({ error: 'title and description are required' }, 400);
  }

  const slug = slugify(input.slug || input.title);
  if (!slug) {
    return json({ error: 'Invalid slug' }, 400);
  }

  const path = `${env.BLOG_CONTENT_DIR}/${slug}.md`;

  const existing = await getGitHubFile(env, path);
  if (existing) {
    return json(
      { error: 'An article with this slug already exists', slug },
      409,
    );
  }

  const markdown = buildMarkdown(
    { ...(input as ArticleInput), bodyMarkdown: input.bodyMarkdown ?? '' },
    { draft: true },
  );

  const result = await putGitHubFile({
    env,
    path,
    content: markdown,
    message: `content(blog): create draft ${slug} [admin]`,
  });

  return json(
    {
      success: true,
      slug,
      sha: result.content?.sha,
      commitUrl: result.commit?.html_url,
    },
    201,
  );
}

async function updateArticle(
  request: Request,
  env: Env,
  slug: string,
): Promise<Response> {
  if (!SLUG_PATTERN.test(slug)) {
    return json({ error: 'Invalid slug' }, 400);
  }

  const input = (await request.json()) as Partial<ArticleInput> & {
    sha?: string;
    draft?: boolean;
    pubDate?: string;
  };

  if (!input.title?.trim() || !input.description?.trim()) {
    return json({ error: 'title and description are required' }, 400);
  }

  if (!input.sha) {
    return json({ error: 'sha is required' }, 400);
  }

  const markdown = buildMarkdown(
    { ...(input as ArticleInput), bodyMarkdown: input.bodyMarkdown ?? '' },
    {
      draft: input.draft !== false,
      pubDate: input.pubDate,
      updatedDate: new Date().toISOString(),
    },
  );

  try {
    const result = await putGitHubFile({
      env,
      path: `${env.BLOG_CONTENT_DIR}/${slug}.md`,
      content: markdown,
      message: `content(blog): update ${slug} [admin]`,
      sha: input.sha,
    });

    return json({
      success: true,
      slug,
      sha: result.content?.sha,
      commitUrl: result.commit?.html_url,
    });
  } catch (error) {
    if (error instanceof GitHubConflictError) {
      return json(
        { error: 'Article was modified elsewhere, reload it first' },
        409,
      );
    }
    throw error;
  }
}

async function setDraftState(
  request: Request,
  env: Env,
  slug: string,
): Promise<Response> {
  if (!SLUG_PATTERN.test(slug)) {
    return json({ error: 'Invalid slug' }, 400);
  }

  const input = (await request.json()) as { draft?: boolean };
  if (typeof input.draft !== 'boolean') {
    return json({ error: 'draft boolean is required' }, 400);
  }

  const path = `${env.BLOG_CONTENT_DIR}/${slug}.md`;
  const file = await getGitHubFile(env, path);
  if (!file) {
    return json({ error: 'Article not found' }, 404);
  }

  const markdown = decodeBase64(file.content);
  if (!/^draft:\s*(true|false)\s*$/m.test(markdown)) {
    return json({ error: 'Article has invalid frontmatter' }, 409);
  }

  const now = new Date().toISOString();
  const updated = markdown
    .replace(/^draft:\s*(true|false)\s*$/m, `draft: ${input.draft}`)
    .replace(/^updatedDate:.*$/m, `updatedDate: ${JSON.stringify(now)}`);

  const result = await putGitHubFile({
    env,
    path,
    content: updated,
    message: input.draft
      ? `content(blog): unpublish ${slug} [admin]`
      : `content(blog): publish ${slug} [admin]`,
    sha: file.sha,
  });

  return json({
    success: true,
    slug,
    draft: input.draft,
    sha: result.content?.sha,
    commitUrl: result.commit?.html_url,
  });
}

async function deleteArticle(env: Env, slug: string): Promise<Response> {
  if (!SLUG_PATTERN.test(slug)) {
    return json({ error: 'Invalid slug' }, 400);
  }

  const path = `${env.BLOG_CONTENT_DIR}/${slug}.md`;
  const file = await getGitHubFile(env, path);
  if (!file) {
    return json({ error: 'Article not found' }, 404);
  }

  await deleteGitHubFile({
    env,
    path,
    message: `content(blog): delete ${slug} [admin]`,
    sha: file.sha,
  });

  return json({ success: true, slug });
}

async function uploadImage(request: Request, env: Env): Promise<Response> {
  const input = (await request.json()) as {
    slug?: string;
    filename?: string;
    contentBase64?: string;
  };

  const slug = input.slug ?? '';
  if (!SLUG_PATTERN.test(slug)) {
    return json({ error: 'Invalid slug' }, 400);
  }

  const contentBase64 = (input.contentBase64 ?? '')
    .replace(/^data:[^;]+;base64,/, '')
    .replace(/\s/g, '');

  if (!contentBase64 || !/^[A-Za-z0-9+/]+=*$/.test(contentBase64)) {
    return json({ error: 'contentBase64 is required' }, 400);
  }

  if (contentBase64.length > MAX_IMAGE_BASE64_CHARS) {
    return json({ error: 'Image too large (max 8 MB)' }, 413);
  }

  const rawName = input.filename ?? 'image.jpg';
  const extension = (rawName.split('.').pop() ?? '').toLowerCase();
  if (!IMAGE_CONTENT_TYPES[extension]) {
    return json({ error: 'Unsupported image type (jpg, png, webp)' }, 400);
  }

  const baseName =
    slugify(rawName.replace(/\.[^.]+$/, '')).slice(0, 60) || 'image';

  let filename = `${baseName}.${extension}`;
  let path = `${env.BLOG_IMAGES_DIR}/${slug}/${filename}`;

  // Mai sovrascrivere: se il nome esiste, aggiunge un suffisso temporale.
  if (await getGitHubFile(env, path)) {
    filename = `${baseName}-${Date.now().toString(36)}.${extension}`;
    path = `${env.BLOG_IMAGES_DIR}/${slug}/${filename}`;
  }

  const result = await putGitHubBinaryFile({
    env,
    path,
    contentBase64,
    message: `content(blog): add image ${slug}/${filename} [admin]`,
  });

  return json(
    {
      success: true,
      filename,
      path: `/blog/${slug}/${filename}`,
      commitUrl: result.commit?.html_url,
    },
    201,
  );
}

async function listImages(env: Env, slug: string): Promise<Response> {
  if (!SLUG_PATTERN.test(slug)) {
    return json({ error: 'Invalid slug' }, 400);
  }

  const entries = await listGitHubDir(env, `${env.BLOG_IMAGES_DIR}/${slug}`);

  const images = (entries ?? [])
    .filter((entry) => entry.type === 'file')
    .map((entry) => ({
      name: entry.name,
      path: `/blog/${slug}/${entry.name}`,
    }));

  return json({ images });
}

/**
 * Serve le immagini di public/blog direttamente da GitHub: nell'editor
 * si vedono subito, senza aspettare il deploy del sito.
 */
async function proxyImage(env: Env, pathname: string): Promise<Response> {
  const rest = pathname.slice('/blog/'.length);
  const segments = rest.split('/');

  const isSafe =
    segments.length >= 1 &&
    segments.every((segment) => /^[a-z0-9][a-z0-9._-]*$/i.test(segment));

  if (!isSafe) {
    return json({ error: 'Not found' }, 404);
  }

  const extension = (rest.split('.').pop() ?? '').toLowerCase();
  const contentType = IMAGE_CONTENT_TYPES[extension];
  if (!contentType) {
    return json({ error: 'Not found' }, 404);
  }

  const response = await githubRequest(
    env,
    `${env.BLOG_IMAGES_DIR}/${rest}`,
    'GET',
    undefined,
    'application/vnd.github.raw',
  );

  if (!response.ok) {
    return json({ error: 'Not found' }, 404);
  }

  return new Response(response.body, {
    headers: {
      'Content-Type': contentType,
      'Cache-Control': 'private, max-age=60',
    },
  });
}

function withCookie(response: Response, cookie: string): Response {
  const withHeaders = new Response(response.body, response);
  withHeaders.headers.set('Set-Cookie', cookie);
  return withHeaders;
}
