export type RecapPageInput = {
  slug: string;
  headline: string;
  result: string;
  team: string;
  chips: string[];
  imageUrl?: string | null;
  userAgent?: string | null;
  appStoreUrl?: string | null;
  playStoreUrl?: string | null;
};

export const RECAP_SECURITY_HEADERS = {
  "content-type": "text/html; charset=utf-8",
  "cache-control": "public, max-age=3600, s-maxage=86400",
  "content-security-policy":
    "default-src 'none'; style-src 'unsafe-inline'; img-src https:; " +
    "base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
  "referrer-policy": "no-referrer",
  "x-content-type-options": "nosniff",
  "x-frame-options": "DENY",
  "permissions-policy":
    "camera=(), microphone=(), geolocation=(), payment=(), usb=()",
} as const;

export function isValidRecapSlug(value: string): boolean {
  return /^[A-Za-z0-9_-]{6,128}$/.test(value);
}

export function safeHttpsUrl(value: unknown): string | null {
  if (typeof value !== "string" || value.length > 2048) return null;
  if (/[\s"'<>\\]/.test(value)) return null;
  try {
    const parsed = new URL(value);
    if (parsed.protocol !== "https:" || !parsed.hostname) return null;
    if (parsed.username || parsed.password) return null;
    return parsed.toString();
  } catch {
    return null;
  }
}

export function buildRecapPage(input: RecapPageInput): string {
  const imageUrl = safeHttpsUrl(input.imageUrl);
  const storeUrl = selectStoreUrl(
    input.userAgent,
    input.appStoreUrl,
    input.playStoreUrl,
  );
  const deepLink = `rallymate://recap/${encodeURIComponent(input.slug)}`;

  return `<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Momentum - ${escapeHtml(input.headline)}</title>
<meta property="og:title" content="${escapeHtml(input.headline)}">
<meta property="og:description" content="${
    escapeHtml([input.result, input.team].filter(Boolean).join(" - "))
  }">
${
    imageUrl
      ? `<meta property="og:image" content="${escapeHtml(imageUrl)}">`
      : ""
  }
<meta name="twitter:card" content="summary_large_image">
<style>
  body{margin:0;font-family:-apple-system,BlinkMacSystemFont,system-ui,sans-serif;background:#07101e;color:#fff;display:flex;min-height:100vh;align-items:center;justify-content:center}
  .card{box-sizing:border-box;max-width:420px;width:92%;border:1px solid #26354a;border-radius:8px;padding:28px;background:#111b2b}
  .logo{font-weight:800;font-size:15px;color:#c8f135}.res{font-size:48px;font-weight:900;margin:18px 0 4px}
  .team{color:#b7c2d0;font-size:15px}.head{font-size:20px;font-weight:800;margin:16px 0;line-height:1.3}
  .chips{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:22px}.chip{background:#202e43;border-radius:8px;padding:6px 10px;font-size:12px;font-weight:700}
  a.btn{display:block;text-align:center;text-decoration:none;border-radius:8px;padding:14px;font-weight:800;margin-top:10px}
  .open{background:#c8f135;color:#15200a}.get{border:1px solid #3b4b61;color:#fff}
</style>
</head>
<body>
<main class="card">
  <div class="logo">Momentum</div>
  <div class="res">${escapeHtml(input.result)}</div>
  <div class="team">${escapeHtml(input.team)}</div>
  <div class="head">${escapeHtml(input.headline)}</div>
  <div class="chips">${
    input.chips.map((chip) => `<div class="chip">${escapeHtml(chip)}</div>`)
      .join("")
  }</div>
  <a class="btn open" href="${escapeHtml(deepLink)}">Apri in app</a>
  ${
    storeUrl
      ? `<a class="btn get" rel="noopener noreferrer" href="${
        escapeHtml(storeUrl)
      }">Scarica Momentum</a>`
      : ""
  }
</main>
</body>
</html>`;
}

function selectStoreUrl(
  userAgent: string | null | undefined,
  appStoreUrl: string | null | undefined,
  playStoreUrl: string | null | undefined,
): string | null {
  const isApple = /iPhone|iPad|iPod|Macintosh/i.test(userAgent ?? "");
  const preferred = isApple ? appStoreUrl : playStoreUrl;
  return safeHttpsUrl(preferred);
}

function escapeHtml(value: string): string {
  return value.replace(
    /[&<>"']/g,
    (character) =>
      ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;",
      })[character]!,
  );
}
