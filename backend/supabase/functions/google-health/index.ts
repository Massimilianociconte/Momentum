// Premium Google Health API integration for Fitbit Air/Fitbit/Pixel data.
// OAuth and token refresh always happen server-side. Deploy with
// --no-verify-jwt because Google's GET callback cannot carry a Supabase JWT;
// every mobile POST action still verifies the caller manually.

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  exchangeAuthorizationCode,
  fetchAndStoreDailySummary,
  GOOGLE_HEALTH_PROVIDER,
  GOOGLE_HEALTH_SCOPES,
  googleHealthIdentity,
  requiredEnv,
  revokeGoogleHealth,
  saveGoogleTokens,
  sha256,
} from "../_shared/google_health.ts";
import { hasActiveEntitlement } from "../_shared/entitlement.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);
const MAX_BODY_BYTES = 16 * 1024;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return cors(new Response(null, { status: 204 }), req);
  }
  const url = new URL(req.url);
  if (req.method === "GET") return oauthCallback(url);
  if (req.method !== "POST") {
    return respond(req, { error: "method_not_allowed" }, 405);
  }

  const body = await readJson(req);
  if (!body) return respond(req, { error: "invalid_request" }, 400);
  const user = await authenticatedUser(req);
  if (!user) return respond(req, { error: "unauthorized" }, 401);
  const action = string(body.action, 32);

  try {
    if (action === "status") return status(req, user.id);
    if (!await hasPremiumAccess(user.id)) {
      return respond(req, { error: "plan_required", requiredPlan: "pro" }, 403);
    }
    switch (action) {
      case "authorize":
        return authorize(req, user.id);
      case "today":
        return today(req, body, user.id);
      case "disconnect":
        await revokeGoogleHealth(admin, user.id);
        return respond(req, { disconnected: true });
      default:
        return respond(req, { error: "unknown_action" }, 400);
    }
  } catch (error) {
    const code = safeError(error);
    console.error("google-health", action, code);
    if (code.includes("reconnect_required") || code.includes("not_connected")) {
      return respond(req, { error: "reconnect_required" }, 401);
    }
    if (code.includes("invalid_local_date")) {
      return respond(req, { error: "invalid_local_date" }, 400);
    }
    if (code.startsWith("missing_")) {
      return respond(req, { error: "server_not_configured" }, 503);
    }
    return respond(req, { error: "temporarily_unavailable" }, 503);
  }
});

async function authorize(req: Request, userId: string) {
  const clientId = requiredEnv("GOOGLE_HEALTH_CLIENT_ID");
  const redirectUri = requiredEnv("GOOGLE_HEALTH_REDIRECT_URI");
  requiredEnv("GOOGLE_HEALTH_CLIENT_SECRET");
  requiredEnv("WEARABLE_TOKEN_ENCRYPTION_KEY");

  const state = randomToken(32);
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
  const { error } = await admin.from("wearable_oauth_states").insert({
    state_hash: await sha256(state),
    user_id: userId,
    provider: GOOGLE_HEALTH_PROVIDER,
    redirect_after: "rallymate://devices/google-health",
    expires_at: expiresAt,
  });
  if (error) throw error;

  const query = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUri,
    response_type: "code",
    access_type: "offline",
    prompt: "consent",
    include_granted_scopes: "true",
    scope: GOOGLE_HEALTH_SCOPES.join(" "),
    state,
  });
  return respond(req, {
    authorizationUrl: `https://accounts.google.com/o/oauth2/v2/auth?${query}`,
    expiresAt,
  });
}

async function oauthCallback(url: URL) {
  const state = url.searchParams.get("state")?.trim() ?? "";
  const code = url.searchParams.get("code")?.trim() ?? "";
  const providerError = url.searchParams.get("error")?.trim() ?? "";
  if (!state || (!code && !providerError)) {
    return callbackPage("Collegamento non valido", false);
  }
  try {
    const { data, error } = await admin.rpc("consume_wearable_oauth_state", {
      p_state_hash: await sha256(state),
    });
    const claimed = Array.isArray(data) ? data[0] : null;
    if (error || !claimed?.user_id) {
      return callbackPage(
        "Questo collegamento è scaduto o è già stato usato",
        false,
      );
    }
    if (providerError) {
      await admin.from("wearable_provider_connections").upsert({
        user_id: claimed.user_id,
        provider: GOOGLE_HEALTH_PROVIDER,
        status: "ERROR",
        last_error_code: `oauth_${providerError.slice(0, 50)}`,
        updated_at: new Date().toISOString(),
      }, { onConflict: "user_id,provider" });
      return callbackPage(
        "Consenso annullato. Nessun dato è stato collegato",
        false,
      );
    }
    const tokens = await exchangeAuthorizationCode(code);
    const subject = await googleHealthIdentity(tokens.access_token);
    await saveGoogleTokens(admin, claimed.user_id, tokens, subject);
    return callbackPage("Google Health è collegato a Padelandia", true);
  } catch (error) {
    console.error("google-health callback", safeError(error));
    return callbackPage(
      "Collegamento non riuscito. Torna in Padelandia e riprova",
      false,
    );
  }
}

async function today(
  req: Request,
  body: Record<string, unknown>,
  userId: string,
) {
  const localDate = string(body.localDate, 10);
  const timezone = string(body.timezone, 80);
  if (!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(localDate) || !timezone) {
    return respond(req, { error: "invalid_local_date" }, 400);
  }
  const summary = await fetchAndStoreDailySummary(
    admin,
    userId,
    localDate,
    timezone,
  );
  return respond(req, { summary });
}

async function status(req: Request, userId: string) {
  const { data, error } = await admin.from("wearable_provider_connections")
    .select("status,scopes,consented_at,last_sync_at,last_error_code")
    .eq("user_id", userId)
    .eq("provider", GOOGLE_HEALTH_PROVIDER)
    .maybeSingle();
  if (error) throw error;
  return respond(req, {
    connected: data?.status === "CONNECTED",
    status: data?.status ?? "DISCONNECTED",
    scopes: data?.scopes ?? [],
    consentedAt: data?.consented_at ?? null,
    lastSyncAt: data?.last_sync_at ?? null,
    needsReconnect: data?.status === "REFRESH_REQUIRED",
  });
}

async function authenticatedUser(req: Request) {
  const jwt = (req.headers.get("authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  if (!jwt) return null;
  const { data, error } = await admin.auth.getUser(jwt);
  return error ? null : data.user;
}

function hasPremiumAccess(userId: string) {
  return hasActiveEntitlement(admin, userId, ["plus", "pro", "coach"]);
}

async function readJson(req: Request): Promise<Record<string, unknown> | null> {
  const declared = Number(req.headers.get("content-length") ?? 0);
  if (declared > MAX_BODY_BYTES) return null;
  const textBody = await req.text();
  if (new TextEncoder().encode(textBody).byteLength > MAX_BODY_BYTES) {
    return null;
  }
  try {
    const value = JSON.parse(textBody);
    return value && typeof value === "object" && !Array.isArray(value)
      ? value as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

function callbackPage(message: string, success: boolean) {
  const escaped = message.replace(/[&<>"']/g, (value) =>
    ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    })[value]!);
  const status = success
    ? "Collegamento completato"
    : "Collegamento non completato";
  const color = success ? "#C8F135" : "#FFB74D";
  const destination = success
    ? "rallymate://devices/google-health?result=connected"
    : "rallymate://devices/google-health?result=error";
  const html = `<!doctype html><html lang="it"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'">
<title>${status}</title><style>body{margin:0;background:#07101f;color:#fff;font-family:-apple-system,system-ui,sans-serif;display:grid;place-items:center;min-height:100vh}main{max-width:420px;padding:32px;text-align:center}.dot{width:64px;height:64px;border-radius:50%;display:grid;place-items:center;margin:0 auto 22px;background:${color};color:#07101f;font-size:32px;font-weight:900}h1{font-size:24px}p{color:#aeb8c8;line-height:1.5}a{display:inline-block;margin-top:18px;padding:14px 20px;border-radius:8px;background:${color};color:#07101f;text-decoration:none;font-weight:800}</style></head>
<body><main><div class="dot">${
    success ? "✓" : "!"
  }</div><h1>${status}</h1><p>${escaped}</p><a href="${destination}">Torna a Padelandia</a></main>
<script>setTimeout(function(){location.href=${
    JSON.stringify(destination)
  }},900)</script></body></html>`;
  return new Response(html, {
    status: success ? 200 : 400,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      "referrer-policy": "no-referrer",
    },
  });
}

function randomToken(size: number) {
  const bytes = crypto.getRandomValues(new Uint8Array(size));
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function string(value: unknown, max: number) {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

function safeError(error: unknown) {
  return error instanceof Error ? error.message.slice(0, 300) : "unknown";
}

function respond(req: Request, body: unknown, status = 200) {
  return cors(
    new Response(JSON.stringify(body), {
      status,
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": "no-store",
        "x-content-type-options": "nosniff",
      },
    }),
    req,
  );
}

function cors(response: Response, req: Request) {
  const allowed = (Deno.env.get("RALLYMATE_ALLOWED_ORIGINS") ?? "")
    .split(",").map((value) => value.trim()).filter(Boolean);
  const origin = req.headers.get("origin");
  if (origin && allowed.includes(origin)) {
    response.headers.set("access-control-allow-origin", origin);
    response.headers.set("vary", "origin");
  }
  response.headers.set(
    "access-control-allow-headers",
    "authorization, content-type",
  );
  response.headers.set("access-control-allow-methods", "GET, POST, OPTIONS");
  return response;
}
