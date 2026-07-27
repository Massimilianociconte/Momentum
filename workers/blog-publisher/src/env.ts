/** Binding e variabili del Worker (vedi wrangler.jsonc + secrets). */
export interface Env {
  GITHUB_OWNER: string;
  GITHUB_REPO: string;
  GITHUB_BRANCH: string;
  BLOG_CONTENT_DIR: string;
  BLOG_IMAGES_DIR: string;
  // Secrets (wrangler secret put)
  GITHUB_TOKEN: string;
  CHATGPT_ACTION_TOKEN: string;
  ADMIN_PASSWORD: string;
  SESSION_SECRET: string;
}

export function json(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, {
    status,
    headers: { 'Cache-Control': 'no-store' },
  });
}
