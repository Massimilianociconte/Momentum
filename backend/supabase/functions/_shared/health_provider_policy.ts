export type HealthProviderAction =
  | "status"
  | "authorize"
  | "sync"
  | "disconnect";

export type HealthProviderActionPolicy = {
  requiresActiveRollout: boolean;
  requiresPremium: boolean;
};

export function healthProviderActionPolicy(
  value: string,
): HealthProviderActionPolicy | null {
  if (value === "status" || value === "disconnect") {
    return { requiresActiveRollout: false, requiresPremium: false };
  }
  if (value === "authorize" || value === "sync") {
    return { requiresActiveRollout: true, requiresPremium: true };
  }
  return null;
}
