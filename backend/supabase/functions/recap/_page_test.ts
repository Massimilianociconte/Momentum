import { buildRecapPage, isValidRecapSlug, safeHttpsUrl } from "./_page.ts";

Deno.test("recap slug accepts opaque public identifiers only", () => {
  if (!isValidRecapSlug("Abc_123-test")) throw new Error("valid slug rejected");
  if (isValidRecapSlug("../../admin")) throw new Error("path slug accepted");
  if (isValidRecapSlug("tiny")) throw new Error("short slug accepted");
});

Deno.test("recap URLs require credential-free HTTPS", () => {
  if (safeHttpsUrl("http://example.com/a") !== null) {
    throw new Error("HTTP accepted");
  }
  if (safeHttpsUrl("https://user:pass@example.com/a") !== null) {
    throw new Error("embedded credentials accepted");
  }
  if (safeHttpsUrl("https://cdn.example.com/a.png") === null) {
    throw new Error("valid HTTPS rejected");
  }
});

Deno.test("recap page escapes content and contains no executable script", () => {
  const html = buildRecapPage({
    slug: "safe_token_123",
    headline: '"><script>alert(1)</script>',
    result: "6-4",
    team: "Rally & Mate",
    chips: ["12 < 20"],
    imageUrl: 'https://cdn.example.com/x.png" onerror="alert(1)',
    userAgent: "iPhone",
    appStoreUrl: "https://apps.apple.com/app/id123456789",
    playStoreUrl: "https://play.google.com/store/apps/details?id=example",
  });

  if (html.includes("<script")) throw new Error("script tag emitted");
  if (html.includes("onerror=")) throw new Error("unsafe image emitted");
  if (!html.includes("&lt;script&gt;")) throw new Error("headline not escaped");
  if (!html.includes("apps.apple.com")) {
    throw new Error("iOS store not selected");
  }
  if (html.includes("play.google.com")) throw new Error("wrong store emitted");
});

Deno.test("recap omits store CTA until a real URL is configured", () => {
  const html = buildRecapPage({
    slug: "safe_token_123",
    headline: "Partita",
    result: "6-4",
    team: "Team",
    chips: [],
  });
  if (html.includes("Scarica Momentum")) {
    throw new Error("unconfigured store CTA emitted");
  }
});
