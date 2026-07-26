import test from "node:test";
import assert from "node:assert/strict";

import { createEventId } from "../common/event_id.js";

test("event IDs are canonical unique UUID v4 values", () => {
  const values = new Set(Array.from({ length: 256 }, () => createEventId()));
  const uuidV4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

  assert.equal(values.size, 256);
  for (const value of values) assert.match(value, uuidV4);
});

test("version and variant bits are set with deterministic entropy", () => {
  const value = createEventId(() => 0);
  assert.equal(value, "00000000-0000-4000-8000-000000000000");
});
