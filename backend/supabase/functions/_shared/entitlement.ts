import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export async function hasActiveEntitlement(
  client: SupabaseClient,
  userId: string,
  requiredPlans: readonly string[],
): Promise<boolean> {
  const { data, error } = await client.rpc("has_active_entitlement", {
    p_user_id: userId,
    p_required_plans: [...requiredPlans],
  });
  if (error) throw new Error(`entitlement_lookup_failed:${error.code ?? "db"}`);
  return data === true;
}
