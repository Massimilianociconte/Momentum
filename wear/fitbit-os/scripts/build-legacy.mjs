import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const temporary = path.join(root, ".legacy-build");
const copy = (name) =>
  fs.cpSync(path.join(root, name), path.join(temporary, name), {
    recursive: true,
  });

fs.rmSync(temporary, { recursive: true, force: true });
fs.mkdirSync(temporary, { recursive: true });
for (const directory of [
  "app",
  "common",
  "companion",
  "resources",
  "settings",
]) {
  copy(directory);
}
fs.copyFileSync(
  path.join(root, "package.legacy.json"),
  path.join(temporary, "package.json"),
);
fs.copyFileSync(
  path.join(root, "tsconfig.json"),
  path.join(temporary, "tsconfig.json"),
);
fs.renameSync(
  path.join(temporary, "resources", "index.view"),
  path.join(temporary, "resources", "index.gui"),
);
fs.renameSync(
  path.join(temporary, "resources", "widget.defs"),
  path.join(temporary, "resources", "widgets.gui"),
);

run("npm", ["install", "--no-audit", "--no-fund"]);
run("npm", ["run", "build"]);
fs.mkdirSync(path.join(root, "build"), { recursive: true });
fs.copyFileSync(
  path.join(temporary, "build", "app.fba"),
  path.join(root, "build", "rallymate-fitbit-os4.fba"),
);
fs.rmSync(temporary, { recursive: true, force: true });

function run(command, args) {
  const result = spawnSync(command, args, {
    cwd: temporary,
    stdio: "inherit",
    env: process.env,
  });
  if (result.status !== 0) process.exit(result.status || 1);
}
