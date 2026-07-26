import { assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import {
  type AssistantProfileGate,
  resolveAssistantAccess,
} from "./assistant_access.ts";

function profile(
  overrides: Partial<AssistantProfileGate> = {},
): AssistantProfileGate {
  return {
    plan: "free",
    account_role: "user",
    premium_override: false,
    assistant_enabled: true,
    assistant_daily_limit: 20,
    assistant_live_limit: 5,
    ...overrides,
  };
}

Deno.test("Free and Plus accounts are not entitled to the AI assistant", () => {
  assertEquals(resolveAssistantAccess(profile(), false).entitled, false);
  assertEquals(
    resolveAssistantAccess(profile({ plan: "plus" }), false).entitled,
    false,
  );
});

Deno.test("premium override grants verified Pro access", () => {
  const access = resolveAssistantAccess(
    profile({ premium_override: true }),
    true,
  );

  assertEquals(access.entitled, true);
  assertEquals(access.effectivePlan, "pro");
  assertEquals(
    access.promptContext.includes("Piano verificato lato server: Pro"),
    true,
  );
});

Deno.test("super admin access is represented as Coach", () => {
  const access = resolveAssistantAccess(
    profile({ plan: "coach", account_role: "super_admin" }),
    true,
  );

  assertEquals(access.entitled, true);
  assertEquals(access.privileged, true);
  assertEquals(access.effectivePlan, "coach");
  assertEquals(
    access.promptContext.includes("Piano verificato lato server: Coach"),
    true,
  );
});

Deno.test("cache scopes differ by plan and test access", () => {
  const free = resolveAssistantAccess(profile(), false);
  const pro = resolveAssistantAccess(profile({ plan: "pro" }), true);
  const test = resolveAssistantAccess(
    profile({ premium_override: true }),
    true,
  );

  assertNotEquals(free.cacheScope, pro.cacheScope);
  assertNotEquals(pro.cacheScope, test.cacheScope);
  assertNotEquals(free.cacheScope, test.cacheScope);
});

Deno.test("an expired stored Pro plan is represented as Free", () => {
  const access = resolveAssistantAccess(profile({ plan: "pro" }), false);

  assertEquals(access.entitled, false);
  assertEquals(access.effectivePlan, "free");
});
