import { assertEquals } from "jsr:@std/assert@1";
import { healthProviderActionPolicy } from "./health_provider_policy.ts";

Deno.test("disconnect remains available after downgrade or provider shutdown", () => {
  assertEquals(healthProviderActionPolicy("disconnect"), {
    requiresActiveRollout: false,
    requiresPremium: false,
  });
  assertEquals(healthProviderActionPolicy("status"), {
    requiresActiveRollout: false,
    requiresPremium: false,
  });
});

Deno.test("only authorize and sync require rollout plus Premium", () => {
  for (const action of ["authorize", "sync"]) {
    assertEquals(healthProviderActionPolicy(action), {
      requiresActiveRollout: true,
      requiresPremium: true,
    });
  }
  assertEquals(healthProviderActionPolicy("unknown"), null);
});
