export const FITBIT_MESSAGE_LIMIT_BYTES = 1027;
export const RALLYMATE_MESSAGE_BUDGET_BYTES = 900;

export function fitMessageBatch(
  events,
  budget = RALLYMATE_MESSAGE_BUDGET_BYTES,
) {
  const batch = [];
  for (const event of events || []) {
    const candidate = batch.concat(event);
    const encoded = JSON.stringify({ type: "events", events: candidate });
    if (utf8ByteLength(encoded) > budget) break;
    batch.push(event);
  }
  return batch;
}

export function utf8ByteLength(value) {
  let bytes = 0;
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index);
    if (code < 0x80) bytes += 1;
    else if (code < 0x800) bytes += 2;
    else if (code >= 0xd800 && code <= 0xdbff) {
      bytes += 4;
      index += 1;
    } else bytes += 3;
  }
  return bytes;
}
