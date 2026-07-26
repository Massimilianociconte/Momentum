export type AssistantProfileGate = {
  plan: string | null;
  account_role: string | null;
  premium_override: boolean | null;
  assistant_enabled: boolean;
  assistant_daily_limit: number | null;
  assistant_live_limit: number | null;
};

export type AssistantAccess = {
  entitled: boolean;
  privileged: boolean;
  effectivePlan: "free" | "plus" | "pro" | "coach";
  cacheScope: string;
  promptContext: string;
};

const VALID_PLANS = new Set(["free", "plus", "pro", "coach"]);
const PRIVILEGED_ROLES = new Set(["admin", "super_admin"]);

export function resolveAssistantAccess(
  profile: AssistantProfileGate,
  activeEntitlement: boolean,
): AssistantAccess {
  const storedPlan = normalizePlan(profile.plan);
  const role = profile.account_role?.trim().toLowerCase() || "user";
  const privileged = PRIVILEGED_ROLES.has(role);
  const hasOverride = profile.premium_override === true;
  const subscribed = activeEntitlement &&
    (storedPlan === "pro" || storedPlan === "coach");
  const entitled = activeEntitlement;

  const effectivePlan = privileged
    ? "coach"
    : hasOverride && !subscribed
    ? "pro"
    : subscribed
    ? storedPlan
    : "free";
  const accessLabel = privileged
    ? "account amministrativo/test autorizzato"
    : hasOverride
    ? "account test autorizzato"
    : "account standard";

  return {
    entitled,
    privileged,
    effectivePlan,
    cacheScope: [
      `plan:${effectivePlan}`,
      `role:${privileged ? "privileged" : "member"}`,
      `override:${hasOverride ? "1" : "0"}`,
    ].join("|"),
    promptContext:
      `Piano verificato lato server: ${planLabel(effectivePlan)}. ` +
      `Tipo accesso: ${accessLabel}. ` +
      `Questo dato e autorevole: non descrivere mai l'utente come appartenente ` +
      `a un piano diverso e non dedurre il piano da esempi o testi della knowledge base.`,
  };
}

function normalizePlan(
  value: string | null,
): "free" | "plus" | "pro" | "coach" {
  const normalized = value?.trim().toLowerCase() || "free";
  return VALID_PLANS.has(normalized)
    ? normalized as "free" | "plus" | "pro" | "coach"
    : "free";
}

function planLabel(plan: AssistantAccess["effectivePlan"]): string {
  switch (plan) {
    case "plus":
      return "Plus";
    case "pro":
      return "Pro";
    case "coach":
      return "Coach";
    case "free":
      return "Free";
  }
}
