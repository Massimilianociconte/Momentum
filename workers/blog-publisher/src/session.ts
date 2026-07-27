/**
 * Sessione admin basata su cookie firmato: `scadenzaMs.HMAC-SHA256`.
 * Nessuno stato lato server: la firma con SESSION_SECRET è sufficiente.
 */

const COOKIE_NAME = 'mm_session';
const SESSION_DURATION_MS = 30 * 24 * 60 * 60 * 1000; // 30 giorni

export async function createSessionCookie(secret: string): Promise<string> {
  const expiresAt = Date.now() + SESSION_DURATION_MS;
  const signature = await hmacHex(secret, String(expiresAt));
  const maxAgeSeconds = Math.floor(SESSION_DURATION_MS / 1000);

  return (
    `${COOKIE_NAME}=${expiresAt}.${signature}; ` +
    `Max-Age=${maxAgeSeconds}; Path=/; HttpOnly; Secure; SameSite=Strict`
  );
}

export function clearSessionCookie(): string {
  return `${COOKIE_NAME}=; Max-Age=0; Path=/; HttpOnly; Secure; SameSite=Strict`;
}

export async function hasValidSession(
  request: Request,
  secret: string,
): Promise<boolean> {
  const cookieHeader = request.headers.get('cookie') ?? '';

  const cookie = cookieHeader
    .split(';')
    .map((part) => part.trim())
    .find((part) => part.startsWith(`${COOKIE_NAME}=`));

  if (!cookie) {
    return false;
  }

  const value = cookie.slice(COOKIE_NAME.length + 1);
  const separator = value.indexOf('.');
  if (separator <= 0) {
    return false;
  }

  const expiresAt = Number(value.slice(0, separator));
  const signature = value.slice(separator + 1);

  if (!Number.isFinite(expiresAt) || expiresAt < Date.now()) {
    return false;
  }

  const expected = await hmacHex(secret, String(expiresAt));
  return timingSafeEqualString(signature, expected);
}

export function timingSafeEqualString(a: string, b: string): boolean {
  const encoder = new TextEncoder();
  const bufferA = encoder.encode(a);
  const bufferB = encoder.encode(b);

  if (bufferA.byteLength !== bufferB.byteLength) {
    return false;
  }

  return crypto.subtle.timingSafeEqual(bufferA, bufferB);
}

async function hmacHex(secret: string, payload: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(payload),
  );

  return [...new Uint8Array(signature)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}
