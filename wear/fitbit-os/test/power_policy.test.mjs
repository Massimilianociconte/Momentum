import test from "node:test";
import assert from "node:assert/strict";

import {
  ACTIVE_WAKE_MS,
  DEVICE_RETRY_MS,
  IDLE_WAKE_MS,
  companionWakeInterval,
  shouldRetryOnDevice,
} from "../common/power_policy.js";

test("companion sleeps longer when there is no match or pending data", () => {
  assert.equal(companionWakeInterval(0, false), IDLE_WAKE_MS);
  assert.equal(companionWakeInterval(1, false), ACTIVE_WAKE_MS);
  assert.equal(companionWakeInterval(0, true), ACTIVE_WAKE_MS);
});

test("device retry is disabled while the screen is off or in AOD", () => {
  assert.equal(DEVICE_RETRY_MS, 30000);
  assert.equal(shouldRetryOnDevice(1, true, true), true);
  assert.equal(shouldRetryOnDevice(1, true, false), false);
  assert.equal(shouldRetryOnDevice(0, true, true), false);
});
