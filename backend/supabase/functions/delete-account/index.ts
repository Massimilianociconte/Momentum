// Edge function: eliminazione account (requisito Google Play "Account
// deletion" e Apple App Review 5.1.1(v)).
//
//   GET  /delete-account          → pagina web con istruzioni (l'URL da
//                                   inserire nel Play Console / App Store)
//   POST /delete-account          → elimina DEFINITIVAMENTE l'account del
//                                   chiamante (richiede JWT utente valido)
//
// Deploy: supabase functions deploy delete-account --no-verify-jwt
// (il JWT è verificato manualmente sul POST; il GET è pubblico)
//
// La cancellazione di auth.users propaga a cascata sui dati personali. Gli
// acquisti coach restano come record contabili pseudonimizzati: le FK verso
// player/coach/package vengono scollegate e le assegnazioni vengono eliminate.
// I dati locali sul dispositivo NON sono toccati: restano dell'utente.

import { createClient } from "npm:@supabase/supabase-js@2";
import { revokeGoogleHealth } from "../_shared/google_health.ts";
import { disconnectProvider } from "../_shared/health_cloud_provider.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const supportEmail = (Deno.env.get("SUPPORT_EMAIL") ?? "").trim();
const publicSupportCard =
  /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i.test(supportEmail)
    ? `<div class="card">
<h2>Senza accesso all'app?</h2>
<p>Scrivi a <a href="mailto:${encodeURIComponent(supportEmail)}">${
      escapeHtml(supportEmail)
    }</a>
dall'indirizzo email dell'account chiedendo l'eliminazione: completiamo la
richiesta entro 30 giorni (art. 17 GDPR).</p>
</div>`
    : `<div class="card">
<h2>Senza accesso all'app?</h2>
<p>Consulta il <a href="https://padelandia.app/supporto/">centro supporto
Padelandia</a> per il recapito ufficiale e la procedura aggiornata. Non inviare
password o codici di accesso.</p>
</div>`;

const PAGE = `<!doctype html>
<html lang="it"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Padelandia — Eliminazione account</title>
<style>
body{font-family:-apple-system,Segoe UI,Roboto,sans-serif;background:#0C1220;
color:#E8EEF6;max-width:640px;margin:0 auto;padding:32px 20px;line-height:1.6}
h1{font-size:26px} h2{font-size:18px;margin-top:28px}
.card{background:#16202F;border:1px solid rgba(255,255,255,.08);
border-radius:16px;padding:20px;margin:16px 0}
a{color:#C8F135} li{margin:6px 0} .muted{color:#93A1B5;font-size:14px}
</style></head><body>
<h1>🎾 Padelandia — Eliminazione account e dati</h1>
<div class="card">
<h2>Come eliminare l'account dall'app (consigliato)</h2>
<ol>
<li>Apri Padelandia e vai su <b>Profilo → Gestisci account</b>.</li>
<li>Tocca <b>Elimina account</b> nella sezione Sessione.</li>
<li>Conferma: l'account e i dati cloud vengono eliminati subito e in modo
definitivo.</li>
</ol>
</div>
<div class="card">
<h2>Cosa viene eliminato</h2>
<ul>
<li>Account (email e credenziali di accesso)</li>
<li>Profilo base sincronizzato (nome, nickname, livello, ruolo, preferenze)</li>
<li>Backup cloud (piano Plus/Pro)</li>
<li>Richieste social, inviti, proposte partita, card Wrapped pubblicate</li>
<li>Team cloud e relative immagini private</li>
<li>Dati coach (profilo, pacchetti e schede assegnate) se presenti</li>
</ul>
<p class="muted">I dati salvati SOLO sul tuo dispositivo (partite, statistiche,
allenamenti) non transitano dai nostri server: puoi rimuoverli disinstallando
l'app. Le ricevute presso Apple/Google e RevenueCat e i record contabili
minimi pseudonimizzati possono essere conservati per obblighi fiscali,
contestazioni e antifrode; gli abbonamenti si disdicono da App Store /
Google Play.</p>
</div>
${publicSupportCard}
</body></html>`;

Deno.serve(async (req) => {
  if (req.method === "GET") {
    return new Response(PAGE, {
      headers: { "content-type": "text/html; charset=utf-8" },
    });
  }
  if (req.method !== "POST") return new Response(null, { status: 405 });

  // Autentica il chiamante col suo JWT: può eliminare SOLO se stesso.
  const jwt = (req.headers.get("authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  if (!jwt) return json({ error: "unauthorized" }, 401);
  const { data: userData, error: userError } = await admin.auth.getUser(jwt);
  const user = userData?.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  // Storage objects are not removed by PostgreSQL FK cascades. Resolve paths
  // from owner-scoped team rows and delete them before deleting auth.users, so
  // a transient Storage failure never leaves inaccessible personal media.
  const { data: teams, error: teamsError } = await admin
    .from("teams")
    .select("avatar_path")
    .eq("owner_id", user.id)
    .not("avatar_path", "is", null);
  if (teamsError) {
    console.error("delete-account team lookup failed", teamsError.message);
    return json({ error: "delete_temporarily_unavailable" }, 503);
  }
  const avatarPaths = [
    ...new Set(
      (teams ?? [])
        .map((row) => row.avatar_path as string | null)
        .filter((path): path is string =>
          typeof path === "string" && path.startsWith(`${user.id}/`)
        ),
    ),
  ];
  for (let start = 0; start < avatarPaths.length; start += 100) {
    const { error: storageError } = await admin.storage
      .from("team-avatars")
      .remove(avatarPaths.slice(start, start + 100));
    if (storageError) {
      console.error(
        "delete-account storage cleanup failed",
        storageError.message,
      );
      return json({ error: "delete_temporarily_unavailable" }, 503);
    }
  }

  // Profile avatars live under {user_id}/... and are not cascaded by auth delete.
  const profilePaths = [
    `${user.id}/avatar.jpg`,
    `${user.id}/avatar.jpeg`,
    `${user.id}/avatar.png`,
    `${user.id}/avatar.webp`,
  ];
  {
    const { error: profileStorageError } = await admin.storage
      .from("profile-avatars")
      .remove(profilePaths);
    if (profileStorageError) {
      // Listing may fail if the prefix is empty; try list+remove as fallback.
      const { data: listed, error: listError } = await admin.storage
        .from("profile-avatars")
        .list(user.id, { limit: 100 });
      if (listError) {
        console.error(
          "delete-account profile avatar cleanup failed",
          profileStorageError.message,
        );
        return json({ error: "delete_temporarily_unavailable" }, 503);
      }
      const paths = (listed ?? [])
        .map((entry) => `${user.id}/${entry.name}`)
        .filter((path) => path.length > user.id.length + 1);
      if (paths.length > 0) {
        const { error: removeError } = await admin.storage
          .from("profile-avatars")
          .remove(paths);
        if (removeError) {
          console.error(
            "delete-account profile avatar remove failed",
            removeError.message,
          );
          return json({ error: "delete_temporarily_unavailable" }, 503);
        }
      }
    }
  }

  // Provider tokens are not useful after account deletion and should be
  // revoked upstream where possible before the database cascade removes the
  // encrypted connection row. Local token material is wiped even if Google
  // has already invalidated consent or its revoke endpoint is unavailable.
  try {
    await revokeGoogleHealth(admin, user.id);
    await disconnectProvider(admin, user.id, "OURA_DIRECT");
    await disconnectProvider(admin, user.id, "WHOOP_DIRECT");
  } catch (providerError) {
    console.error(
      "delete-account Google Health cleanup failed",
      providerError instanceof Error ? providerError.message : "unknown",
    );
    return json({ error: "delete_temporarily_unavailable" }, 503);
  }

  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) {
    console.error("delete-account failed", user.id, error.message);
    return json({ error: "delete_failed" }, 500);
  }
  return json({ deleted: true });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function escapeHtml(value: string) {
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
