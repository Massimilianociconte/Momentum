import fs from "node:fs";

const release = process.argv.includes("--release");
const check = process.argv.includes("--check");
const value = (process.env.RALLYMATE_WEARABLE_GATEWAY_URL || "").trim();
const valid = /^https:\/\/[a-z0-9.-]+\/[-a-z0-9_/.]+$/i.test(value) &&
  !value.includes("example.") && !value.includes("<") &&
  !value.includes("localhost");

if ((release || check) && !valid) {
  console.error(
    "RALLYMATE_WEARABLE_GATEWAY_URL must be a public HTTPS wearable-gateway URL",
  );
  process.exit(2);
}
if (release) {
  fs.writeFileSync(
    new URL("../companion/runtime-config.js", import.meta.url),
    `export const GATEWAY_URL = ${JSON.stringify(value)};\n`,
  );
}
