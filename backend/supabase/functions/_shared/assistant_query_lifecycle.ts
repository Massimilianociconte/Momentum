export type AssistantQueryMutation = "finalize" | "release";

export type AssistantQueryMutationAttempt = {
  error?: unknown;
  settled: boolean;
};

export class AssistantQueryPersistenceError extends Error {
  readonly operation: AssistantQueryMutation;
  readonly attempts: number;

  constructor(
    operation: AssistantQueryMutation,
    attempts: number,
    detail: string,
  ) {
    super(`assistant_query_${operation}_failed:${detail}`);
    this.name = "AssistantQueryPersistenceError";
    this.operation = operation;
    this.attempts = attempts;
  }
}

type RetryOptions = {
  maxAttempts?: number;
  baseDelayMs?: number;
  wait?: (delayMs: number) => Promise<void>;
};

/**
 * Repeats an idempotent assistant-query mutation until its desired state is
 * confirmed. Callers must make `attempt` safe to repeat: finalization writes
 * the same payload, while release treats an already-absent row as success.
 */
export async function persistAssistantQueryMutation(
  operation: AssistantQueryMutation,
  attempt: () => Promise<AssistantQueryMutationAttempt>,
  options: RetryOptions = {},
): Promise<void> {
  const maxAttempts = Math.max(1, options.maxAttempts ?? 3);
  const baseDelayMs = Math.max(0, options.baseDelayMs ?? 50);
  const wait = options.wait ??
    ((delayMs: number) =>
      new Promise<void>((resolve) => setTimeout(resolve, delayMs)));
  let lastDetail = "state_not_confirmed";

  for (let attemptNumber = 1; attemptNumber <= maxAttempts; attemptNumber++) {
    try {
      const result = await attempt();
      if (!result.error && result.settled) return;
      lastDetail = result.error
        ? errorDetail(result.error)
        : "state_not_confirmed";
    } catch (error) {
      lastDetail = errorDetail(error);
    }

    if (attemptNumber < maxAttempts && baseDelayMs > 0) {
      await wait(baseDelayMs * 2 ** (attemptNumber - 1));
    }
  }

  throw new AssistantQueryPersistenceError(
    operation,
    maxAttempts,
    lastDetail,
  );
}

function errorDetail(error: unknown): string {
  if (error instanceof Error) return sanitize(error.message);
  if (
    typeof error === "object" && error !== null && "message" in error &&
    typeof error.message === "string"
  ) {
    return sanitize(error.message);
  }
  return "unknown";
}

function sanitize(message: string): string {
  return message.replaceAll(/\s+/g, " ").trim().slice(0, 180) || "unknown";
}
