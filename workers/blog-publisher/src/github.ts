/**
 * Helpers per la GitHub Contents API. Ogni scrittura è un commit sul
 * branch configurato; i path sono encodati segmento per segmento.
 */

import type { Env } from './env';

export type GitHubFile = {
  sha: string;
  content: string;
  html_url: string;
};

export type GitHubDirEntry = {
  name: string;
  path: string;
  sha: string;
  type: 'file' | 'dir';
};

export type GitHubWriteResult = {
  content?: { html_url?: string; sha?: string };
  commit?: { html_url?: string };
};

export function githubRequest(
  env: Env,
  path: string,
  method: 'GET' | 'PUT' | 'DELETE',
  body?: Record<string, unknown>,
  accept = 'application/vnd.github+json',
): Promise<Response> {
  const safePath = path.split('/').map(encodeURIComponent).join('/');

  const base =
    'https://api.github.com/repos/' +
    `${encodeURIComponent(env.GITHUB_OWNER)}/` +
    `${encodeURIComponent(env.GITHUB_REPO)}/` +
    `contents/${safePath}`;

  const url =
    method === 'GET'
      ? `${base}?ref=${encodeURIComponent(env.GITHUB_BRANCH)}`
      : base;

  return fetch(url, {
    method,
    headers: {
      Accept: accept,
      Authorization: `Bearer ${env.GITHUB_TOKEN}`,
      'Content-Type': 'application/json',
      'User-Agent': 'momentum-blog-publisher',
      'X-GitHub-Api-Version': '2022-11-28',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
}

export async function getGitHubFile(
  env: Env,
  path: string,
): Promise<GitHubFile | null> {
  const response = await githubRequest(env, path, 'GET');

  if (response.status === 404) {
    return null;
  }

  if (!response.ok) {
    throw new Error(`GitHub read failed with status ${response.status}`);
  }

  return (await response.json()) as GitHubFile;
}

/** Lista una directory; null se la directory non esiste. */
export async function listGitHubDir(
  env: Env,
  path: string,
): Promise<GitHubDirEntry[] | null> {
  const response = await githubRequest(env, path, 'GET');

  if (response.status === 404) {
    return null;
  }

  if (!response.ok) {
    throw new Error(`GitHub list failed with status ${response.status}`);
  }

  const entries = (await response.json()) as GitHubDirEntry[];
  return Array.isArray(entries) ? entries : null;
}

export async function putGitHubFile({
  env,
  path,
  content,
  message,
  sha,
}: {
  env: Env;
  path: string;
  content: string;
  message: string;
  sha?: string;
}): Promise<GitHubWriteResult> {
  return putGitHubBinaryFile({
    env,
    path,
    contentBase64: encodeBase64(content),
    message,
    sha,
  });
}

/** Scrive contenuto già in base64 (immagini o testo pre-encodato). */
export async function putGitHubBinaryFile({
  env,
  path,
  contentBase64,
  message,
  sha,
}: {
  env: Env;
  path: string;
  contentBase64: string;
  message: string;
  sha?: string;
}): Promise<GitHubWriteResult> {
  const body: Record<string, unknown> = {
    message,
    content: contentBase64,
    branch: env.GITHUB_BRANCH,
  };

  if (sha) {
    body.sha = sha;
  }

  const response = await githubRequest(env, path, 'PUT', body);

  if (!response.ok) {
    const responseText = await response.text();

    console.error(
      JSON.stringify({
        event: 'github_write_failed',
        status: response.status,
        response: responseText.slice(0, 500),
      }),
    );

    if (response.status === 409) {
      throw new GitHubConflictError();
    }

    throw new Error(`GitHub write failed with status ${response.status}`);
  }

  return (await response.json()) as GitHubWriteResult;
}

export async function deleteGitHubFile({
  env,
  path,
  message,
  sha,
}: {
  env: Env;
  path: string;
  message: string;
  sha: string;
}): Promise<GitHubWriteResult> {
  const response = await githubRequest(env, path, 'DELETE', {
    message,
    sha,
    branch: env.GITHUB_BRANCH,
  });

  if (!response.ok) {
    const responseText = await response.text();

    console.error(
      JSON.stringify({
        event: 'github_delete_failed',
        status: response.status,
        response: responseText.slice(0, 500),
      }),
    );

    if (response.status === 409) {
      throw new GitHubConflictError();
    }

    throw new Error(`GitHub delete failed with status ${response.status}`);
  }

  return (await response.json()) as GitHubWriteResult;
}

/** Sollevata quando lo SHA inviato non corrisponde più al file remoto. */
export class GitHubConflictError extends Error {
  constructor() {
    super('GitHub content conflict');
    this.name = 'GitHubConflictError';
  }
}

export function encodeBase64(value: string): string {
  const bytes = new TextEncoder().encode(value);
  let binary = '';

  // btoa accetta solo stringhe binarie: chunk per non superare lo stack.
  for (let index = 0; index < bytes.length; index += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(index, index + 0x8000));
  }

  return btoa(binary);
}

export function decodeBase64(value: string): string {
  const binary = atob(value.replace(/\n/g, ''));
  const bytes = Uint8Array.from(binary, (character) =>
    character.charCodeAt(0),
  );

  return new TextDecoder().decode(bytes);
}
