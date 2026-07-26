export type WebhookProcessingOutcome = "already_processed" | "processed";

export async function processPendingWebhook(args: {
  processedAt: string | null | undefined;
  process(): Promise<void>;
  markProcessed(): Promise<void>;
  markFailed?(error: unknown): Promise<void>;
}): Promise<WebhookProcessingOutcome> {
  if (args.processedAt) return "already_processed";

  try {
    await args.process();
    await args.markProcessed();
    return "processed";
  } catch (error) {
    if (args.markFailed) {
      try {
        await args.markFailed(error);
      } catch {
        // Preserve the processing failure. The provider receives a non-2xx
        // response and retries even if recording diagnostic state also fails.
      }
    }
    throw error;
  }
}
