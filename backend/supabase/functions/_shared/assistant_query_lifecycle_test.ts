import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  AssistantQueryPersistenceError,
  persistAssistantQueryMutation,
} from "./assistant_query_lifecycle.ts";

const noWait = () => Promise.resolve();

Deno.test("assistant finalization retries and confirms the persisted state", async () => {
  let attempts = 0;

  await persistAssistantQueryMutation(
    "finalize",
    () => {
      attempts += 1;
      return Promise.resolve(
        attempts === 1
          ? { error: new Error("temporary_postgrest_failure"), settled: false }
          : { error: null, settled: true },
      );
    },
    { baseDelayMs: 1, wait: noWait },
  );

  assertEquals(attempts, 2);
});

Deno.test("repeating assistant finalization with the same payload is idempotent", async () => {
  let persistedAnswer: string | null = null;
  let writes = 0;
  const finalize = () =>
    persistAssistantQueryMutation(
      "finalize",
      () => {
        writes += 1;
        persistedAnswer = "answer";
        return Promise.resolve({
          error: null,
          settled: persistedAnswer === "answer",
        });
      },
      { baseDelayMs: 0 },
    );

  await finalize();
  await finalize();

  assertEquals(persistedAnswer, "answer");
  assertEquals(writes, 2);
});

Deno.test("assistant release retries and treats an already absent row as success", async () => {
  let exists = true;
  let attempts = 0;
  const release = () =>
    persistAssistantQueryMutation(
      "release",
      () => {
        attempts += 1;
        if (attempts === 1) {
          return Promise.resolve({
            error: { message: "temporary_delete_failure" },
            settled: false,
          });
        }
        exists = false;
        return Promise.resolve({ error: null, settled: !exists });
      },
      { baseDelayMs: 1, wait: noWait },
    );

  await release();
  await release();

  assertEquals(exists, false);
  assertEquals(attempts, 3);
});

Deno.test("assistant persistence failure is surfaced after bounded retries", async () => {
  let attempts = 0;

  const error = await assertRejects(
    () =>
      persistAssistantQueryMutation(
        "finalize",
        () => {
          attempts += 1;
          return Promise.resolve({ error: null, settled: false });
        },
        { maxAttempts: 3, baseDelayMs: 1, wait: noWait },
      ),
    AssistantQueryPersistenceError,
    "state_not_confirmed",
  );

  assertEquals(attempts, 3);
  assertEquals(error.operation, "finalize");
  assertEquals(error.attempts, 3);
});
