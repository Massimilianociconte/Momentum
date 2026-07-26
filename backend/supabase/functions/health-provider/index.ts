// Direct Oura/WHOOP health integration. The function intentionally runs with
// gateway JWT verification disabled because provider OAuth callbacks cannot
// carry a Supabase token. Every mobile POST action authenticates manually.

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  assertProviderRollout,
  buildAuthorizationUrl,
  type DirectHealthProvider,
  disconnectProvider,
  exchangeAuthorizationCode,
  randomToken,
  readProviderStatus,
  requiredEnv,
  saveProviderTokens,
  sha256,
} from "../_shared/health_cloud_provider.ts";
import {
  syncOuraRange,
  syncWhoopRange,
  whoopSubject,
} from "../_shared/direct_health_sync.ts";
import { healthProviderActionPolicy } from "../_shared/health_provider_policy.ts";
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
  const provider = parseProvider(body.provider);
  const action = string(body.action, 32);
  const policy = healthProviderActionPolicy(action);
  if (!provider || !action || !policy) {
    return respond(req, { error: "invalid_request" }, 400);
  }

  try {
    if (action === "status") {
      return respond(req, await readProviderStatus(admin, user.id, provider));
    }
    if (policy.requiresActiveRollout) {
      await assertProviderRollout(admin, provider);
    }
    if (policy.requiresPremium && !await hasPremiumAccess(user.id)) {
      return respond(
        req,
        { error: "plan_required", requiredPlan: "plus" },
        403,
      );
    }
    if (action === "authorize") return authorize(req, user.id, provider);
    if (action === "sync") return sync(req, body, user.id, provider);
    if (action === "disconnect") {
      await disconnectProvider(admin, user.id, provider);
      return respond(req, { disconnected: true });
    }
    return respond(req, { error: "invalid_request" }, 400);
  } catch (error) {
    const code = safeError(error);
    console.error("health-provider", provider, action, code);
    if (code.includes("provider_not_enabled")) {
      return respond(req, { error: "provider_not_available" }, 409);
    }
    if (code.includes("not_connected") || code.includes("reconnect_required")) {
      return respond(req, { error: "reconnect_required" }, 401);
    }
    if (code.includes("invalid_date_range")) {
      return respond(req, { error: "invalid_date_range" }, 400);
    }
    if (code.startsWith("missing_") || code.includes("encryption_key")) {
      return respond(req, { error: "server_not_configured" }, 503);
    }
    return respond(req, { error: "temporarily_unavailable" }, 503);
  }
});

async function authorize(
  req: Request,
  userId: string,
  provider: DirectHealthProvider,
) {
  const configName = provider === "OURA_DIRECT" ? "OURA" : "WHOOP";
  requiredEnv(`${configName}_CLIENT_ID`);
  requiredEnv(`${configName}_CLIENT_SECRET`);
  requiredEnv(`${configName}_REDIRECT_URI`);
  requiredEnv("WEARABLE_TOKEN_ENCRYPTION_KEY");
  const state = randomToken(32);
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
  const { error: staleStateError } = await admin.from("wearable_oauth_states")
    .delete()
    .eq("user_id", userId).eq("provider", provider).is("consumed_at", null);
  if (staleStateError) throw staleStateError;
  const { error } = await admin.from("wearable_oauth_states").insert({
    state_hash: await sha256(state),
    user_id: userId,
    provider,
    redirect_after: `rallymate://devices/health/${provider.toLowerCase()}`,
    expires_at: expiresAt,
  });
  if (error) throw error;
  return respond(req, {
    authorizationUrl: buildAuthorizationUrl(provider, state),
    expiresAt,
  });
}

async function oauthCallback(url: URL) {
  const provider = callbackProvider(url.pathname);
  const state = url.searchParams.get("state")?.trim() ?? "";
  const code = url.searchParams.get("code")?.trim() ?? "";
  const providerError = url.searchParams.get("error")?.trim() ?? "";
  if (!provider || !state || (!code && !providerError)) {
    return callbackPage(null, "Collegamento non valido", false);
  }
  try {
    await assertProviderRollout(admin, provider);
    const { data, error } = await admin.rpc("consume_health_oauth_state", {
      p_state_hash: await sha256(state),
      p_provider: provider,
    });
    const claimed = Array.isArray(data) ? data[0] : null;
    if (error || !claimed?.user_id) {
      return callbackPage(
        provider,
        "Questo collegamento è scaduto o è già stato usato",
        false,
      );
    }
    if (providerError) {
      const { error: connectionError } = await admin.from(
        "wearable_provider_connections",
      ).upsert({
        user_id: claimed.user_id,
        provider,
        status: "ERROR",
        connection_type: "CLOUD_OAUTH",
        support_status: "INTERNAL",
        last_error_code: `oauth_${providerError.slice(0, 50)}`,
        updated_at: new Date().toISOString(),
      }, { onConflict: "user_id,provider" });
      if (connectionError) throw connectionError;
      return callbackPage(
        provider,
        "Consenso annullato. Nessun dato è stato collegato",
        false,
      );
    }
    const tokens = await exchangeAuthorizationCode(provider, code);
    const subject = provider === "WHOOP_DIRECT"
      ? await whoopSubject(tokens.access_token)
      : undefined;
    await saveProviderTokens(admin, claimed.user_id, provider, tokens, subject);
    return callbackPage(
      provider,
      `${providerName(provider)} è collegato`,
      true,
    );
  } catch (error) {
    console.error("health-provider callback", provider, safeError(error));
    return callbackPage(
      provider,
      "Collegamento non riuscito. Torna in Padelandia e riprova",
      false,
    );
  }
}

async function sync(
  req: Request,
  body: Record<string, unknown>,
  userId: string,
  provider: DirectHealthProvider,
) {
  const end = parseDate(body.endDate) ?? new Date();
  const start = parseDate(body.startDate) ??
    new Date(end.getTime() - 7 * 864e5);
  if (end < start || end.getTime() - start.getTime() > 31 * 864e5) {
    return respond(req, { error: "invalid_date_range" }, 400);
  }
  const lastSync = await admin.from("wearable_provider_connections")
    .select("last_sync_at").eq("user_id", userId).eq("provider", provider)
    .maybeSingle();
  if (lastSync.error) throw lastSync.error;
  if (
    lastSync.data?.last_sync_at &&
    Date.now() - Date.parse(lastSync.data.last_sync_at) < 60_000
  ) {
    return respond(
      req,
      { error: "sync_too_frequent", retryAfterSeconds: 60 },
      429,
    );
  }
  const result = provider === "OURA_DIRECT"
    ? await syncOuraRange(admin, userId, isoDay(start), isoDay(end))
    : await syncWhoopRange(
      admin,
      userId,
      start.toISOString(),
      end.toISOString(),
    );
  return respond(req, { result, syncedAt: new Date().toISOString() });
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

function callbackProvider(pathname: string): DirectHealthProvider | null {
  const normalized = pathname.toLowerCase();
  if (normalized.includes("/oura/")) return "OURA_DIRECT";
  if (normalized.includes("/whoop/")) return "WHOOP_DIRECT";
  return null;
}

function parseProvider(value: unknown): DirectHealthProvider | null {
  return value === "OURA_DIRECT" || value === "WHOOP_DIRECT" ? value : null;
}

function parseDate(value: unknown) {
  if (typeof value !== "string" || value.length > 40) return null;
  const parsed = new Date(value);
  return Number.isFinite(parsed.getTime()) ? parsed : null;
}

function isoDay(value: Date) {
  return value.toISOString().slice(0, 10);
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

function callbackPage(
  provider: DirectHealthProvider | null,
  message: string,
  success: boolean,
) {
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
  const path = provider?.toLowerCase() ?? "provider";
  const destination = `rallymate://devices/health/${path}?result=${
    success ? "connected" : "error"
  }`;
  const html = `<!doctype html><html lang="it"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'">
<title>${status}</title><style>body{margin:0;background:#0c1220;color:#fff;font-family:-apple-system,system-ui,sans-serif;display:grid;place-items:center;min-height:100vh}main{max-width:420px;padding:32px;text-align:center}.dot{width:64px;height:64px;border-radius:50%;display:grid;place-items:center;margin:0 auto 22px;background:${color};color:#07101f;font-size:32px;font-weight:900}h1{font-size:24px}p{color:#aeb8c8;line-height:1.5}a{display:inline-block;margin-top:18px;padding:14px 20px;border-radius:8px;background:${color};color:#07101f;text-decoration:none;font-weight:800}</style></head>
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

function providerName(provider: DirectHealthProvider) {
  return provider === "OURA_DIRECT" ? "Oura" : "WHOOP";
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
