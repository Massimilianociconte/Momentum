export const DEVICE_RETRY_MS = 30000;
export const ACTIVE_WAKE_MS = 5 * 60 * 1000;
export const IDLE_WAKE_MS = 30 * 60 * 1000;

export function companionWakeInterval(pendingCount, activeMatch) {
  return pendingCount > 0 || activeMatch ? ACTIVE_WAKE_MS : IDLE_WAKE_MS;
}

export function shouldRetryOnDevice(outboxCount, socketOpen, displayActive) {
  return outboxCount > 0 && socketOpen && displayActive;
}
