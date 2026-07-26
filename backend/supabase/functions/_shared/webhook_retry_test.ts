import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { processPendingWebhook } from "./webhook_retry.ts";

Deno.test("failed webhook remains pending and the same id succeeds on retry", async () => {
  const state: {
    processedAt: string | null;
    attempts: number;
    failures: number;
  } = { processedAt: null, attempts: 0, failures: 0 };

  const deliver = () =>
    processPendingWebhook({
      processedAt: state.processedAt,
      process: () => {
        state.attempts += 1;
        return state.attempts === 1
          ? Promise.reject(new Error("provider_unavailable"))
          : Promise.resolve();
      },
      markProcessed: () => {
        state.processedAt = "2026-07-18T12:00:00.000Z";
        return Promise.resolve();
      },
      markFailed: () => {
        state.failures += 1;
        return Promise.resolve();
      },
    });

  await assertRejects(deliver, Error, "provider_unavailable");
  assertEquals(state.processedAt, null);
  assertEquals(state.failures, 1);

  assertEquals(await deliver(), "processed");
  assertEquals(state.attempts, 2);
  assertEquals(await deliver(), "already_processed");
  assertEquals(state.attempts, 2);
});
