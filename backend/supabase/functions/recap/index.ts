// Edge function: pagina pubblica "Rally Wrapped" (PRD G5).
//
//   GET /recap?slug=abc123
//
// Ritorna una pagina HTML leggerissima (zero framework, <8KB) con la card,
// il pulsante "Apri in app" (deep link) e "Scarica app". Rispetta la privacy
// della card e incrementa view_count. Serve anche i social crawler
// (og:image) per l'anteprima su WhatsApp/Instagram/Telegram.

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  buildRecapPage,
  isValidRecapSlug,
  RECAP_SECURITY_HEADERS,
} from "./_page.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const slug = url.searchParams.get("slug") ?? url.pathname.split("/").pop();
  if (!slug || !isValidRecapSlug(slug)) {
    return new Response("Not found", { status: 404 });
  }

  const { data: card, error } = await supabase
    .from("wrapped_cards")
    .select("card_id, type, payload, image_url, privacy")
    .eq("slug", slug)
    .maybeSingle();

  if (error || !card || card.privacy === "PRIVATE") {
    return new Response("Not found", { status: 404 });
  }

  // Fire-and-forget view counter (non blocca la risposta).
  supabase
    .rpc("increment_card_views", { p_card_id: card.card_id })
    .then(() => {});

  const p = card.payload as Record<string, unknown>;
  const headline = String(p.headline ?? "La mia partita di padel");
  const result = String(p.resultLine ?? "");
  const team = String(p.teamLabel ?? "");
  const clutch = p.clutchScore != null ? `Clutch ${p.clutchScore}/100` : "";
  const streak = p.bestStreak != null ? `Streak ${p.bestStreak}` : "";
  const points = p.totalPoints != null ? `${p.totalPoints} punti` : "";
  const chips = [points, streak, clutch].filter(Boolean);

  const html = buildRecapPage({
    slug,
    headline,
    result,
    team,
    chips,
    imageUrl: card.image_url,
    userAgent: req.headers.get("user-agent"),
    appStoreUrl: Deno.env.get("RALLYMATE_APP_STORE_URL"),
    playStoreUrl: Deno.env.get("RALLYMATE_PLAY_STORE_URL"),
  });

  return new Response(html, {
    headers: RECAP_SECURITY_HEADERS,
  });
});
