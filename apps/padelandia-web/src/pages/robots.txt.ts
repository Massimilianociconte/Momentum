import type { APIRoute } from 'astro';
import { siteOrigin } from '@/lib/seo';

export const prerender = true;

/**
 * Crawler di ricerca generativa e assistenti conversazionali.
 * Vengono ammessi esplicitamente: la landing serve a farsi trovare anche
 * dentro le risposte degli assistenti (GEO), non solo nella SERP classica.
 */
const GENERATIVE_AGENTS = [
  'GPTBot',
  'OAI-SearchBot',
  'ChatGPT-User',
  'ClaudeBot',
  'Claude-User',
  'Claude-SearchBot',
  'anthropic-ai',
  'PerplexityBot',
  'Perplexity-User',
  'Google-Extended',
  'Applebot',
  'Applebot-Extended',
  'Bingbot',
  'DuckAssistBot',
  'meta-externalagent',
  'Amazonbot',
  'MistralAI-User',
  'cohere-ai',
  'YouBot',
];

export const GET: APIRoute = ({ site }) => {
  const origin = siteOrigin(site);

  const body = [
    `# Momentum — ${origin}/`,
    '',
    '# Content-Signal (content-signal.org): il sito è una landing pubblica,',
    '# vuole essere trovato sia in SERP sia nelle risposte degli assistenti AI.',
    'Content-Signal: search=yes, ai-input=yes, ai-train=yes',
    '',
    'User-agent: *',
    'Allow: /',
    '',
    '# Ricerca generativa e assistenti AI: accesso consentito.',
    ...GENERATIVE_AGENTS.flatMap((agent) => [`User-agent: ${agent}`, 'Allow: /', '']),
    `Sitemap: ${origin}/sitemap-index.xml`,
    '',
    '# Indice sintetico per assistenti generativi (llmstxt.org).',
    `# LLMs: ${origin}/llms.txt`,
    '',
  ].join('\n');

  return new Response(body, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
};
